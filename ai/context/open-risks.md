# postgres-drizzle-starter — open risks

What is not yet proven or not yet decided. The full write-up of every risk,
including the accepted and resolved ones, is
`specs/epics/postgres-drizzle-starter/risks-and-open-questions.md`; this page
lists only what is still live, so it should be short.

| ID | Risk | State | What closes it |
|---|---|---|---|
| PD-J | No live bootstrap yet: the repository created and linked, the five keys minted, real Terraform applies of the Supabase projects and Hyperdrive configs, a `db-migrate` apply against a real Supabase project, a real `wrangler deploy`, Hyperdrive's read cache and the probes are all unproven | OPEN | One bootstrap from a tag against a workspace with Cloudflare and Supabase connections |

Accepted, and worth knowing before you change them: PD-A (a client per
request), PD-F (two Supabase projects per product — an owner prerequisite on
the free plan), PD-H (the migrations package is named `@saas/db`).
