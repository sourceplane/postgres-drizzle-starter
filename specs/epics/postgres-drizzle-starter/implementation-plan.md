# postgres-drizzle-starter — implementation plan

## PD0 — the spec ✅

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/PD-1..PD-4.TaskContract.yaml` exist

## PD1 — the profiles table on Workers ✅

**Done when**
- `pnpm install && pnpm run wire:fixture && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally and in `Checks`
- `wrangler dev` boots; `/` reaches for Postgres through the binding (with the Supabase CLI running locally the table seeds and three profiles render; without it the page errors on the connection, as upstream does without a database)

## PD2 — Supabase and Hyperdrive from Terraform ✅

**Done when**
- `terraform validate` passes on both roots
- `hyperdrive_id` is the key the template's token names

## PD3 — ready to instantiate ✅

**Done when**
- the README quick start works from a fresh clone
- the status file lists every PR and departure

## PD4 — a baseline

The repository becomes an Orun baseline on the Lumen conventions, built the
way cirrus-baseline v22 builds a product — in ONE landing:

- the table moves from the page's first request to `db-migrate`: Lumen's
  `packages/db` runner (`@saas/db`, the name the composition builds) with
  `010_profiles` and `020_row_level_security`, their drizzle-kit twins in
  `apps/web/lib/migrations`, `infra/db-migrate`; the page seeds only rows,
  on an empty table;
- `blueprint.yaml` (the card: `requires [github, cloudflare, supabase]`, the
  five brokered secrets as a preview, the programme `01-product`, `02-docs`)
  and `repo-blueprint.yaml` (every module placed by `01-product` and landed as
  one pull request; `02-docs` hook-only);
- the components' edges `mode: enforced` on a push to main, advisory on a
  pull request, so one convergence runs supabase → cloudflare-hyperdrive →
  db-migrate → web per environment;
- `/api/health` for the smoke and the probes; `wrangler.jsonc` committed as
  the fixture render;
- `.baseline/`, the rename engine, the bootstrap helpers, the deployment
  record, `ai/context/`, `testing/` and the `baseline.yml` / `tag.yml` lanes.

**Done when**
- orun reads the build document at the bootstrap floor (v2.58.11), the lane
  pin (v2.78.4) and 2.79.0, and the card agrees with it
- the product's own `orun plan --trigger github-push-main` shows the order,
  enforced; a pull request's plan holds the same edges advisory
- the e2e tier migrates a local Postgres with the product's own runner, builds
  in the job tree orun stages, and serves the page over it — eight concurrent
  first requests leaving exactly the three seed rows — while the Data API's
  roles read and write none of it

## Sequencing note

PD1's component already names the Hyperdrive root's wiring secret; PD2
makes the name true. Applying PD2 needs a workspace with Supabase and
Cloudflare connections (the Hyperdrive token scope).
