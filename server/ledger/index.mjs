import { mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { LedgerStore } from './store.mjs'
import { ledgerServer, supabaseVerifier, legacyBillLoader } from './http.mjs'

const rawKey = process.env.LEDGER_ENCRYPTION_KEY ?? ''
if (!/^[0-9a-fA-F]{64}$/.test(rawKey)) throw new Error('Set LEDGER_ENCRYPTION_KEY to a secure random 32-byte hex key')
if (process.env.LEDGER_ENABLED === 'true' && (process.env.LEDGER_DELETION_SECRET?.length ?? 0) < 32) throw new Error('Configure LEDGER_DELETION_SECRET and the identity deletion callback before enabling the ledger')
const file = resolve(process.env.LEDGER_DATABASE_PATH ?? fileURLToPath(new URL('./data/ledger.sqlite', import.meta.url)))
mkdirSync(dirname(file), { recursive: true, mode: 0o700 })
const store = new LedgerStore(file, Buffer.from(rawKey, 'hex'))
const server = ledgerServer({
  store,
  verify: supabaseVerifier({ origin: process.env.SUPABASE_URL, publicKey: process.env.SUPABASE_ANON_KEY }),
  loadBill: legacyBillLoader({ origin: process.env.CARD_API_ORIGIN ?? 'https://card.lengziyu.cn' }),
  enabled: process.env.LEDGER_ENABLED === 'true',
  deletionSecret: process.env.LEDGER_DELETION_SECRET,
})
server.requestTimeout = 30000
server.headersTimeout = 10000
server.listen(Number(process.env.LEDGER_PORT ?? 51713), '127.0.0.1')
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close(() => { store.close(); process.exit(0) }))
