import { getSql } from './db'

// The template's three profiles, written by the page the first time it finds
// the table empty. Upstream also created the table here (`CREATE TABLE IF NOT
// EXISTS`) when the first select failed; that is the migrations' job now
// (packages/db, applied by db-migrate before the Worker serves), because two
// first requests racing through that DDL can both miss the table and one of
// them fails on Postgres's own catalog (`duplicate key value violates unique
// constraint "pg_type_typname_nsp_index"`). What is left is data, and it is
// safe to race: each insert is `ON CONFLICT (email) DO NOTHING` against the
// table's unique index, so any number of concurrent first requests leave
// exactly these three rows.
export async function seed() {
  const sql = await getSql()

  const profiles = await Promise.all([
    sql`
          INSERT INTO profiles (name, email, image)
          VALUES ('Guillermo Rauch', 'rauchg@vercel.com', 'https://images.ctfassets.net/e5382hct74si/2P1iOve0LZJRZWUzfXpi9r/9d4d27765764fb1ad7379d7cbe5f1043/ucxb4lHy_400x400.jpg')
          ON CONFLICT (email) DO NOTHING;
      `,
    sql`
          INSERT INTO profiles (name, email, image)
          VALUES ('Lee Robinson', 'lee@vercel.com', 'https://images.ctfassets.net/e5382hct74si/4BtM41PDNrx4z1ml643tdc/7aa88bdde8b5b7809174ea5b764c80fa/adWRdqQ6_400x400.jpg')
          ON CONFLICT (email) DO NOTHING;
      `,
    sql`
          INSERT INTO profiles (name, email, image)
          VALUES ('Steven Tey', 'stey@vercel.com', 'https://images.ctfassets.net/e5382hct74si/4QEuVLNyZUg5X6X4cW4pVH/eb7cd219e21b29ae976277871cd5ca4b/profile.jpg')
          ON CONFLICT (email) DO NOTHING;
      `,
  ])
  console.log(`Seeded ${profiles.length} users`)

  return {
    insertedUsers: profiles,
  }
}
