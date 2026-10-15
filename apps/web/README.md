# @app/web — the Postgres + Drizzle page on Cloudflare Workers

Vercel's [Postgres + Drizzle Next.js Starter](https://github.com/vercel/examples/tree/main/storage/postgres-drizzle)
([demo](https://postgres-drizzle.vercel.app/)): one page that selects every
row of a `profiles` table through [Drizzle](https://github.com/drizzle-team/drizzle-orm)
and shows how long the query took. Here it is built by
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare) into one
Worker plus Static Assets, and its Postgres is reached through the Worker's
`HYPERDRIVE` binding.

| File | What it does |
|---|---|
| `lib/site.ts` | The product's name: the page's heading and its `<title>` |
| `lib/db.ts` | `getSql()`: a `postgres` client per call — the `HYPERDRIVE` binding's connection string on the Worker, `POSTGRES_URL` without a Cloudflare context |
| `lib/drizzle.ts` | The `profiles` table (with `.enableRLS()`) and `getDb()` |
| `lib/seed.ts` | The three demo profiles, inserted `ON CONFLICT (email) DO NOTHING` the first time the page finds the table empty |
| `components/table.tsx` | Selects the rows, seeds an empty table (reading it back with a query Hyperdrive's cache cannot answer), says so when the migrations have not run |
| `app/api/health/route.ts` | 200 only when the database answers through the binding and the table exists with row-level security |
| `lib/migrations`, `drizzle.config.ts` | drizzle-kit, for a local database (`pnpm db:migrate`, `pnpm db:generate`); the deployed databases are migrated by db-migrate from `packages/db` — the same SQL |
| `wrangler.template.jsonc` → `wrangler.jsonc` | The Worker's config; the render is committed (`pnpm run wire:fixture`) |

The table is created by the migrations, never by the page: upstream ran
`CREATE TABLE IF NOT EXISTS` from its first request, which fails for one of
two requests that race through it on a fresh database.

```bash
pnpm db:migrate     # the schema, into POSTGRES_URL (default: the Supabase CLI's localhost:54322)
pnpm dev            # next dev, with the Worker's bindings through wrangler's platform proxy
pnpm build && pnpm preview   # the built Worker under wrangler dev
```
