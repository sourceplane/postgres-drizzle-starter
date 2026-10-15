# postgres-drizzle-starter — risks and open questions

## PD-A — A client per request (ACCEPTED)

Hyperdrive pools on Cloudflare's side, so opening a `postgres` client per
request costs a connection to the nearest Hyperdrive, not to Supabase. The
same rule Lumen's workers follow (`executor.ts`): a module-level client
fails with "Cannot perform I/O on behalf of a different request".

## PD-B — Seed on first use against a pooled connection (ACCEPTED, as upstream)

`CREATE TABLE IF NOT EXISTS` and `ON CONFLICT DO NOTHING` make the seed
idempotent, so two first requests racing through Hyperdrive are harmless.

## PD-C — The verify lane and `wrangler dev` without a database (RESOLVED)

The build does not touch the database (the page is `force-dynamic`).
`wrangler dev` points the binding at the Supabase CLI's local Postgres
(`localConnectionString`); without one running, the page errors on the
connection, which is what upstream does without `POSTGRES_URL`.

## PD-D — Drizzle 0.28 → current (RESOLVED)

The schema's extra-config callback returns an object, which the current
line still accepts (deprecated in favour of an array). Kept as written.
