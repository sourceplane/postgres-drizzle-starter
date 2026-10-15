-- The same SQL as packages/db/src/migrations/010_profiles/up.sql (which says
-- why), for drizzle-kit (`pnpm db:migrate`) against a local database.
-- drizzle-kit's own output for lib/drizzle.ts, with IF NOT EXISTS added.
CREATE TABLE IF NOT EXISTS "profiles" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"image" text NOT NULL,
	"createdAt" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "unique_idx" ON "profiles" USING btree ("email");
