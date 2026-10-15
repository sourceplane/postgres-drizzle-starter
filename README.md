# postgres-drizzle-starter

Vercel's [Postgres + Drizzle Next.js Starter](https://github.com/vercel/examples/tree/main/storage/postgres-drizzle)
— a page that reads a seeded `profiles` table with Drizzle — running on
**Cloudflare Workers + Static Assets** through
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare), with the
database a **Supabase Postgres** project reached through **Cloudflare
Hyperdrive**, both provisioned by Terraform through
[Orun](https://github.com/sourceplane/orun), the way the
[Lumen baseline](https://github.com/sourceplane/lumen) does it.

The schema, the query and the seed are the template's; the connection
string comes from the Hyperdrive binding, one client per request. See
[`specs/epics/postgres-drizzle-starter`](specs/epics/postgres-drizzle-starter/README.md)
for the design, the milestones and the as-built status.

## What is here

| Surface | Where |
|---|---|
| The page and the table | `apps/web/app/page.tsx`, `apps/web/components/table.tsx` |
| The client (Hyperdrive first, `POSTGRES_URL` fallback), the schema, the seed | `apps/web/lib/db.ts`, `apps/web/lib/drizzle.ts`, `apps/web/lib/seed.ts` |
| Workers build, bindings and deploy contract | `apps/web/next.config.mjs`, `open-next.config.ts`, `wrangler.template.jsonc` + `wiring.fixture.json`, `component.yaml` |
| The Supabase project and the Hyperdrive config (stage, prod) | `infra/terraform/supabase`, `infra/terraform/cloudflare-hyperdrive` |
| Tests | `tests/web` (vitest) |

## Getting started

```bash
pnpm install
pnpm run wire:fixture   # render apps/web/wrangler.jsonc from the offline fixture
pnpm typecheck
pnpm lint
pnpm test
pnpm build              # next build + opennextjs-cloudflare build → apps/web/.open-next
```

With a local Postgres (the Supabase CLI's `supabase start` listens on
`localhost:54322`, which the binding's `localConnectionString` points at):

```bash
pnpm --filter @app/web dev        # http://localhost:3000 — the binding through wrangler's platform proxy
pnpm --filter @app/web preview    # wrangler dev over the built Worker
```

Any other Postgres works too: set `POSTGRES_URL` (see `apps/web/.env.example`)
and run `next dev` without a rendered `wrangler.jsonc`. The first request
creates and seeds the table, as upstream does.

## How it maps to Vercel

| Vercel | Here |
|---|---|
| Next.js hosting | One Cloudflare Worker (`.open-next/worker.js`) + Static Assets |
| Vercel Postgres (`POSTGRES_URL`) | Supabase Postgres through Hyperdrive: the `HYPERDRIVE` binding's connection string, one `postgres` client per request |
| A database created in the dashboard | Terraform: the Supabase project and the Hyperdrive config, their ids published as orun secrets |
| Deploy on push | Orun deploys `postgres-drizzle-starter-web-{stage,prod}` on merge to `main` (`apps/web/component.yaml`) |

## Deploying

`.github/workflows/checks.yml` runs install, wire, typecheck, lint, test and
build on every push and pull request. `ci.yml` is the Orun pipeline: set
`execution.state.workspace` in `intent.yaml` to this product's workspace
(`orun cloud link`), connect **Cloudflare and Supabase** to it, and set the
`ORUN_CI` repository variable to `true`. A merge to `main` then applies the
Supabase project and the Hyperdrive config, renders the Worker's config with
the real Hyperdrive id, and deploys to `stage`, then `prod`.
