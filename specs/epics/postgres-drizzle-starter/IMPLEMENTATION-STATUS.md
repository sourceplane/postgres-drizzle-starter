# postgres-drizzle-starter (PD) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PD0 — the spec | | |
| PD1 — the profiles table on Workers | | |
| PD2 — Supabase and Hyperdrive from Terraform | | |
| PD3 — ready to instantiate | | |

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
