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

## PD4 — a baseline (PD-5) ✅

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

## PD5 — the cirrus standard (PD-6, PD-7) ✅

Bring the baseline to cirrus-baseline's standard, with nothing about the
product itself changing.

- **No kiox.** `kiox.yaml`/`kiox.lock` pinned an orun (v2.15.0) that nothing
  ran: every workflow installs orun itself through `orun-action` with its own
  `version:`. The files, their two modules and the rebrand's skip entry go.
- **Component docs.** `tooling/catalog/gen-component-docs.py` writes each
  component's `docs/overview.md`, `docs/architecture.md` and `docs/runbook.md`
  from what the component declares, as cirrus-baseline's do; the pages ship
  with the component. Baseline CI runs it with `--check`.
- **The context pack.** `ai/context/current.md`, `decisions.md` and
  `open-risks.md` beside the two pages a product ships with — this
  repository's own, so no module places them.
- **Status that agrees with the tags.** PD4 is shipped and tagged; the risk
  register names the missing live bootstrap (PD-J).
- **The subdomain from the Cloudflare connection (PD-7).** The card's
  `subdomain` input declares `from: connection.cloudflare.workersSubdomain`,
  as cirrus-baseline since `baseline-v23`: the console fills it from the
  connection the build is bound to and renders no field; `manifest.test.sh`
  accepts the source only while the card requires `cloudflare`. A hand-run
  build still passes `--set subdomain`.

**Done when**
- `git grep -i kiox` finds only this milestone's own record, and the leak gate and the offline
  bootstrap pass without the two modules
- the docs check is green in Baseline CI
- this file, the status file and `epic.yaml` agree

## Sequencing note

PD1's component already names the Hyperdrive root's wiring secret; PD2
makes the name true. Applying PD2 needs a workspace with Supabase and
Cloudflare connections (the Hyperdrive token scope).
