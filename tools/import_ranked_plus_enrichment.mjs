#!/usr/bin/env node

/**
 * Enrich existing card records from Ranked+ without importing referrals.
 *
 * The source endpoint is a TanStack Start server function. It returns a
 * Seroval payload rather than ordinary JSON, hence the small decoder below.
 * This tool only updates existing records through the protected card API;
 * it never creates cards and never stores selectUrl, promoCode, promoCodeBonus,
 * inviteCode, or inviteUrl from the source.
 *
 * Examples:
 *   node tools/import_ranked_plus_enrichment.mjs
 *   node tools/import_ranked_plus_enrichment.mjs --only coinbase,kast
 *   CARD_ADMIN_TOKEN='…' node tools/import_ranked_plus_enrichment.mjs --apply
 */

const sourceUrl = 'https://ranked.plus/_serverFn/be96b738cf59ba8bfd779130d0163fee84df1cd2bac1a3e48f4d947f51db71b9'
const apiBaseUrl = (process.env.CARD_API_BASE_URL || 'https://card.lengziyu.cn').replace(/\/+$/, '')
const adminToken = String(process.env.CARD_ADMIN_TOKEN || '').trim()
const args = new Set(process.argv.slice(2))
const onlyArg = process.argv.find((arg) => arg.startsWith('--only=')) ||
  (process.argv.includes('--only') ? process.argv[process.argv.indexOf('--only') + 1] : '')
const requestedIds = new Set(String(onlyArg || '').replace(/^--only=/, '').split(',').map((id) => id.trim()).filter(Boolean))
const apply = args.has('--apply')

const rankedToLocalId = {
  'avalanche-card': 'avalanche',
  avici: 'avici',
  'bitget-wallet-card': 'bitget-wallet',
  'bitpanda-card': 'bitpanda',
  bleap: 'bleap',
  coca: 'coca',
  'coinbase-card': 'coinbase',
  cypher: 'cypher',
  'ether-fi-cash': 'etherfi-core',
  exa: 'exa',
  'gnosis-pay': 'gnosis-pay',
  hawala: 'hawala',
  holyheld: 'holyheld',
  hyperbeat: 'hyperbeat',
  'jam-card': 'jam',
  karta: 'karta',
  kast: 'kast',
  kolo: 'kolo',
  krak: 'krak',
  'lava-card': 'lava',
  'metamask-card': 'metamask',
  oobit: 'oobit',
  'plasma-one': 'plasma-one',
  ready: 'ready',
  'redot-pay': 'redotpay',
  'revolut-crypto': 'revolut-crypto',
  safepal: 'safepal',
  solayer: 'solayer',
  solflare: 'solflare',
  tangem: 'tangem',
  tria: 'tria',
  tuyo: 'tuyo',
  wirex: 'wirex',
  xplace: 'xplace'
}

function usage(exitCode = 0) {
  console.log(`Usage: node tools/import_ranked_plus_enrichment.mjs [--only id,id] [--apply]

Default mode is dry-run. --apply requires CARD_ADMIN_TOKEN and updates only
existing cards. Referral URLs, promo codes, and invite fields are discarded.`)
  process.exit(exitCode)
}

if (args.has('--help') || args.has('-h')) usage()
if (apply && !adminToken) {
  console.error('--apply requires CARD_ADMIN_TOKEN.')
  process.exit(2)
}

function decodeSeroval(value, references = new Map()) {
  if (!value || typeof value !== 'object' || !('t' in value)) return value
  if (references.has(value.i)) return references.get(value.i)

  switch (value.t) {
    case 1:
      return value.s
    case 2:
      return value.n
    case 3:
      return value.b
    case 9: {
      const result = []
      references.set(value.i, result)
      result.push(...(value.a || []).map((item) => decodeSeroval(item, references)))
      return result
    }
    case 10:
    case 11: {
      const result = value.t === 10 ? {} : Object.create(null)
      references.set(value.i, result)
      for (let index = 0; index < value.p.k.length; index += 1) {
        result[value.p.k[index]] = decodeSeroval(value.p.v[index], references)
      }
      return result
    }
    default:
      throw new Error(`Unsupported Ranked+ serialized value type: ${value.t}`)
  }
}

function nonEmpty(value) {
  return typeof value === 'string' && value.trim() !== '' && value.trim() !== '—'
}

function uniqueText(values) {
  return [...new Set(values.map((value) => String(value || '').trim()).filter(Boolean))]
}

function mergeDelimitedText(values) {
  return [...new Set(
    values
      .flatMap((value) => String(value || '').split('；'))
      .map((value) => value.trim())
      .filter(Boolean)
  )].join('；')
}

function mergeFee(fees, label, value, note, legacyLabel = `Ranked+ ${label}`) {
  if (!nonEmpty(value)) return fees
  const next = { label, value: note ? `${value}；${note}` : value }
  return [...fees.filter((fee) => fee?.label !== label && fee?.label !== legacyLabel), next]
}

function mergeBenefit(benefits, icon, text) {
  if (!text) return benefits
  return uniqueText(benefits.map((benefit) => benefit?.text)).includes(text)
    ? benefits
    : [...benefits, { icon, text }]
}

function paymentSupportFromRanked(card) {
  const supported = new Set(Array.isArray(card.paymentMethods) ? card.paymentMethods : [])
  const checkedAt = new Date().toISOString().slice(0, 10)
  return {
    applePay: supported.has('apple') ? { status: 'supported', sourceUrl, checkedAt } : undefined,
    googlePay: supported.has('google') ? { status: 'supported', sourceUrl, checkedAt } : undefined
  }
}

function mergePaymentSupport(current, ranked) {
  const additions = paymentSupportFromRanked(ranked)
  return {
    ...(current || {}),
    // An explicit Ranked+ capability is intentionally allowed to replace an
    // earlier conditional record. This is the requested Coinbase behaviour.
    ...(additions.applePay ? { applePay: additions.applePay } : {}),
    ...(additions.googlePay ? { googlePay: additions.googlePay } : {})
  }
}

function enrichCard(record, ranked, rules) {
  const methods = uniqueText(ranked.fundingMethods || [])
  const useCases = uniqueText(ranked.bestFor || [])
  const supported = rules?.supported?.length || 0
  const excluded = rules?.excluded?.length || 0
  let fees = Array.isArray(record.fees) ? record.fees : []
  fees = mergeFee(fees, '月费', ranked.monthlyFeeMin, ranked.monthlyFeeNotes, 'Ranked+ 月费起')
  fees = mergeFee(fees, '外汇费', ranked.fxFee, ranked.fxFeeNotes)
  fees = mergeFee(fees, '取现手续费', ranked.atmFee, ranked.atmNotes, 'Ranked+ ATM 取现费')

  let benefits = Array.isArray(record.benefits) ? record.benefits : []
  benefits = mergeBenefit(benefits, 'wallet', methods.length ? `入金方式：${methods.join('、')}` : '')
  benefits = mergeBenefit(benefits, 'payments', useCases.length ? `适用场景：${useCases.join('、')}` : '')
  benefits = mergeBenefit(
    benefits,
    'market',
    nonEmpty(ranked.cashbackConditions) ? `返现规则：${ranked.cashbackConditions.replace(/\s+/g, ' ').trim()}` : ''
  )

  const cashback = [ranked.baseCashback, ranked.maxCashback]
    .filter(nonEmpty)
    .filter((value, index, values) => values.indexOf(value) === index)
    .join(' / ')
  const regionNote = supported || excluded
    ? `可用性：支持 ${supported} 个国家/地区，排除 ${excluded} 个国家/地区。`
    : ''
  benefits = mergeBenefit(
    benefits,
    'market',
    nonEmpty(ranked.cashbackLimit) ? `返现限制：${ranked.cashbackLimit}` : ''
  )
  benefits = mergeBenefit(
    benefits,
    'wallet',
    nonEmpty(ranked.paidIn) ? `返现发放：${ranked.paidIn}` : ''
  )
  benefits = mergeBenefit(
    benefits,
    'market',
    nonEmpty(ranked.savingsApyMin) || nonEmpty(ranked.savingsApyMax)
      ? `储蓄 APY：${[ranked.savingsApyMin, ranked.savingsApyMax].filter(nonEmpty).join(' / ')}`
      : ''
  )
  const region = mergeDelimitedText([record.region, regionNote, ranked.availabilityNote])

  return {
    ...record,
    cashbackRate: cashback || record.cashbackRate,
    rankTier: `评级：${ranked.tier || '未分级'}`,
    tags: uniqueText([
      ...(record.tags || []).filter((tag) => !String(tag || '').startsWith('Ranked+')),
      `评级：${ranked.tier || '未分级'}`,
      ranked.kyc ? `KYC：${ranked.kyc}` : ''
    ]),
    benefits,
    fees,
    region,
    funding: methods.length ? methods.join('、') : record.funding,
    paymentSupport: mergePaymentSupport(record.paymentSupport, ranked),
    // The existing public API deliberately exposes these fields; blanking
    // them makes this import idempotent and removes any legacy crawler data.
    inviteCode: '',
    inviteUrl: '',
    updatedAt: new Date().toISOString()
  }
}

async function fetchRankedCards() {
  const response = await fetch(sourceUrl, {
    headers: {
      'x-tsr-serverfn': 'true',
      accept: 'application/json, application/x-ndjson, application/json',
      referer: 'https://ranked.plus/',
      'user-agent': 'CardFiCatalogReview/1.0'
    },
    signal: AbortSignal.timeout(30_000)
  })
  if (!response.ok) throw new Error(`Ranked+ source request failed: HTTP ${response.status}`)
  const serialized = await response.json()
  const decoded = decodeSeroval(serialized)
  if (!Array.isArray(decoded?.result?.cards)) throw new Error('Ranked+ response did not contain cards.')
  return decoded.result
}

async function fetchAdminCard(id) {
  const response = await fetch(`${apiBaseUrl}/api/admin/cards/${encodeURIComponent(id)}`, {
    headers: { authorization: `Bearer ${adminToken}`, accept: 'application/json' },
    signal: AbortSignal.timeout(30_000)
  })
  const body = await response.json().catch(() => null)
  if (!response.ok) throw new Error(`Unable to read ${id}: HTTP ${response.status}`)
  if (body?.item) return body.item

  // Seeded cards have no admin override yet, so the protected endpoint returns
  // `{ item: null }`. Rebuild an editable record from the public card and
  // detail responses before creating its first override.
  const publicResponse = await fetch(`${apiBaseUrl}/api/cards/${encodeURIComponent(id)}`, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(30_000)
  })
  const publicBody = await publicResponse.json().catch(() => null)
  if (!publicResponse.ok || !publicBody?.item || !publicBody?.detail) {
    throw new Error(`Unable to build seeded card ${id}: HTTP ${publicResponse.status}`)
  }
  const item = publicBody.item
  const detail = publicBody.detail
  const reference = detail.referenceInfo || {}
  return {
    id: item.id,
    name: item.name,
    issuer: item.issuer,
    category: item.category,
    status: 'published',
    network: item.suffix || item.meta || '',
    logo: item.logo || '',
    logoText: item.logoText || '',
    suffix: item.suffix || '',
    suffixType: item.suffixType || 'text',
    featured: item.featured === true,
    rankTier: '',
    cashbackRate: item.cashbackRate || '',
    rating: Number(detail.rating) || 0,
    reviews: Number(detail.reviews) || 0,
    tags: Array.isArray(detail.tags) ? detail.tags : [],
    benefits: Array.isArray(detail.benefits) ? detail.benefits : [],
    fees: Array.isArray(detail.fees) ? detail.fees : [],
    region: detail.region || '',
    funding: detail.funding || '',
    speed: detail.speed || '',
    applyUrl: detail.applyUrl || item.sourceUrl || '',
    inviteCode: '',
    inviteUrl: '',
    sourceUrl: item.sourceUrl || reference.sourceUrl || '',
    sourceName: item.sourceName || reference.sourceName || '',
    material: item.meta || reference.material || '',
    kycFact: detail.kycFact || undefined,
    paymentSupport: detail.paymentSupport || {},
    screenshotSrc: '',
    cardImageSrc: item.cardImageSrc || '',
    logoImageSrc: item.logoImageSrc || '',
    createdAt: item.createdAt || new Date().toISOString(),
    updatedAt: item.updatedAt || new Date().toISOString()
  }
}

async function fetchPublicCardIds() {
  const response = await fetch(`${apiBaseUrl}/api/cards?offset=0&limit=500`, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(30_000)
  })
  const body = await response.json().catch(() => null)
  if (!response.ok || !Array.isArray(body?.items)) {
    throw new Error(`Unable to read the public card catalog: HTTP ${response.status}`)
  }
  return new Set(body.items.map((item) => String(item?.id || '').trim()).filter(Boolean))
}

async function writeAdminCard(card) {
  const response = await fetch(`${apiBaseUrl}/api/admin/cards/${encodeURIComponent(card.id)}`, {
    method: 'PUT',
    headers: {
      authorization: `Bearer ${adminToken}`,
      'content-type': 'application/json',
      accept: 'application/json'
    },
    body: JSON.stringify(card),
    signal: AbortSignal.timeout(30_000)
  })
  if (!response.ok) throw new Error(`Unable to update ${card.id}: HTTP ${response.status} ${await response.text()}`)
}

const rankedPayload = await fetchRankedCards()
const mapped = rankedPayload.cards
  .map((ranked) => ({ ranked, localId: rankedToLocalId[ranked.id] }))
  .filter((item) => item.localId)
let selected = mapped.filter((item) => !requestedIds.size || requestedIds.has(item.localId))

const unknownRequested = [...requestedIds].filter((id) => !mapped.some((item) => item.localId === id))
if (unknownRequested.length) {
  console.error(`No Ranked+ mapping for: ${unknownRequested.join(', ')}`)
  process.exit(2)
}

const publicCardIds = await fetchPublicCardIds()
const unavailable = selected.filter(({ localId }) => !publicCardIds.has(localId))
if (unavailable.length) {
  console.warn(`Skipped unavailable public card(s): ${unavailable.map(({ localId }) => localId).join(', ')}`)
  selected = selected.filter(({ localId }) => publicCardIds.has(localId))
}

console.log(`${apply ? 'Applying' : 'Dry run'}: ${selected.length} existing card record(s).`)
const failures = []
for (const { ranked, localId } of selected) {
  if (!apply) {
    console.log(`${localId}\t${ranked.name}\t${ranked.baseCashback}–${ranked.maxCashback}\t${ranked.fxFee}\t${ranked.monthlyFeeMin}`)
    continue
  }
  try {
    const current = await fetchAdminCard(localId)
    const updated = enrichCard(current, ranked, rankedPayload.rules?.[ranked.id])
    const serialized = JSON.stringify(updated).toLowerCase()
    if (serialized.includes('promocode') || serialized.includes('selecturl')) {
      throw new Error(`Unsafe referral field found in ${localId}; refusing to write.`)
    }
    await writeAdminCard(updated)
    console.log(`Updated ${localId}; referrals and invite fields cleared.`)
  } catch (error) {
    failures.push(`${localId}: ${error instanceof Error ? error.message : String(error)}`)
    console.error(`Skipped ${failures.at(-1)}`)
  }
}

if (failures.length) {
  console.error(`Completed with ${failures.length} failed card(s): ${failures.join(' | ')}`)
  process.exitCode = 1
}
