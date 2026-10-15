import { sql } from 'drizzle-orm'
import { getDb, UsersTable } from '@/lib/drizzle'
import { timeAgo } from '@/lib/utils'
import Image from 'next/image'
import RefreshButton from './refresh-button'
import { seed } from '@/lib/seed'

export default async function Table() {
  let users
  let startTime = Date.now()
  const db = await getDb()
  try {
    users = await db.select().from(UsersTable)
  } catch (e: any) {
    if (e.message === `relation "profiles" does not exist`) {
      // The migrations have not run against this database. The page never
      // creates the table (lib/seed.ts says why); it says what to do instead.
      return <MigrationsPending />
    }
    throw e
  }
  if (users.length === 0) {
    console.log('Table is empty, seeding it with dummy data now...')
    await seed()
    startTime = Date.now()
    // Hyperdrive caches read queries for up to a minute and does not
    // invalidate them on a write, so the plain select above may keep
    // answering with the empty table for a while yet. Read back what the
    // seed wrote with a query it never caches: one that calls NOW(), a STABLE
    // function (Hyperdrive caches only queries whose functions are IMMUTABLE).
    users = await db
      .select()
      .from(UsersTable)
      .where(sql`now() is not null`)
  }

  const duration = Date.now() - startTime

  return (
    <div className="bg-white/30 p-12 shadow-xl ring-1 ring-gray-900/5 rounded-lg backdrop-blur-lg max-w-xl mx-auto w-full">
      <div className="flex justify-between items-center mb-4">
        <div className="space-y-1">
          <h2 className="text-xl font-semibold">Recent Users</h2>
          <p className="text-sm text-gray-500">
            Fetched {users.length} users in {duration}ms
          </p>
        </div>
        <RefreshButton />
      </div>
      <div className="divide-y divide-gray-900/5">
        {users.map((user) => (
          <div
            key={user.name}
            className="flex items-center justify-between py-3"
          >
            <div className="flex items-center space-x-4">
              <Image
                src={user.image}
                alt={user.name}
                width={48}
                height={48}
                className="rounded-full ring-1 ring-gray-900/5"
              />
              <div className="space-y-1">
                <p className="font-medium leading-none">{user.name}</p>
                <p className="text-sm text-gray-500">{user.email}</p>
              </div>
            </div>
            <p className="text-sm text-gray-500">{timeAgo(user.createdAt)}</p>
          </div>
        ))}
      </div>
    </div>
  )
}

function MigrationsPending() {
  return (
    <div
      data-schema="missing"
      className="bg-white/30 p-12 shadow-xl ring-1 ring-gray-900/5 rounded-lg backdrop-blur-lg max-w-xl mx-auto w-full"
    >
      <h2 className="text-xl font-semibold">The profiles table does not exist yet</h2>
      <p className="text-sm text-gray-500 mt-2">
        Apply the migrations to this database: <code>pnpm --filter @app/web db:migrate</code>{' '}
        locally; on stage and prod, db-migrate applies them before the app deploys.
      </p>
    </div>
  )
}
