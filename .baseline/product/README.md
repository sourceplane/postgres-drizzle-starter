# postgres-drizzle-starter

Vercel's [Postgres + Drizzle Next.js Starter](https://github.com/vercel/examples/tree/main/storage/postgres-drizzle)
— a page that reads a `profiles` table through Drizzle and seeds it with
three rows the first time it finds it empty — on **Cloudflare Workers +
Static Assets** through [`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare),
with its Postgres a **Supabase** project's database reached through
**Cloudflare Hyperdrive**. Terraform provisions both per environment and
Orun's `db-migrate` applies the schema, all on every merge to `main`.

## Live deployment

<!-- 02-docs:begin -->
Not recorded yet. The bootstrap's last phase writes the live URLs, the
workspace, what the database check reports and the secrets the product
uses into
[ai/context/deployment.md](ai/context/deployment.md); how the product deploys
and how to operate it is in
[ai/context/operations.md](ai/context/operations.md).
<!-- 02-docs:end -->

## What is here

| Surface | Where |
|---|---|
| The product's name (the page's heading and its title) | `apps/web/lib/site.ts` |
| The page and the table | `apps/web/app/page.tsx`, `apps/web/components/table.tsx` |
| The per-request client (Hyperdrive first, `POSTGRES_URL` fallback), the schema, the seed | `apps/web/lib/db.ts`, `apps/web/lib/drizzle.ts`, `apps/web/lib/seed.ts` |
| The database check the deploy smoke-tests | `apps/web/app/api/health/route.ts` |
| Workers build and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` → `wrangler.jsonc`, `component.yaml` |
| The schema as migrations, and their runner | `packages/db` (`@saas/db`); `apps/web/lib/migrations` is the same SQL for drizzle-kit |
| The Supabase project, the Hyperdrive config, the migration step | `infra/terraform/supabase`, `infra/terraform/cloudflare-hyperdrive`, `infra/db-migrate` |
| Tests | `tests/web`, `tests/db` (vitest) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # re-render apps/web/wrangler.jsonc from its template (it is committed)
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # next build + opennextjs-cloudflare build → apps/web/.open-next
```

The build needs no database: the page renders per request.

## Running it locally

You need a Postgres on `localhost:54322` — the Supabase CLI's default
(`supabase start`) — or any Postgres whose URL you put in `POSTGRES_URL`.

1. **Schema.** drizzle-kit applies the migrations to `POSTGRES_URL`
   (default `postgres://postgres:postgres@localhost:54322/postgres`):

   ```bash
   pnpm --filter @app/web db:migrate
   ```

   The same SQL lives in `packages/db/src/migrations`, which is what CI
   applies to the real databases. The page never creates the table; until
   the migrations have run it says so.

2. **Run.** Either Next's dev server, which gets the Worker's bindings
   through `getCloudflareContext()` (the `HYPERDRIVE` binding points at
   `localhost:54322` through `wrangler.jsonc`'s `localConnectionString`):

   ```bash
   pnpm --filter @app/web dev          # http://localhost:3000
   ```

   or the built Worker under `wrangler dev`:

   ```bash
   pnpm build
   pnpm --filter @app/web preview      # http://localhost:8787
   ```

   The first page view seeds the three profiles; `/api/health` says whether
   the database is reachable and migrated.

## How it deploys

Merges to `main` converge through [Orun](https://github.com/sourceplane/orun):
`.github/workflows/ci.yml` plans the changed components and runs each lane
against the workspace in `intent.yaml`. Per environment the order is
enforced — **the Supabase project, then the Hyperdrive config over its
database, then the migrations, then the Worker** — because each reads what
the one before it published: the project's ref and password, the Hyperdrive
id the Worker binds, the table the page queries. `stage` deploys first and
`prod` once stage has converged on the same commit; `dev` only verifies.
Every deploy is smoke-tested over HTTP: the home page's table, and
`/api/health`, which answers only when the Worker reaches a migrated
database.

The pipeline holds one credential, GitHub's own `GITHUB_TOKEN`. The
Cloudflare tokens and account id and the Supabase access token and org id
are brokered per run from the workspace's connections; the Supabase
project's credentials and the Hyperdrive id are published by the Terraform
applies as orun secrets. Nothing provider-shaped is stored in the repository
or in GitHub, and the app needs no secret of its own.

Every table in `public` has row-level security and no policy, so Supabase's
Data API (which serves `public` to the project's anon key) returns none of
it; the app connects as the table's owner and is not affected.

## Custom domain

The app answers on workers.dev from its first deploy. To serve it on your
own domain, attach the domain to the Worker in Cloudflare (Workers & Pages →
`postgres-drizzle-starter-web-prod` → Settings → Domains & Routes), then set
`SITE_URL` under that environment's `env:` in `intent.yaml` — the page's Open
Graph image link is absolute — and merge.

The repository also names the domain in one place, `BASE_DOMAIN` under each
environment's `env:` in `intent.yaml`, which the product was born with as the
reserved placeholder `postgres-drizzle-starter.example.com`. Nothing builds a
URL from it — the origin is `SITE_URL` — so replacing it moves nothing by
itself; it records the domain. Replace it with yours in the same pull request
as `SITE_URL`.

## CI

| Workflow | What it runs |
|---|---|
| `ci.yml` | the Orun pipeline, and the only workflow: `orun plan --changed`, then one job per lane. A pull request runs the verify lanes — the app built and dry-deployed for each environment, both Terraform roots checked and planned, the migrations planned and their checksums verified — with nothing applied or deployed. They do not typecheck, lint or run the tests: run `pnpm typecheck`, `pnpm lint` and `pnpm test` before you push (Getting started, above). A merge applies, migrates and deploys stage → prod |
