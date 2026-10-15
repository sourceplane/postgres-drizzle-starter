import { beforeEach, describe, expect, it, vi } from "vitest";

// /api/health is what the deploy's smoke and the bootstrap's probes read: 200
// only when the database answers through the binding and the migrations have
// run — the profiles table exists, with row-level security on.
let answer: () => Promise<unknown[]>;
vi.mock("@/lib/db", () => ({
  getSql: async () => () => answer(),
}));

beforeEach(() => {
  vi.spyOn(console, "error").mockImplementation(() => {});
});

async function health() {
  const { GET } = await import("@/app/api/health/route");
  const res = await GET();
  const body = (await res.json()) as { ok: boolean; database: string; schema?: string };
  return { status: res.status, body, cache: res.headers.get("cache-control") };
}

describe("GET /api/health (app/api/health/route.ts)", () => {
  it("is ok when the table exists with row-level security", async () => {
    answer = async () => [{ profiles: "profiles", rls: true }];
    expect(await health()).toEqual({
      status: 200,
      body: { ok: true, database: "reachable", schema: "migrated" },
      cache: "no-store",
    });
  });

  it("is 503 when the migrations have not run", async () => {
    answer = async () => [{ profiles: null, rls: false }];
    const r = await health();
    expect(r.status).toBe(503);
    expect(r.body).toEqual({ ok: false, database: "reachable", schema: "missing" });
  });

  it("is 503 when the table is there without row-level security", async () => {
    answer = async () => [{ profiles: "profiles", rls: false }];
    const r = await health();
    expect(r.status).toBe(503);
    expect(r.body.schema).toBe("missing");
  });

  it("is 503 when the database is unreachable", async () => {
    answer = async () => {
      throw new Error("connection refused");
    };
    const r = await health();
    expect(r.status).toBe(503);
    expect(r.body).toEqual({ ok: false, database: "unreachable" });
  });
});
