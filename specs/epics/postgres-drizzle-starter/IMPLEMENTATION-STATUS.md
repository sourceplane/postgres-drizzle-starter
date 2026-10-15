# postgres-drizzle-starter (PD) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PD0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/postgres-drizzle-starter/pull/1) |
| PD1 — the profiles table on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/postgres-drizzle-starter/pull/2) |
| PD2 — Supabase and Hyperdrive from Terraform | ✅ Shipped (validated; apply gated on a linked workspace) | [#3](https://github.com/sourceplane/postgres-drizzle-starter/pull/3) |
| PD3 — ready to instantiate | ✅ Shipped | [#4](https://github.com/sourceplane/postgres-drizzle-starter/pull/4) |

## Departures from the upstream template

### `lib/db.ts` (new) and per-call clients

`lib/drizzle.ts` exports `getDb()` instead of a module-level `db`;
`lib/seed.ts` opens its `sql` inside `seed()`; `components/table.tsx`
calls `getDb()` once per render. The connection string is the `HYPERDRIVE`
binding's on the Worker and `POSTGRES_URL` elsewhere.

### `next.config.mjs`

`images.domains` → `images.remotePatterns` (Next 16), `output: standalone`,
the monorepo tracing root, `initOpenNextCloudflareForDev()`.

### `metadataBase` from `NEXT_PUBLIC_SITE_URL`

### Page copy and links

"Postgres on Vercel" → "Postgres on Cloudflare"; the deploy button → this
repository. The Prisma / Starter / Kysely demo links stay.

### Versions

drizzle-orm 0.28 → ^0.45 (schema unchanged), drizzle-kit ^0.31, Next
16.3.8, React 19, eslint-config-next 16 flat config (`no-explicit-any` and
`react-hooks/purity` off for the template's `catch (e: any)` and its
`Date.now()` timing during render).

## Verified

- Local: `pnpm run wire:fixture`, `pnpm typecheck`, `pnpm lint`, `pnpm test`
  (4 tests), `pnpm build` green (`/` dynamic); `wrangler dev` boots, serves
  `/` ("Postgres on Cloudflare") and the static assets; without a local
  Postgres the table's query fails on the connection through the binding,
  as upstream does without a database.
- `terraform validate` green on `infra/terraform/supabase` and
  `infra/terraform/cloudflare-hyperdrive`.
- CI: `Checks` green on #2 and #3.
- Not verified: the seed against a real Postgres through Hyperdrive, the
  Terraform applies and a live deploy — all need the product linked to an
  Orun workspace with Supabase and Cloudflare connections (`ORUN_CI`).

## Versions

| Package | Version | Why |
|---|---|---|
| next | 16.3.8 | newest inside `@opennextjs/cloudflare` 1.20.11's peer range |
| drizzle-orm / drizzle-kit | ^0.45 / ^0.31 | the template pinned 0.28 / 0.19; schema unchanged |
| postgres | ^3.4.5 | as upstream; `prepare: false` through Hyperdrive |
| wrangler | ^4.151.0 | compatibility_date 2026-10-01 |
