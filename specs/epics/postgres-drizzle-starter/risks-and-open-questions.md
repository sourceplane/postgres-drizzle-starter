# postgres-drizzle-starter — risks and open questions

## PD-A — A client per request (ACCEPTED)

Hyperdrive pools on Cloudflare's side, so opening a `postgres` client per
request costs a connection to the nearest Hyperdrive, not to Supabase. The
same rule Lumen's workers follow (`executor.ts`): a module-level client
fails with "Cannot perform I/O on behalf of a different request".

## PD-B — Seed on first use against a pooled connection (REVERSED in PD4)

PD0 accepted it: "`CREATE TABLE IF NOT EXISTS` and `ON CONFLICT DO NOTHING`
make the seed idempotent, so two first requests racing through Hyperdrive are
harmless." The first half is wrong. `IF NOT EXISTS` is checked before the
catalog insert, not under a lock, so two sessions can both find no table and
both create it; the loser fails on Postgres's own unique index
(`duplicate key value violates unique constraint "pg_type_typname_nsp_index"`,
or `pg_class_relname_nsp_index`). Measured on Postgres 16 with upstream's DDL:
2 of 160 sessions failed across 20 rounds of 8 racing sessions — and a failure
in `seed()` is a 500 for that visitor. The schema is therefore `db-migrate`'s
(PD4), applied before the Worker deploys. The seed's INSERTs stay with the
page and are safe to race: `ON CONFLICT (email) DO NOTHING` against the
table's unique index is atomic, and the e2e races eight first requests to
prove it.

## PD-C — The verify lane and `wrangler dev` without a database (RESOLVED)

The build does not touch the database (the page is `force-dynamic`).
`wrangler dev` points the binding at the Supabase CLI's local Postgres
(`localConnectionString`); without one running, the page errors on the
connection, which is what upstream does without `POSTGRES_URL`.

## PD-E — Supabase's Data API and a table with no RLS (RESOLVED in PD4)

Upstream assumed a private Postgres. A Supabase project serves `public`
through PostgREST to anyone with the project's anon key, which is public by
design, so `profiles` would have been readable and writable from the
internet. Migration `020_row_level_security` enables RLS with no policy (the
app does not use the Data API or Supabase Auth): `anon` and `authenticated`
get nothing, and the app — which connects as `postgres`, the table's owner —
is not subject to it. Its guard refuses to run if `postgres` would be locked
out. `tests/db` fails on any table in `public` without RLS.

## PD-F — Two Supabase projects per product (OWNER PREREQUISITE)

Stage and prod are separate projects, and Supabase's free plan allows two
active projects per organization. The card's description and BOOTSTRAP.md
say so; an org without room fails the supabase apply ("project limit"),
nothing downstream runs, and a re-run after freeing room adopts what exists.

## PD-G — The build's site origin had an empty subdomain (RESOLVED in PD4)

PD1's `buildCommand` built `NEXT_PUBLIC_SITE_URL` from
`${WORKERS_DEV_SUBDOMAIN}`, which the workers-assets composition exports to
the smoke step only: every deployed build would have baked
`https://<worker>-<env>..workers.dev` into the Open Graph link. The subdomain
is written out now (as portfolio-starter-kit does) and the rebrand rewrites
it; `SITE_URL` under an environment's `env:` overrides it for a custom
domain.

## PD-H — The migrations package is named `@saas/db` (ACCEPTED)

stack-tectonic's `db-migrate` composition (0.19.0) builds
`--filter=@saas/db` and runs `dist/runner/cli.js` two levels above the
component's `path`. Lumen's package carries that name, so this one does too;
it is a build-system name, not this product's.

## PD-D — Drizzle 0.28 → current (RESOLVED)

The schema's extra-config callback returns an object, which the current
line still accepts (deprecated in favour of an array). Kept as written.
