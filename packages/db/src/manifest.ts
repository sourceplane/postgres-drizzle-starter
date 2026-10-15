import type { MigrationManifest } from "./types.js";

// Every migration the runner applies, in order, with the sha256 of its file.
// `pnpm --filter @saas/db run manifest:check` verifies the checksums;
// `manifest:fix` rewrites them after a migration file changes (only ever
// before that migration has been applied anywhere — an applied migration's
// checksum is immutable).
export const manifest: MigrationManifest = {
  version: 1,
  migrations: [
    {
      id: "000_control_baseline",
      context: "control",
      path: "000_control/up.sql",
      checksum:
        "2a5d7f30684c99e3ff441ca8a2c38038dedd1bab4db4a40e92cd36bb22be297f",
      description:
        "Baseline control migration — creates the migration tracking schema",
    },
    {
      id: "010_profiles",
      context: "app",
      path: "010_profiles/up.sql",
      checksum:
        "21ec3e9a0fde10d759dcfcfb34a64c65c9af8ab9080436757aa0bced11446e0a",
      description:
        "The template's profiles table, as lib/drizzle.ts declares it (drizzle-kit's output, IF NOT EXISTS) — applied before the Worker serves instead of created by its first request; lib/migrations/0000_profiles.sql is the same SQL for drizzle-kit",
    },
    {
      id: "020_row_level_security",
      context: "app",
      path: "020_row_level_security/up.sql",
      checksum:
        "4294e5584ad83a1cf450e9480f5060d962f0ef2fb90ec5e0d27cadd938f7f2ee",
      description:
        "Row-level security, with no policies, on every table in public — closed to Supabase's Data API (anon, authenticated), open to the app, which owns them; refuses to run if the app's role would be locked out. lib/migrations/0001_row_level_security.sql is the same SQL for drizzle-kit",
    },
  ],
};
