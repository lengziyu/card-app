import { readFile } from 'node:fs/promises'

const [proConfigPath, target = 'ipa', apiBase = 'https://card.lengziyu.cn'] = process.argv.slice(2)

const fail = (message) => {
  console.error(`Store release preflight failed: ${message}`)
  process.exit(78)
}

let local
try {
  local = JSON.parse(await readFile(proConfigPath, 'utf8'))
} catch (error) {
  fail(`cannot read ${proConfigPath}: ${error.message}`)
}

const configUrl = new URL('/api/pro/config', apiBase).toString()
let remote
try {
  const response = await fetch(configUrl, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(15_000),
  })
  if (!response.ok) fail(`${configUrl} returned HTTP ${response.status}`)
  remote = await response.json()
} catch (error) {
  fail(`cannot read ${configUrl}: ${error.message}`)
}

const failures = []
const expectedStore = target === 'appbundle' ? 'googlePlay' : 'appStore'
if (remote?.enabled !== true) failures.push('remote Pro service is not enabled')
if (remote?.stores?.[expectedStore] !== true) {
  failures.push(`remote ${expectedStore} verification is not enabled`)
}
if (remote?.products?.monthly !== local.PRO_MONTHLY_PRODUCT_ID) {
  failures.push('monthly product ID does not match the remote service')
}
if (remote?.products?.yearly !== local.PRO_YEARLY_PRODUCT_ID) {
  failures.push('yearly product ID does not match the remote service')
}
if (
  local.ENABLE_PRO_LIFETIME === true &&
  remote?.products?.lifetime !== local.PRO_LIFETIME_PRODUCT_ID
) {
  failures.push('lifetime product ID does not match the remote service')
}

if (failures.length) fail(failures.join('; '))

console.log(
  `Store release preflight passed: ${target} billing is enabled and product IDs match ${configUrl}`,
)
