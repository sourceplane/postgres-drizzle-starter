import type { Config } from 'drizzle-kit'

// drizzle-kit, for a LOCAL database only. `pnpm db:migrate` applies
// lib/migrations to POSTGRES_URL — by default the Supabase CLI's database, the
// one wrangler.jsonc's localConnectionString names — and `pnpm db:generate`
// writes the next migration after a change to the schema in lib/drizzle.ts.
// Stage and prod are migrated by db-migrate from packages/db/src/migrations:
// the same statements, which tests/db holds equal.
export default {
  schema: './lib/drizzle.ts',
  out: './lib/migrations',
  dialect: 'postgresql',
  dbCredentials: {
    url:
      process.env.POSTGRES_URL ??
      'postgres://postgres:postgres@localhost:54322/postgres',
  },
} satisfies Config
