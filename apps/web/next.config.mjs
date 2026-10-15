import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { initOpenNextCloudflareForDev } from '@opennextjs/cloudflare'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// `next dev` reaches the Hyperdrive binding through wrangler's local
// platform proxy (render apps/web/wrangler.jsonc first: `pnpm run wire:fixture`).
initOpenNextCloudflareForDev()

/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [{ protocol: 'https', hostname: 'images.ctfassets.net' }],
  },
  output: 'standalone',
  outputFileTracingRoot: path.join(__dirname, '../..'),
}

export default nextConfig
