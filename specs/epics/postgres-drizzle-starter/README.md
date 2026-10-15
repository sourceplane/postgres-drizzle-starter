# Epic: postgres-drizzle-starter (PD)

**Vercel's Postgres + Drizzle starter is the smallest template that opens a Postgres socket: a schema, one `select`, and a seed that creates the table on first use. On Cloudflare that socket goes through Hyperdrive to a Supabase Postgres project — the Lumen baseline's data plane — and the only code that changes is where the client comes from: a per-request `getSql()` reading the `HYPERDRIVE` binding's connection string, because the Workers runtime refuses to share a socket across requests, with `POSTGRES_URL` kept as the fallback for local work without wrangler.**

The port keeps the page, the table component, the refresh button, the schema and the seed. It adds the Workers build, the monorepo wrapper, a test package for the client resolution and the first-use seeding, the Supabase and Hyperdrive Terraform roots, and the deploy contract. It deliberately does not add a migrations package: the template's seed is its schema, and Lumen's `db-migrate` is the shape to adopt when a product outgrows that.

## Status

| Field | Value |
|-------|-------|
| Status | ✅ Shipped — PD0–PD3 landed (#1–#4); Terraform applies and live deploy gated on a linked workspace |
| Cluster | **PD** (PD0–PD3) |
| Owner(s) | `apps/web` (the page, `lib/db.ts`, `lib/drizzle.ts`, `lib/seed.ts`) · `tests/web` · `infra/terraform/{supabase,cloudflare-hyperdrive}` |
| Builds on | `lumen`: the `supabase` and `cloudflare-hyperdrive` roots and the per-request `postgres` client; the `saas-starter` port's `getDb()` pattern |
| Upstream | [vercel/examples `storage/postgres-drizzle`](https://github.com/vercel/examples/tree/main/storage/postgres-drizzle) |
| Changes | The client resolution (module-level `POSTGRES_URL` → per-request Hyperdrive), the Workers build, tests, two Terraform roots, the deploy contract; page copy says Cloudflare |
| Decisions locked | (1) Per-request client, Hyperdrive first, `POSTGRES_URL` fallback. (2) Seed-on-first-use kept as upstream; no `db-migrate` for one table. (3) `wrangler.jsonc` rendered per environment; never committed. (4) Drizzle moves from 0.28 to the current line with the schema as written. |
| Gate | PD1 is the first user-visible rung. PD2 applies only with a linked workspace (Supabase + Cloudflare connections); verified by `terraform validate`. |
| Shipped as | `main` after [#4](https://github.com/sourceplane/postgres-drizzle-starter/pull/4); verified locally under `wrangler dev` |

## Read order

1. `design.md` — what maps to what, the connection flow, what is out of scope
2. `implementation-plan.md` — the milestones and what "done" means for each
3. `risks-and-open-questions.md` — what could go wrong and what was decided
4. `IMPLEMENTATION-STATUS.md` — what actually shipped (kept distinct from intent)

## Milestones at a glance

| Milestone | What it lands | Done when |
|---|---|---|
| PD0 — the spec | this doc set and the task contracts | merged on `main` |
| PD1 — the profiles table on Workers | `apps/web`, the rendered wrangler config, `tests/web` | Checks green; the Worker boots and reaches the binding |
| PD2 — Supabase and Hyperdrive from Terraform | the two roots | they validate; the wiring key matches the template |
| PD3 — ready to instantiate | README, as-built status | a reader can run, test, preview and deploy it |
