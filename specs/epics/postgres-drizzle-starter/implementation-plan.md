# postgres-drizzle-starter — implementation plan

## PD0 — the spec

**Done when**
- the five documents and `epic.yaml` are on `main`
- `tasks/PD-1..PD-4.TaskContract.yaml` exist

## PD1 — the profiles table on Workers

**Done when**
- `pnpm install && pnpm run wire:fixture && pnpm typecheck && pnpm lint && pnpm test && pnpm build` is green locally and in `Checks`
- `wrangler dev` boots; `/` reaches for Postgres through the binding (with the Supabase CLI running locally the table seeds and three profiles render; without it the page errors on the connection, as upstream does without a database)

## PD2 — Supabase and Hyperdrive from Terraform

**Done when**
- `terraform validate` passes on both roots
- `hyperdrive_id` is the key the template's token names

## PD3 — ready to instantiate

**Done when**
- the README quick start works from a fresh clone
- the status file lists every PR and departure

## Sequencing note

PD1's component already names the Hyperdrive root's wiring secret; PD2
makes the name true. Applying PD2 needs a workspace with Supabase and
Cloudflare connections (the Hyperdrive token scope).
