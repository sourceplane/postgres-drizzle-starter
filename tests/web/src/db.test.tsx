import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { readFileSync } from "node:fs";
import * as path from "node:path";

// The connection string comes from the HYPERDRIVE binding on the Worker and
// from POSTGRES_URL elsewhere; the Table seeds on the "relation does not
// exist" error exactly as upstream does.
const ctx = { env: {} as { HYPERDRIVE?: { connectionString: string } } };
vi.mock("@opennextjs/cloudflare", () => ({
  getCloudflareContext: async () => ctx,
}));
const postgresMock = vi.fn((cs: string) => ({ connectionString: cs }));
vi.mock("postgres", () => ({ default: postgresMock }));

beforeEach(() => {
  postgresMock.mockClear();
  ctx.env = {};
  delete process.env.POSTGRES_URL;
});

describe("getSql (lib/db.ts)", () => {
  it("uses the Hyperdrive binding on the Worker", async () => {
    ctx.env = { HYPERDRIVE: { connectionString: "postgres://hyperdrive/db" } };
    const { getSql } = await import("@/lib/db");
    await getSql();
    expect(postgresMock).toHaveBeenCalledWith("postgres://hyperdrive/db", expect.objectContaining({ prepare: false }));
  });

  it("falls back to POSTGRES_URL without a binding", async () => {
    process.env.POSTGRES_URL = "postgres://local/db";
    const { getSql } = await import("@/lib/db");
    await getSql();
    expect(postgresMock).toHaveBeenCalledWith("postgres://local/db", { ssl: "require" });
  });
});

describe("timeAgo (lib/utils.ts)", () => {
  it("formats a past timestamp as a relative duration", async () => {
    const { timeAgo } = await import("@/lib/utils");
    expect(timeAgo(new Date(Date.now() - 2 * 60 * 60 * 1000))).toBe("2h ago");
    expect(timeAgo(new Date(Date.now() - 5000), true)).toBe("5s");
    expect(timeAgo(undefined as unknown as Date)).toBe("never");
  });
});

describe("Table (components/table.tsx)", () => {
  // The page never creates the table (the migrations do, before the Worker
  // serves); it seeds the three profiles the first time it finds it empty.
  const rows = [
    { id: 1, name: "Ada", email: "ada@example.com", image: "https://images.ctfassets.net/a.jpg", createdAt: new Date() },
  ];
  async function render(results: Array<unknown[] | Error>) {
    vi.resetModules();
    let calls = 0;
    const filtered: number[] = [];
    // drizzle's builder: awaitable as is, or narrowed with .where().
    const run = async () => {
      const r = results[Math.min(calls, results.length - 1)];
      calls += 1;
      if (r instanceof Error) throw r;
      return r;
    };
    const select = () => ({
      from: () => ({
        then: (ok: (v: unknown) => unknown, ko: (e: unknown) => unknown) => run().then(ok, ko),
        where: () => {
          filtered.push(calls);
          return run();
        },
      }),
    });
    const seed = vi.fn(async () => ({}));
    vi.doMock("@/lib/drizzle", () => ({ getDb: async () => ({ select }), UsersTable: {} }));
    vi.doMock("@/lib/seed", () => ({ seed }));
    vi.doMock("next/image", () => ({ default: (p: { alt: string }) => <img alt={p.alt} /> }));
    vi.doMock("@/components/refresh-button", () => ({ default: () => null }));
    const { default: Table } = await import("@/components/table");
    return { html: renderToStaticMarkup(await Table()), seed, selects: () => calls, filtered };
  }

  it("renders the users without writing when the table has rows", async () => {
    const { html, seed, selects } = await render([rows]);
    expect(seed).not.toHaveBeenCalled();
    expect(selects()).toBe(1);
    expect(html).toContain("Recent Users");
    expect(html).toContain("Fetched 1 users in");
    expect(html).toContain("ada@example.com");
  });

  it("seeds an empty table, then renders what it wrote", async () => {
    const { html, seed, selects } = await render([[], rows]);
    expect(seed).toHaveBeenCalledTimes(1);
    expect(selects()).toBe(2);
    expect(html).toContain("Fetched 1 users in");
  });

  it("reads the seed back with a query Hyperdrive will not answer from its cache", async () => {
    const { filtered } = await render([[], rows]);
    // the first select is plain (cacheable); only the read-back is narrowed
    expect(filtered).toEqual([1]);
    const table = readFileSync(path.resolve(__dirname, "../../../apps/web/components/table.tsx"), "utf8");
    expect(table).toMatch(/\.where\(sql`now\(\) is not null`\)/);
  });

  it("says the migrations have not run instead of creating the table", async () => {
    const { html, seed } = await render([new Error('relation "profiles" does not exist')]);
    expect(seed).not.toHaveBeenCalled();
    expect(html).toContain('data-schema="missing"');
    expect(html).toContain("db:migrate");
    expect(html).not.toContain("Recent Users");
  });

  it("lets any other database error through", async () => {
    await expect(render([new Error("connection refused")])).rejects.toThrow("connection refused");
  });
});

describe("seed (lib/seed.ts)", () => {
  it("only inserts — idempotently, on the unique email — and never creates the table", async () => {
    vi.resetModules();
    vi.doUnmock("@/lib/seed"); // the Table tests above replace it
    const statements: string[] = [];
    const sql = (strings: TemplateStringsArray) => {
      statements.push(strings.join("?"));
      return Promise.resolve([]);
    };
    vi.doMock("@/lib/db", () => ({ getSql: async () => sql }));
    const { seed } = await import("@/lib/seed");
    await seed();
    expect(statements).toHaveLength(3);
    for (const s of statements) {
      expect(s).toMatch(/INSERT INTO profiles/);
      expect(s).toMatch(/ON CONFLICT \(email\) DO NOTHING/);
      expect(s).not.toMatch(/CREATE/i);
    }
  });
});
