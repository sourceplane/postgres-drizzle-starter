import {
  pgTable,
  serial,
  text,
  timestamp,
  uniqueIndex,
} from 'drizzle-orm/pg-core'
import { InferSelectModel, InferInsertModel } from 'drizzle-orm'
import { drizzle } from 'drizzle-orm/postgres-js'
import { getSql } from './db'

// The table lives in `public`, which Supabase's Data API (PostgREST) serves to
// anyone holding the project's anon key. It has row-level security ENABLED and
// no policy, so `anon` and `authenticated` read and write nothing through that
// API, while the app — which connects through Hyperdrive as the table's owner —
// is not subject to it. `.enableRLS()` is how drizzle-kit writes that into the
// migration; a new table declares it too, and tests/db fails on a table in
// `public` without it.
//
// The table itself is created by the migrations (packages/db, applied by
// db-migrate before the Worker deploys; `pnpm db:migrate` locally), never by
// the page.
export const UsersTable = pgTable(
  'profiles',
  {
    id: serial('id').primaryKey(),
    name: text('name').notNull(),
    email: text('email').notNull(),
    image: text('image').notNull(),
    createdAt: timestamp('createdAt').defaultNow().notNull(),
  },
  (users) => {
    return {
      uniqueIdx: uniqueIndex('unique_idx').on(users.email),
    }
  }
).enableRLS()

export type User = InferSelectModel<typeof UsersTable>
export type NewUser = InferInsertModel<typeof UsersTable>

// Connect to Postgres (per call — see lib/db.ts)
export const getDb = async () => drizzle(await getSql())
