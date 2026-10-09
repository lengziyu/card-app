import { randomUUID, createHash } from 'node:crypto'

export class LedgerError extends Error {
  constructor(status, code, message) { super(message); Object.assign(this, { status, code }) }
}
export const fail = (message, status = 400, code = 'INVALID_LEDGER_INPUT') => {
  throw new LedgerError(status, code, message)
}
export const emptyLedger = () => ({ version: 1, cards: [], entries: [], operations: {} })
const scale = 100000000n
export function amount(value, positive = false) {
  if (typeof value !== 'string' || !/^\d{1,12}(?:\.\d{1,8})?$/.test(value)) fail('金额最多支持 12 位整数和 8 位小数')
  const [whole, fraction = ''] = value.split('.')
  const units = BigInt(whole) * scale + BigInt(fraction.padEnd(8, '0'))
  if (positive && units <= 0n) fail('金额必须大于 0')
  return units
}
export function decimal(units) {
  const sign = units < 0n ? '-' : ''
  const n = units < 0n ? -units : units
  const tail = (n % scale).toString().padStart(8, '0').replace(/0+$/, '')
  return `${sign}${n / scale}${tail ? `.${tail}` : ''}`
}
function text(value, max, required = false, multiline = false) {
  if (value == null && !required) return ''
  const controls = multiline ? /[\x00-\x08\x0b\x0c\x0e-\x1f]/ : /[\x00-\x1f]/
  if (typeof value !== 'string' || value.length > max || controls.test(value)) fail('文字格式或长度不正确')
  const result = value.trim()
  if (required && !result) fail('请补全必填信息')
  // Free text must not become an alternate place to save a full card number.
  if (/(?:\d[\s-]?){12,19}/.test(result.normalize('NFKC'))) fail('请勿填写完整卡号或其他敏感号码')
  return result
}
export function identifier(value) {
  if (typeof value !== 'string' || !/^[a-zA-Z0-9_-]{1,160}$/.test(value)) fail('记录标识无效')
  return value
}
function oneOf(value, values) {
  if (!values.includes(value)) fail('记录类型或状态无效')
  return value
}
export function day(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value) ||
      !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0, 10) !== value ||
      value < '1900-01-01' || value > '2199-12-31') fail('日期无效')
  return value
}
function money(value, positive = true) {
  if (!value || typeof value !== 'object') fail('请填写金额和币种')
  const currency = typeof value.currency === 'string' ? value.currency.trim().toUpperCase() : ''
  if (!/^[A-Z][A-Z0-9]{1,11}$/.test(currency)) fail('请填写有效币种代码')
  return { amount: decimal(amount(value.amount, positive)), currency }
}
function assertKeys(value, allowed) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) fail('请求格式无效')
  if (Object.keys(value).some(key => !allowed.includes(key))) fail('请求包含不支持的字段')
}
function cardInput(input) {
  assertKeys(input, ['catalogCardId', 'productName', 'nickname', 'last4', 'form', 'archived', 'requestId', 'expectedRevision'])
  const last4 = input.last4 ?? ''
  if (typeof last4 !== 'string' || !/^(?:\d{4})?$/.test(last4)) fail('卡号末四位必须是 4 位数字，或留空')
  return {
    catalogCardId: identifier(input.catalogCardId), productName: text(input.productName, 100, true),
    nickname: text(input.nickname, 40), last4,
    form: oneOf(input.form ?? 'unspecified', ['unspecified', 'physical', 'virtual']),
    archived: input.archived === true,
  }
}
function entryInput(input) {
  assertKeys(input, ['userCardId', 'type', 'state', 'occurredOn', 'money', 'original', 'fee', 'note', 'relatedEntryId', 'sourceBillId', 'requestId', 'expectedRevision'])
  const type = oneOf(input.type, ['expense', 'refund', 'fee', 'cashback'])
  const result = {
    userCardId: identifier(input.userCardId), type,
    state: oneOf(input.state, ['draft', 'pending', 'posted', 'failed']),
    occurredOn: day(input.occurredOn), money: money(input.money),
    original: type === 'expense' && input.original != null ? money(input.original) : null,
    fee: type === 'expense' && input.fee != null ? { ...money(input.fee, false), included: input.fee.included === true } : null,
    note: text(input.note, 200, false, true),
    relatedEntryId: input.relatedEntryId == null ? null : identifier(input.relatedEntryId),
  }
  if (result.fee?.included && (result.fee.currency !== result.money.currency || amount(result.fee.amount) > amount(result.money.amount))) {
    fail('已含手续费必须与扣款同币种，且不能大于扣款金额')
  }
  if (['expense', 'fee'].includes(type) && result.relatedEntryId) fail('此类型无需关联原消费')
  if (['refund', 'cashback'].includes(type) && !result.relatedEntryId) fail('请选择关联的原消费')
  return result
}
function revision(record, input) {
  if (!Number.isInteger(input.expectedRevision) || record.revision !== input.expectedRevision) {
    fail('记录已在其他设备修改，请刷新后重试', 409, 'REVISION_CONFLICT')
  }
}
function found(list, id) {
  const result = list.find(item => item.id === id)
  if (!result) fail('记录不存在', 404, 'NOT_FOUND')
  return result
}
export function replayedOperation(ledger, input, operation) {
  const key = identifier(input.requestId)
  const hash = createHash('sha256').update(JSON.stringify([operation, input])).digest('hex')
  const saved = Object.hasOwn(ledger.operations, key) ? ledger.operations[key] : null
  if (saved) {
    if (saved.hash !== hash) fail('重复请求的内容不同，请重新打开表单', 409, 'IDEMPOTENCY_CONFLICT')
    const result = ledger[saved.collection].find(item => item.id === saved.id)
    if (!result) fail('该记录已删除', 409, 'DELETED_RECORD')
    return result
  }
  return null
}
function idempotent(ledger, input, operation, action) {
  const replay = replayedOperation(ledger, input, operation)
  if (replay) return replay
  const key = identifier(input.requestId)
  const hash = createHash('sha256').update(JSON.stringify([operation, input])).digest('hex')
  if (Object.keys(ledger.operations).length >= 20000) fail('记录操作已达上限，请联系支持', 409)
  const result = action()
  Object.defineProperty(ledger.operations, key, {
    value: { hash, id: result.id, collection: operation }, enumerable: true, writable: true, configurable: true,
  })
  return result
}
export function createCard(ledger, input) {
  const data = cardInput(input)
  return idempotent(ledger, input, 'cards', () => {
    if (ledger.cards.length >= 240) fail('个人卡片数量已达上限')
    const now = new Date().toISOString()
    const card = { ...data, id: randomUUID(), revision: 1, createdAt: now, updatedAt: now }
    ledger.cards.push(card)
    return card
  })
}
export function updateCard(ledger, id, input) {
  const card = found(ledger.cards, id)
  revision(card, input)
  const data = cardInput(input)
  if (data.catalogCardId !== card.catalogCardId) fail('卡片产品不可更换，请另建一张卡')
  Object.assign(card, data, { revision: card.revision + 1, updatedAt: new Date().toISOString() })
  return card
}
export function deleteCard(ledger, id, input) {
  const card = found(ledger.cards, id)
  revision(card, input)
  if (ledger.entries.some(entry => entry.userCardId === id)) fail('这张卡还有流水，请归档以保留记录', 409)
  ledger.cards = ledger.cards.filter(item => item.id !== id)
}
function validateRelations(entries) {
  const refunds = new Map()
  for (const entry of entries) {
    if (!entry.relatedEntryId) continue
    const parent = found(entries, entry.relatedEntryId)
    if (parent.type !== 'expense' || parent.state !== 'posted' || parent.userCardId !== entry.userCardId) fail('请选择同一张卡的已入账消费')
    if (entry.type === 'refund') {
      if (parent.money.currency !== entry.money.currency) fail('退款币种必须与原扣款一致')
      if (entry.state === 'posted' || entry.state === 'pending') {
        refunds.set(parent.id, (refunds.get(parent.id) ?? 0n) + amount(entry.money.amount))
        if (refunds.get(parent.id) > amount(parent.money.amount)) fail('累计退款不能超过原扣款金额')
      }
    }
  }
}
export function createEntry(ledger, input, sourceSnapshot = null) {
  const data = entryInput(input)
  return idempotent(ledger, input, 'entries', () => {
    if (ledger.entries.length >= 5000) fail('流水数量已达上限')
    const card = found(ledger.cards, data.userCardId)
    if (card.archived && !data.relatedEntryId) fail('已归档卡片只能补记关联退款或返现')
    const sourceBillId = input.sourceBillId == null ? null : identifier(input.sourceBillId)
    if (sourceBillId && (!sourceSnapshot || sourceSnapshot.id !== sourceBillId)) fail('未能核验原账单', 400)
    if (sourceSnapshot?.transactionStatus === 'refunded' && data.type !== 'refund') fail('退款账单请从原消费的记录退款入口补录')
    if (sourceBillId && ledger.entries.some(entry => entry.sourceBillId === sourceBillId)) fail('这笔识别账单已经记入账本', 409, 'BILL_ALREADY_IMPORTED')
    const now = new Date().toISOString()
    const entry = {
      ...data, id: randomUUID(), revision: 1, createdAt: now, updatedAt: now,
      cardSnapshot: { productName: card.productName, nickname: card.nickname, last4: card.last4 },
      sourceBillId, source: sourceBillId ? 'bill' : 'manual', sourceSnapshot,
    }
    validateRelations([...ledger.entries, entry])
    ledger.entries.push(entry)
    return entry
  })
}
export function updateEntry(ledger, id, input) {
  const entry = found(ledger.entries, id)
  revision(entry, input)
  const data = entryInput(input)
  const card = found(ledger.cards, data.userCardId)
  if (input.sourceBillId != null && input.sourceBillId !== entry.sourceBillId) fail('识别来源不可更换')
  if (card.archived && card.id !== entry.userCardId && !data.relatedEntryId) fail('不能改绑到已归档卡片')
  const updated = { ...entry, ...data, revision: entry.revision + 1, updatedAt: new Date().toISOString() }
  if (card.id !== entry.userCardId) updated.cardSnapshot = { productName: card.productName, nickname: card.nickname, last4: card.last4 }
  validateRelations(ledger.entries.map(item => item.id === id ? updated : item))
  ledger.entries = ledger.entries.map(item => item.id === id ? updated : item)
  return updated
}
export function deleteEntry(ledger, id, input) {
  const entry = found(ledger.entries, id)
  revision(entry, input)
  if (ledger.entries.some(item => item.relatedEntryId === id)) fail('请先处理关联的退款和返现记录', 409)
  ledger.entries = ledger.entries.filter(item => item.id !== id)
}
export function queryEntries(ledger, query) {
  const month = query.month
  if (month && !/^\d{4}-(?:0[1-9]|1[0-2])$/.test(month)) fail('月份无效')
  if (query.state) oneOf(query.state, ['draft', 'pending', 'posted', 'failed'])
  return ledger.entries.filter(entry =>
    (!month || entry.occurredOn.startsWith(month)) &&
    (!query.userCardId || entry.userCardId === query.userCardId) &&
    (!query.currency || entry.money.currency === query.currency.toUpperCase()) &&
    (!query.state || entry.state === query.state)
  ).sort((a, b) => b.occurredOn.localeCompare(a.occurredOn) || b.createdAt.localeCompare(a.createdAt) || b.id.localeCompare(a.id))
}
export function summarize(ledger, query) {
  // Summary always includes the complete matching month, never a list page.
  const entries = queryEntries(ledger, { ...query, currency: null, state: null })
  const buckets = new Map()
  const get = currency => {
    if (!buckets.has(currency)) buckets.set(currency, { currency, spent: 0n, refunds: 0n, fees: 0n, cashback: 0n, net: 0n, count: 0 })
    return buckets.get(currency)
  }
  let pendingCount = 0
  for (const entry of entries) {
    if (entry.state !== 'posted') { if (entry.state !== 'failed') pendingCount++; continue }
    const n = amount(entry.money.amount)
    const bucket = get(entry.money.currency)
    bucket.count++
    if (entry.type === 'expense') { bucket.spent += n; bucket.net += n }
    if (entry.type === 'refund') { bucket.refunds += n; bucket.net -= n }
    if (entry.type === 'fee') { bucket.fees += n; bucket.net += n }
    if (entry.type === 'cashback') { bucket.cashback += n; bucket.net -= n }
    if (entry.fee) {
      const fee = get(entry.fee.currency), cost = amount(entry.fee.amount)
      fee.fees += cost
      if (!entry.fee.included) fee.net += cost
    }
  }
  return { month: query.month ?? null, pendingCount, currencies: [...buckets.values()]
    .filter(bucket => !query.currency || bucket.currency === query.currency.toUpperCase())
    .sort((a, b) => a.currency.localeCompare(b.currency))
    .map(bucket => Object.fromEntries(Object.entries(bucket).map(([key, value]) => [key, typeof value === 'bigint' ? decimal(value) : value]))) }
}

// Keep only explicit, bounded fields from the legacy API; no raw extraction,
// images, credentials or arbitrary nested response can enter this store.
export function billSnapshot(record) {
  const data = record.confirmed ?? {}
  const optionalMoney = value => {
    try { return money(value, false) }
    catch (error) { if (error instanceof LedgerError) return null; throw error }
  }
  return {
    id: identifier(record.id), revision: Number.isInteger(record.revision) ? record.revision : 1,
    transactionStatus: ['success', 'failed', 'pending', 'refunded'].includes(data.status) ? data.status : 'unknown',
    original: optionalMoney(data.original),
    deduction: optionalMoney(data.deduction),
    last4: typeof data.cardLast4 === 'string' && /^\d{4}$/.test(data.cardLast4) ? data.cardLast4 : null,
  }
}
