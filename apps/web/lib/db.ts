import { getCloudflareContext } from '@opennextjs/cloudflare'
import postgres from 'postgres'

// One Postgres client per call. On the Worker the connection string is the
// HYPERDRIVE binding's (Cloudflare pools and caches the Supabase connection);
// without a Cloudflare context (`next dev` without wrangler, scripts) it is
// POSTGRES_URL, as the template had it. The Workers runtime refuses to reuse a
// socket across requests, which is why there is no module-level client.
export async function getSql(): Promise<postgres.Sql> {
  try {
    const { env } = await getCloudflareContext({ async: true })
    if (env.HYPERDRIVE?.connectionString) {
      return postgres(env.HYPERDRIVE.connectionString, {
        max: 5,
        fetch_types: false,
        prepare: false,
      })
    }
  } catch {
    // no Cloudflare context
  }
  return postgres(process.env.POSTGRES_URL!, { ssl: 'require' })
}
