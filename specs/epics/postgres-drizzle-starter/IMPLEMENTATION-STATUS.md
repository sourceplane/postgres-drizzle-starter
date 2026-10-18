# postgres-drizzle-starter (PD) — Implementation status

As-built ≠ intent. This file records what actually shipped, and every place
the code departed from `design.md` or from the upstream template.

| Milestone | State | PR |
|---|---|---|
| PD0 — the spec | ✅ Shipped | [#1](https://github.com/sourceplane/postgres-drizzle-starter/pull/1) |
| PD1 — the profiles table on Workers | ✅ Shipped | [#2](https://github.com/sourceplane/postgres-drizzle-starter/pull/2) |
| PD2 — Supabase and Hyperdrive from Terraform | ✅ Shipped (validated; apply gated on a linked workspace) | [#3](https://github.com/sourceplane/postgres-drizzle-starter/pull/3) |
| PD3 — ready to instantiate | ✅ Shipped | [#4](https://github.com/sourceplane/postgres-drizzle-starter/pull/4) |
| PD4 — a baseline | ✅ Shipped (offline-proven; no live bootstrap yet, risk PD-J) | [#5](https://github.com/sourceplane/postgres-drizzle-starter/pull/5) (PD-5), tagged `baseline-v1` |
| PD5 — the cirrus standard | ✅ Shipped | PD-6 — on `main` after `baseline-v1`, not yet tagged |

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

Upstream's layout hard-codes `metadataBase: new URL('https://postgres-drizzle.vercel.app')`.
`app/layout.tsx` reads `NEXT_PUBLIC_SITE_URL` instead (falling back to
`http://localhost:3000`), and the deploy's build sets it to the
environment's `SITE_URL` or, unset, its workers.dev URL
(`apps/web/component.yaml`'s `buildCommand`; risk PD-G).

### Page copy and links

"Postgres on Vercel" → "Postgres on Cloudflare"; the deploy button → this
repository. The Prisma / Starter / Kysely demo links stay.

### Versions

drizzle-orm 0.28 → ^0.45 (schema unchanged), drizzle-kit ^0.31, Next
16.3.8, React 19, eslint-config-next 16 flat config (`no-explicit-any` and
`react-hooks/purity` off for the template's `catch (e: any)` and its
`Date.now()` timing during render).

## Verified (PD1–PD3)

(What was checked when PD1–PD3 landed: `tests/web` then held 4 tests. PD4's
count is under Verified (PD4), PD5's under Verified (PD5).)

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

## PD4 — a baseline (PD-5)

The repository is an Orun baseline on the Lumen conventions, built the way
cirrus-baseline v22 builds a product: ONE landing. `blueprint.yaml` is the
card (`requires: [github, cloudflare, supabase]`; the five brokered keys —
`CLOUDFLARE_API_TOKEN` workers-deploy, `CLOUDFLARE_HYPERDRIVE_TOKEN`
hyperdrive-edit, `CLOUDFLARE_ACCOUNT_ID` account-id, `SUPABASE_ACCESS_TOKEN`
management-access, `SUPABASE_ORG_ID` org-id — as a preview; programme
`01-product`, `02-docs`; the two-Supabase-projects prerequisite in its
description); `repo-blueprint.yaml` places every module in `01-product`,
brands it, links the repository, reconciles the five keys and lands it as one
pull request, then awaits the convergence, the four published secrets on
stage and prod and `/` + `/api/health`; `02-docs` restores the promotion gate
and dev's lanes and renders the record. The machinery is saas-starter's
(`baseline` branch, SA5) — itself portfolio-starter-kit's `baseline-v2`
adapted to two phases — copied verbatim where it is generic (`testing/lib`,
the contract tests, `tooling/bootstrap`, the workflows, the Terraform roots
and their lock files) and adapted where it names the product.

### How the table got created, and why that changed

Upstream (and PD0–PD3) created `profiles` from the page: `components/table.tsx`
caught `relation "profiles" does not exist` and ran `lib/seed.ts`, whose
first statement was `CREATE TABLE IF NOT EXISTS` and whose next three were
`INSERT … ON CONFLICT (email) DO NOTHING`. There was no migration, seed
script or drizzle push. The DDL half is idempotent but not safe under
concurrent first requests (risks, PD-B — measured: 2 of 160 racing sessions
failed on Postgres 16), so the table moved to `db-migrate`, which runs before
the Worker deploys; the order on main is supabase → cloudflare-hyperdrive →
db-migrate → web.

### Departures, in the product

- **The schema is migrations** (`packages/db`, Lumen's runner, named
  `@saas/db` because stack-tectonic's db-migrate composition builds
  `--filter=@saas/db` — PD-H): `000_control`, `010_profiles`,
  `020_row_level_security`; `infra/db-migrate` applies them per environment.
  `010_profiles` is drizzle-kit's output for `lib/drizzle.ts` with `IF NOT
  EXISTS` added — so the table is the Drizzle schema's (`text` columns,
  `image` and `createdAt` NOT NULL, `timestamp`, unique index `unique_idx`),
  not seed.ts's hand-written DDL (`varchar(255)`, nullable `image` and
  `createdAt`, `timestamptz`, the constraint `profiles_email_key`). A
  database the old page already created the table in keeps its older shape;
  the page's select works on either. drizzle-kit twins in
  `apps/web/lib/migrations` (`pnpm db:migrate`, `pnpm db:generate`,
  `drizzle.config.ts`) serve a local database; `tests/db` holds the two
  copies to the same statements.
- **The page seeds rows, not the table** (`lib/seed.ts`,
  `components/table.tsx`): `seed()` lost its `CREATE TABLE`; the table seeds
  when its select returns no rows (was: when the relation was missing); a
  missing relation renders "The profiles table does not exist yet" with the
  command to run, instead of creating it. The read-back after a seed adds
  `where now() is not null`, so Hyperdrive's read cache — which would still
  hold the empty answer for up to a minute — cannot serve it (PD-I).
- **Row-level security on every table in `public`** (migration 020, twin
  `0001`, `.enableRLS()` in `lib/drizzle.ts`) with no policy — Supabase's Data
  API serves `public` to the anon key (PD-E). The app connects as
  `postgres`, the table's owner; the migration refuses to run if that role
  would be locked out. `tests/db` (PGlite) and the e2e hold it.
- **`/api/health`** (new): 200 only when the database answers through the
  binding and `public.profiles` exists with RLS on. The deploy's smoke and
  both phases' probes read it; the smoke also needs `Recent Users` on `/`
  (the table rendered — on a fresh environment that request is the seed).
- **The product's name is one seam** (`lib/site.ts`, `SITE_NAME = "Postgres
  on Cloudflare"`): the page's heading and its `<title>` (upstream's title:
  "Postgres Demo with Drizzle").
- **`apps/web/wrangler.jsonc` is committed** — the fixture render — because
  the composition checks for it before the build; stage and prod re-render it
  from their wiring document, dev verifies with the fixture. `tests/web`
  holds the two equal.
- **The deploy order is enforced on main** (`mode: enforced`, advisory
  `modeRules` on pull requests): `cloudflare-hyperdrive` → `supabase`;
  `db-migrate` → `supabase`, `cloudflare-hyperdrive`; `web` →
  `cloudflare-hyperdrive`, `db-migrate`.
- **The build's site origin is written out** (PD-G): it read
  `${WORKERS_DEV_SUBDOMAIN}`, which the build step never had.
  `SITE_URL` under an environment's `env:` overrides it.
- **The supabase root publishes Lumen's three outputs** (`SUPABASE_PROJECT_REF`,
  `SUPABASE_DB_PASSWORD`, `SUPABASE_DB_URL`); the `supabase_apikeys` block and
  `SUPABASE_URL`/`_ANON_KEY`/`_SERVICE_ROLE_KEY`/`WIRING_SUPABASE` are gone —
  nothing here uses them. Both roots carry Lumen's `.terraform.lock.hcl`.
- **stack-tectonic 0.19.0** (was 0.18.2; not 0.20.0, whose lane-scoped
  install Turbopack refuses), **`checks.yml` on pull requests only**,
  `ci.yml`'s `linked` gate in place of the `ORUN_CI` variable and its lanes on
  v2.78.4.
- `apps/web/README.md` describes the app as it runs here (upstream's README
  was the Vercel template page's); `intent.yaml`'s docs pages are the
  product's `ai/context/` pages; tasks PD-1..PD-4 gained the `metadata` that
  `orun work check` requires.

### Verified (PD4)

See the pull request for the run log. In short: the repository's checks
(`pnpm install --frozen-lockfile`, `wire:fixture`, typecheck, lint, test —
29 tests: 17 in `tests/web`, 12 in `tests/db` — build); every
`testing/*.test.sh`; `orun new --status` at v2.58.11, v2.78.4 and 2.79.0;
`orun validate`; `orun work check`; `terraform fmt -check`, `init
-backend=false` (against the committed lock files) and `validate` on both
roots. Not verified: a Terraform apply, a db-migrate apply against a real
Supabase project, a live deploy, and a live bootstrap — all need a linked
workspace with Cloudflare and Supabase connections.

## The cirrus standard (PD5)

Nothing about the product changed. What changed is the baseline around it:

| What | Before | After | Why |
|---|---|---|---|
| orun pin | `kiox.yaml` (v2.15.0) + `kiox.lock`, shipped to every product | gone; orun is pinned where it runs, the `orun-action` `version:` in each workflow | nothing ran the kiox pin, and it disagreed with the lanes (v2.78.4) |
| `root-kiox`, `root-kiox-lock` modules | in `01-product` | removed (`testing/phases.test.sh` and the rebrand's skip list follow) | a product is placed with 126 files: 107 − 2 kiox + 21 docs pages |
| component docs | none | `docs/overview.md`, `architecture.md`, `runbook.md` beside each of the seven `component.yaml` (`apps/web`, `packages/db`, `infra/db-migrate`, `infra/terraform/{supabase,cloudflare-hyperdrive}`, `tests/{web,db}`) | cirrus-baseline documents every component; the workspace Docs library renders `docs/` beside each `component.yaml` |
| how the docs stay true | — | `tooling/catalog/gen-component-docs.py` derives them from the manifest, the Worker config, Terraform, the migrations and package scripts; Baseline CI runs it with `--check` | a hand-written copy of a manifest drifts silently |
| context pack | `operations.md`, `deployment.md` | plus `current.md`, `decisions.md`, `open-risks.md` | cirrus-baseline's shape; the three new pages are this repository's own and no module places them (the leak gate still allows exactly two) |
| status | PD4 "in review" on its branch; an empty `metadataBase` heading; an unlabeled Verified section's "4 tests"; no risk for the missing live bootstrap | PD4 shipped and tagged `baseline-v1`; the heading says what changed; the section is labeled PD1–PD3; risk PD-J (OPEN) | the tag existed; the documents had not caught up |

## Verified (PD5)

- `testing/{manifest,phases,coverage,rebrand,retouch,bootstrap-defer}.test.sh`
  green; `gen-component-docs.py --check` green (7 components, 21 pages).
- `orun new --status` (v2.58.11, the bootstrap floor): `01-product` 126
  files, `02-docs` hook-only.
- `testing/leak.test.sh` (v2.58.11): 126 files derived (107 − 2 kiox + 21
  docs pages), 123 text files read; ai/context still exactly the two
  declared pages; no factory path ships or is named by a shipped file.
- `testing/placement.test.sh` (v2.58.11, as Baseline CI runs it): 126 files
  placed, both landings, branded, re-tenanted, record rendered; the
  product's own plan for the 01-product merge converges supabase →
  cloudflare-hyperdrive → db-migrate → web, enforced, on stage and prod side
  by side, resolving exactly the 5 keys the blueprint mints; `--resume`
  changes nothing.
- `pnpm install --frozen-lockfile`, `wire:fixture` (committed render
  unchanged), `typecheck`, `lint`, `test` (29 tests: 17 in `tests/web`, 12
  in `tests/db`), `build` green.
- `testing/e2e.test.sh` (v2.78.4): the 01-product landing passes the Checks
  sequence; the stage db-migrate lane builds `@saas/db` and applies the 3
  migrations to a local Postgres with Supabase's roles, a second apply
  applies nothing, and the pull request's plan verifies every checksum
  offline; the stage web lane's five steps pass in the staged job tree;
  under `wrangler dev` eight concurrent first requests all render the table
  and leave exactly the 3 seed rows, the component's own smoke passes, and
  `anon` and `authenticated` read none of the rows and write none.
- `orun task check PD-6` complete.

