# postgres-drizzle-starter — where this repository stands

The entry page for anyone (or any agent) picking this repository up. It is
this repository's own state and does not ship to a product built from it;
the two pages that do are [operations.md](operations.md) and
[deployment.md](deployment.md).

## What it is

Vercel's Postgres + Drizzle Next.js Starter — one page that reads a
`profiles` table with Drizzle — on Cloudflare Workers + Static Assets, with
the database a Supabase Postgres project reached through Hyperdrive, packaged
as an Orun baseline: `orun new --blueprint repo-blueprint.yaml` builds a new
product in its own repository and takes it to live on stage and prod in one
landing (`01-product`: supabase → cloudflare-hyperdrive → db-migrate → web
per environment), then records what went live (`02-docs`).

## Release

| | |
|---|---|
| Latest tag | `baseline-v3` (PD6 — the domain is set later: the console asks for no domain, and a product is born with the placeholder `<reponame>.example.com` in `BASE_DOMAIN` for an owner to replace); `baseline-v2` is PD5 (the cirrus standard), `baseline-v1` PD4 |
| Proven live | No. Everything short of the platform is proven offline in Baseline CI, a migrated local Postgres served through the built Worker included; a live bootstrap from a tag is still to come (risk PD-J) |

## Where to read

| Question | Page |
|---|---|
| What shipped, and every departure from upstream | `specs/epics/postgres-drizzle-starter/IMPLEMENTATION-STATUS.md` |
| Why it is built this way | [decisions.md](decisions.md), then `specs/epics/postgres-drizzle-starter/design.md` |
| What could still go wrong | [open-risks.md](open-risks.md), then `specs/epics/postgres-drizzle-starter/risks-and-open-questions.md` |
| How to instantiate it | `BOOTSTRAP.md`, `docs/phases/` |
| What each component is | `<component>/docs/` beside each `component.yaml` — `apps/web`, `packages/db`, `infra/db-migrate`, `infra/terraform/{supabase,cloudflare-hyperdrive}`, `tests/{web,db}` (generated; `python3 tooling/catalog/gen-component-docs.py`) |

## Next

1. Bootstrap one product from `baseline-v3` against a workspace with
   Cloudflare and Supabase connections and room for two Supabase projects
   (PD-F), and record its timings (closes PD-J).
