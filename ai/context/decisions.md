# postgres-drizzle-starter — decisions

The choices that shape this repository, one line each, with where the full
reasoning lives. Superseded decisions stay listed, marked, so the history
reads in order.

| # | Decision | Why | Source |
|---|---|---|---|
| 1 | A Postgres client per request (`getSql()`/`getDb()`), Hyperdrive's connection string first, `POSTGRES_URL` as the fallback without a Cloudflare context | The Workers runtime refuses to share a socket across requests; Hyperdrive pools on Cloudflare's side | `specs/epics/postgres-drizzle-starter/design.md` §2, risk PD-A |
| 2 | Drizzle over a socket to Supabase Postgres through Hyperdrive, not Supabase's PostgREST client | The template's point is Drizzle and its schema file; PostgREST would replace both | design.md §2 |
| 3 | The `profiles` table is `db-migrate`'s (`packages/db`), applied before the Worker deploys; the page seeds only rows, on an empty table — superseding PD0's "seed on first use, no migrations for one table" | `CREATE TABLE IF NOT EXISTS` is not safe under concurrent first requests (2 of 160 racing sessions failed) | risk PD-B, IMPLEMENTATION-STATUS (PD4) |
| 4 | Row-level security on every table in `public`, with no policy | Supabase's Data API serves `public` to the public anon key; the app connects as the table's owner | risk PD-E |
| 5 | `wrangler.jsonc` committed as the fixture render; stage and prod re-render it from their wiring document | The composition checks for it before the build | epic README (decision 3), design.md §4 |
| 6 | One landing (`01-product`) then the record (`02-docs`); every edge `mode: enforced` on main, advisory on a pull request | One convergence runs supabase → cloudflare-hyperdrive → db-migrate → web per environment (cirrus-baseline v22's shape) | IMPLEMENTATION-STATUS (PD4), design.md §4 |
| 7 | The migrations package is named `@saas/db` | stack-tectonic's db-migrate composition builds `--filter=@saas/db` | risk PD-H |
| 8 | The read-back after a seed calls `NOW()` | Hyperdrive's read cache would otherwise serve the empty answer for up to a minute | risk PD-I |
| 9 | `ci.yml` plans nothing while `intent.yaml` names `ws_CHANGE_ME` (the `linked` step) | A bootstrap cannot set a repository variable (replaced the `ORUN_CI` gate) | IMPLEMENTATION-STATUS (PD4) |
| 10 | stack-tectonic 0.19.0, not 0.20.0 | 0.20.0's lane-scoped install is refused by Turbopack | IMPLEMENTATION-STATUS (PD4) |
| 11 | orun is pinned only where it runs (the `orun-action` `version:` in each workflow); no kiox | `kiox.yaml` pinned a version (v2.15.0) nothing ran | IMPLEMENTATION-STATUS (PD5) |
| 12 | Component docs are generated from the manifests and checked in CI | A hand-written copy of the dependency graph, bindings and migrations drifts silently | `tooling/catalog/gen-component-docs.py` |
| 13 | The console card reads `subdomain` from the Cloudflare connection (`from: connection.cloudflare.workersSubdomain`); only a hand-run build passes it | It belongs to the account like its id and has one right answer; a typed one could only be wrong, and wrong showed up after deploy (cirrus-baseline since baseline-v23) | `blueprint.yaml`, IMPLEMENTATION-STATUS (PD-7) |
| 14 | The console asks for no domain; an empty `productdomain` brands the placeholder `<reponame>.example.com` | The app goes live on workers.dev and nothing in the build needs a domain (the origin is `SITE_URL`, else workers.dev); attaching one is an owner's step, and the placeholder keeps the place the domain goes in the repository, ready to replace | `repo-blueprint.yaml`, `tooling/rebrand/rebrand.mjs`, IMPLEMENTATION-STATUS (PD-8) |
| 15 | The turso-starter v8 shape on orun v2.88.0: no `checks.yml` (a product carries `ci.yml` alone); the brokered keys in one `secrets` reconcile per provider; every component's generated pages attached in `spec.docs`, and the app's domain `app`, not `web`; the task set-up in the background, each landing checked in the box (`checks: local`), the watch at 5 s, and no await of what the convergence already resolves | A bootstrap waited on things that did not need waiting for (a runner's plan of a tree in the box, the task plane, one platform round trip per key); the catalog attached no docs and the `web` domain hid the `web` component; a green convergence already proves every published key, because each is resolved fail-closed by a job that waits for its publisher | `repo-blueprint.yaml`, `testing/phases.test.sh`, `testing/coverage.test.sh` (PD7) |
