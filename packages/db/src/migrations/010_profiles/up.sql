-- The template's one table, as lib/drizzle.ts declares it (drizzle-kit's
-- output for that schema; apps/web/lib/migrations/0000_profiles.sql is the
-- same SQL for drizzle-kit against a local database).
--
-- Upstream created the table from the page: on `relation "profiles" does not
-- exist` the first request ran `CREATE TABLE IF NOT EXISTS` itself. Two first
-- requests racing through that DDL can both miss the table, and one then fails
-- on Postgres's own catalog (`duplicate key value violates unique constraint
-- "pg_type_typname_nsp_index"`), so the schema is applied here instead,
-- before the Worker deploys. The page still writes the three seed rows the
-- first time it finds the table empty (lib/seed.ts); those inserts are safe to
-- race.
--
-- Idempotent, as every migration here must be: the Supabase Management API
-- adapter sends each one in autocommit mode, and a database the old page
-- already created the table in keeps it.
CREATE TABLE IF NOT EXISTS "profiles" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"image" text NOT NULL,
	"createdAt" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "unique_idx" ON "profiles" USING btree ("email");
