# postgres-drizzle-starter — design

## 1. What the template is

`lib/drizzle.ts` declares the `profiles` table (Drizzle `pgTable`) and a
`postgres(POSTGRES_URL, { ssl: 'require' })` client wrapped by `drizzle()`;
`components/table.tsx` selects every row, and on `relation "profiles" does
not exist` runs `lib/seed.ts` (raw SQL `CREATE TABLE IF NOT EXISTS` + three
`INSERT … ON CONFLICT DO NOTHING`) and selects again; the page is
`force-dynamic` and shows the rows with `timeAgo`; a client button calls
`router.refresh()`.

## 2. The mapping (Vercel → Cloudflare + Supabase)

| Vercel primitive the template uses | Here |
|---|---|
| Next.js hosting (dynamic page) | Cloudflare Workers + Static Assets; the Worker is `@opennextjs/cloudflare`'s output |
| Vercel Postgres (`POSTGRES_URL` with `ssl: 'require'`) | Supabase Postgres through Cloudflare Hyperdrive; `lib/db.ts` `getSql()` opens `postgres(env.HYPERDRIVE.connectionString, { max: 5, fetch_types: false, prepare: false })` per call, or `postgres(POSTGRES_URL, { ssl: 'require' })` without a Cloudflare context |
| Module-level `db` and `sql` | `getDb()` / `getSql()` per call (the runtime forbids cross-request socket reuse); `components/table.tsx` and `lib/seed.ts` call them once per render |
| A database created in the dashboard | `infra/terraform/supabase` (project; ref, password and DB URL as secrets — Lumen's three) + `infra/terraform/cloudflare-hyperdrive` (the config fronting it; wiring `{hyperdrive_id, hyperdrive_name}`) |
| The page creates the table on its first request | PD4: `infra/db-migrate` applies `packages/db/src/migrations` — `010_profiles` (the Drizzle schema), `020_row_level_security` — per environment, after the project and the Hyperdrive config exist and before the Worker deploys; the page seeds only the rows, on an empty table |
| `images.domains` | `images.remotePatterns` for `images.ctfassets.net` (the `domains` key is gone in Next 16) |
| Hard-coded `metadataBase` | `NEXT_PUBLIC_SITE_URL`, set by the Orun build to the environment's Worker URL |
| Deploy on push | Orun: `apps/web/component.yaml` renders the config for `$ORUN_ENVIRONMENT`, builds, and deploys `postgres-drizzle-starter-web-{stage,prod}` on merge to `main` once the product is linked, after `cloudflare-hyperdrive` and `db-migrate` (enforced on main) |

Alternative rejected: Supabase's PostgREST client. The template's point is
Drizzle over a socket; PostgREST would replace the ORM and the schema file.
Also rejected at PD0, and adopted at PD4: a `packages/db` migration for the
one table. The seed was upstream's schema mechanism, but its DDL is not safe
under concurrent first requests (risks, PD-B), and a deterministic schema
before the app serves is what a baseline's unattended first deploy needs.

## 3. The connection flow

```
request ──► Worker ──► getSql(): env.HYPERDRIVE.connectionString ──► Hyperdrive (pooled) ──► Supabase Postgres
                  ▲ no context (next dev / scripts): POSTGRES_URL, ssl required
before the first deploy: db-migrate → profiles (+ row-level security)
first render: select → no rows → seed() (INSERT … ON CONFLICT DO NOTHING) → select
             select → "relation does not exist" → "apply the migrations" (never created here)
```

## 4. The wiring flow

`wrangler.template.jsonc` carries `@@wiring(cloudflare-hyperdrive/__ENV__:hyperdrive_id)@@`
and a `localConnectionString` for wrangler dev (the Supabase CLI's default
Postgres); `pnpm run wire:fixture` renders it from `wiring.fixture.json` into
the COMMITTED `wrangler.jsonc` (the composition checks it exists before the
build, in a fresh checkout), which the dev verify lane uses; the stage and
prod lanes re-render it from `WIRING_CLOUDFLARE_HYPERDRIVE_<ENV>` before they
build (PD4; it was git-ignored before).

On a push to main the four data-plane and app components converge in one
run, per environment, in the order `supabase → cloudflare-hyperdrive →
db-migrate → web`, because each component that reads another's output
declares `dependsOn` on it with `mode: enforced` (advisory on a pull
request).

## 5. The repository

```
apps/web                               the template + the Workers build
  lib/db.ts                            the per-call client (Hyperdrive first)
  lib/drizzle.ts, lib/seed.ts          schema (.enableRLS()) and seed rows, with getSql()/getDb()
  lib/migrations, drizzle.config.ts    drizzle-kit, for a local database
  app/api/health/route.ts              the database check the smoke and probes read
  wrangler.template.jsonc              worker name, nodejs_compat, ASSETS, the HYPERDRIVE binding
packages/db                            the migrations and Lumen's runner (@saas/db)
infra/terraform/supabase               the Supabase project per environment
infra/terraform/cloudflare-hyperdrive  the Hyperdrive config per environment
infra/db-migrate                       applies packages/db's migrations per environment
tests/web                              vitest: client resolution, timeAgo, the seeding branch, /api/health, the wrangler render
tests/db                               vitest: the manifest, the drizzle-kit twins, row-level security (PGlite)
```

## 6. Out of scope

Auth and RLS *policies* (the app does not use Supabase's Data API or Auth,
so RLS is enabled with none — PD4), a custom domain. Migrations and row-level
security were out of scope until PD4.
