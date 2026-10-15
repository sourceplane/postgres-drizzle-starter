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
| A database created in the dashboard | `infra/terraform/supabase` (project, keys, DB URL as secrets) + `infra/terraform/cloudflare-hyperdrive` (the config fronting it; wiring `{hyperdrive_id, hyperdrive_name}`) |
| `images.domains` | `images.remotePatterns` for `images.ctfassets.net` (the `domains` key is gone in Next 16) |
| Hard-coded `metadataBase` | `NEXT_PUBLIC_SITE_URL`, set by the Orun build to the environment's Worker URL |
| Deploy on push | Orun: `apps/web/component.yaml` renders the config for `$ORUN_ENVIRONMENT`, builds, and deploys `postgres-drizzle-starter-web-{stage,prod}` on merge to `main` once the product is linked |

Alternative rejected: Supabase's PostgREST client. The template's point is
Drizzle over a socket; PostgREST would replace the ORM and the schema file.
Also rejected: a `packages/db` migration for the one table — the seed is
upstream's schema mechanism and stays; `db-migrate` is the next step for a
product.

## 3. The connection flow

```
request ──► Worker ──► getSql(): env.HYPERDRIVE.connectionString ──► Hyperdrive (pooled) ──► Supabase Postgres
                  ▲ no context (next dev / scripts): POSTGRES_URL, ssl required
first render: select → "relation does not exist" → seed() → select
```

## 4. The wiring flow

`wrangler.template.jsonc` carries `@@wiring(cloudflare-hyperdrive/__ENV__:hyperdrive_id)@@`
and a `localConnectionString` for wrangler dev (the Supabase CLI's default
Postgres); the verify lane and `pnpm run wire:fixture` render from
`wiring.fixture.json`, the deploy lane from `WIRING_CLOUDFLARE_HYPERDRIVE_<ENV>`.

## 5. The repository

```
apps/web                               the template + the Workers build
  lib/db.ts                            the per-call client (Hyperdrive first)
  lib/drizzle.ts, lib/seed.ts          schema and seed, with getSql()/getDb()
  wrangler.template.jsonc              worker name, nodejs_compat, ASSETS, the HYPERDRIVE binding
infra/terraform/supabase               the Supabase project per environment
infra/terraform/cloudflare-hyperdrive  the Hyperdrive config per environment
tests/web                              vitest: client resolution, timeAgo, the seeding branch
```

## 6. Out of scope

Migrations (Lumen's `packages/db` + `db-migrate`), auth, Row Level
Security (the Worker connects as `postgres`, as the template did with its
Vercel Postgres role), a custom domain.
