import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";

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
  it("seeds the table when the relation is missing, then renders the users", async () => {
    const rows = [
      { id: 1, name: "Ada", email: "ada@example.com", image: "https://images.ctfassets.net/a.jpg", createdAt: new Date() },
    ];
    let calls = 0;
    const select = () => ({
      from: async () => {
        calls += 1;
        if (calls === 1) throw new Error('relation "profiles" does not exist');
        return rows;
      },
    });
    const seed = vi.fn(async () => ({}));
    vi.doMock("@/lib/drizzle", () => ({ getDb: async () => ({ select }), UsersTable: {} }));
    vi.doMock("@/lib/seed", () => ({ seed }));
    vi.doMock("next/image", () => ({ default: (p: { alt: string }) => <img alt={p.alt} /> }));
    vi.doMock("@/components/refresh-button", () => ({ default: () => null }));
    const { default: Table } = await import("@/components/table");
    const html = renderToStaticMarkup(await Table());
    expect(seed).toHaveBeenCalledTimes(1);
    expect(html).toContain("Fetched 1 users in");
    expect(html).toContain("ada@example.com");
  });
});
