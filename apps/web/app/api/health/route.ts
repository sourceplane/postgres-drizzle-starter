import { getSql } from '@/lib/db'

// Not upstream's: the deploy's smoke check and the bootstrap's probes read
// this. The home page proves the Worker deployed; this proves what a page
// render cannot say on its own — the HYPERDRIVE binding names a real config,
// Hyperdrive reaches the Supabase database, and db-migrate applied the schema:
// the `profiles` table exists, with row-level security on.
export const dynamic = 'force-dynamic'

export async function GET() {
  const headers = { 'cache-control': 'no-store' }
  try {
    const sql = await getSql()
    const [row] = await sql<{ profiles: string | null; rls: boolean }[]>`
      select to_regclass('public.profiles')::text as profiles,
             coalesce((select relrowsecurity from pg_class
                        where oid = to_regclass('public.profiles')), false) as rls`
    const ok = Boolean(row?.profiles) && row?.rls === true
    return Response.json(
      { ok, database: 'reachable', schema: ok ? 'migrated' : 'missing' },
      { status: ok ? 200 : 503, headers }
    )
  } catch (error) {
    console.error('health: database check failed', error)
    return Response.json(
      { ok: false, database: 'unreachable' },
      { status: 503, headers }
    )
  }
}
