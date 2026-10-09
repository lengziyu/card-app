import test from 'node:test'
import assert from 'node:assert/strict'
import { randomBytes, randomUUID, createHmac } from 'node:crypto'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { emptyLedger, createCard, updateCard, createEntry, updateEntry, deleteEntry, deleteCard, summarize, billSnapshot } from '../domain.mjs'
import { LedgerStore } from '../store.mjs'
import { ledgerServer, supabaseVerifier } from '../http.mjs'

const cardInput = (more = {}) => ({ catalogCardId: 'product-one', productName: 'Example Card', nickname: 'Travel', last4: '0123', form: 'physical', requestId: randomUUID(), ...more })
const expense = (card, more = {}) => ({ userCardId: card.id, type: 'expense', state: 'posted', occurredOn: '2026-10-07', money: { amount: '10.1', currency: 'USD' }, note: '', requestId: randomUUID(), ...more })
const revisionInput = (entry, more = {}) => ({ userCardId: entry.userCardId, type: entry.type, state: entry.state, occurredOn: entry.occurredOn, money: entry.money, original: entry.original, fee: entry.fee, note: entry.note, relatedEntryId: entry.relatedEntryId, expectedRevision: entry.revision, ...more })

test('same product and last4 are not identities; card rename preserves history snapshot', () => {
  const db = emptyLedger(), first = createCard(db, cardInput()), second = createCard(db, cardInput())
  assert.notEqual(first.id, second.id)
  const row = createEntry(db, expense(first))
  updateCard(db, first.id, { ...cardInput(), nickname: 'New name', expectedRevision: first.revision })
  assert.equal(row.cardSnapshot.nickname, 'Travel')
  assert.throws(() => deleteCard(db, first.id, { expectedRevision: first.revision }), /归档/)
})

test('rejects full card numbers, unknown credential fields and invalid dates', () => {
  for (const more of [{ last4: '4242424242424242' }, { cvv: '123' }, { nickname: '4242 4242 4242 4242' }]) {
    assert.throws(() => createCard(emptyLedger(), cardInput(more)))
  }
  const db = emptyLedger(), card = createCard(db, cardInput())
  assert.throws(() => createEntry(db, expense(card, { occurredOn: '2026-02-30' })))
  assert.throws(() => createEntry(db, expense(card, { note: '4242-4242-4242-4242' })))
  assert.throws(() => createEntry(db, expense(card, { note: '４２４２ ４２４２ ４２４２ ４２４２' })))
  assert.equal(createEntry(db, expense(card, { note: 'Coffee\nTravel' })).note, 'Coffee\nTravel')
  assert.throws(() => createEntry(db, expense(card, { money: { amount: '1e10', currency: 'USD' } })))
})

test('exact amounts, included/extra fees, mixed currencies and draft exclusions', () => {
  const db = emptyLedger(), card = createCard(db, cardInput())
  createEntry(db, expense(card, { money: { amount: '0.1', currency: 'USD' }, fee: { amount: '0.02', currency: 'USD', included: true } }))
  createEntry(db, expense(card, { money: { amount: '0.2', currency: 'USD' }, fee: { amount: '0.01', currency: 'USDT', included: false } }))
  createEntry(db, expense(card, { state: 'draft' }))
  createEntry(db, expense(card, { state: 'pending' }))
  createEntry(db, expense(card, { state: 'failed' }))
  const result = summarize(db, { month: '2026-10' })
  assert.equal(result.pendingCount, 2)
  assert.deepEqual(result.currencies, [
    { currency: 'USD', spent: '0.3', refunds: '0', fees: '0.02', cashback: '0', net: '0.3', count: 2 },
    { currency: 'USDT', spent: '0', refunds: '0', fees: '0.01', cashback: '0', net: '0.01', count: 0 },
  ])
})

test('cross-month refunds and cashback use their own dates and protect parent edits', () => {
  const db = emptyLedger(), card = createCard(db, cardInput())
  const parent = createEntry(db, expense(card, { money: { amount: '100', currency: 'USD' } }))
  const refund = createEntry(db, expense(card, { type: 'refund', relatedEntryId: parent.id, occurredOn: '2026-11-01', money: { amount: '30', currency: 'USD' } }))
  const cashback = createEntry(db, expense(card, { type: 'cashback', relatedEntryId: parent.id, occurredOn: '2026-11-02', money: { amount: '2', currency: 'USD' } }))
  createEntry(db, expense(card, { type: 'cashback', relatedEntryId: parent.id, state: 'pending', occurredOn: '2026-11-03', money: { amount: '8', currency: 'USD' } }))
  assert.equal(summarize(db, { month: '2026-10' }).currencies[0].net, '100')
  assert.equal(summarize(db, { month: '2026-11' }).currencies[0].net, '-32')
  assert.throws(() => createEntry(db, expense(card, { type: 'refund', relatedEntryId: parent.id, money: { amount: '71', currency: 'USD' } })), /累计退款/)
  assert.throws(() => updateEntry(db, parent.id, revisionInput(parent, { money: { amount: '20', currency: 'USD' } })), /累计退款/)
  assert.throws(() => deleteEntry(db, parent.id, { expectedRevision: parent.revision }), /关联/)
  assert.equal(refund.relatedEntryId, parent.id)
  assert.equal(cashback.relatedEntryId, parent.id)
})

test('idempotent retries, stale updates and deleted requests cannot resurrect data', () => {
  const db = emptyLedger(), card = createCard(db, cardInput()), input = expense(card)
  const entry = createEntry(db, input)
  assert.equal(createEntry(db, input).id, entry.id)
  assert.equal(db.entries.length, 1)
  assert.throws(() => createEntry(db, { ...input, note: 'different' }), /重复请求/)
  const updated = updateEntry(db, entry.id, revisionInput(entry, { note: 'corrected' }))
  assert.throws(() => updateEntry(db, entry.id, revisionInput(entry)), /其他设备/)
  deleteEntry(db, updated.id, { expectedRevision: updated.revision })
  assert.throws(() => createEntry(db, input), /已删除/)
})

test('request IDs cannot collide with object prototype properties', () => {
  for (const requestId of ['__proto__', 'constructor', 'toString']) {
    const db = emptyLedger(), input = cardInput({ requestId });
    const card = createCard(db, input)
    const restored = JSON.parse(JSON.stringify(db))
    assert.equal(createCard(restored, input).id, card.id)
    assert.equal(restored.cards.length, 1)
  }
})

test('a committed import retries successfully after its upstream disappears', async () => {
  const store = new LedgerStore(':memory:', randomBytes(32))
  const card = store.change('alice', db => createCard(db, cardInput()))
  let loads = 0
  const server = ledgerServer({ store, verify: async () => 'alice', loadBill: async () => {
    if (++loads > 1) throw new Error('upstream unavailable')
    return billSnapshot({ id: 'scanned-bill', confirmed: {} })
  } })
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  const input = expense(card, { sourceBillId: 'scanned-bill' })
  const request = () => fetch(`http://127.0.0.1:${server.address().port}/api/user/card-ledger/entries`, {
    method: 'POST', headers: { authorization: 'Bearer token', 'content-type': 'application/json' }, body: JSON.stringify(input),
  })
  try {
    const original = await (await request()).json()
    const retry = await request()
    assert.equal(retry.status, 201)
    assert.equal((await retry.json()).entry.id, original.entry.id)
    assert.equal(loads, 1)
    assert.equal(store.read('alice').entries.length, 1)
  } finally { await new Promise(resolve => server.close(resolve)); store.close() }
})

test('foreign cards, wrong refund currency and archived-card spending are rejected', () => {
  const db = emptyLedger(), other = emptyLedger()
  const card = createCard(db, cardInput()), foreign = createCard(other, cardInput())
  assert.throws(() => createEntry(db, expense(foreign)), /不存在/)
  const parent = createEntry(db, expense(card))
  assert.throws(() => createEntry(db, expense(card, { type: 'refund', relatedEntryId: parent.id, money: { amount: '1', currency: 'CNY' } })), /币种/)
  updateCard(db, card.id, { ...cardInput(), archived: true, expectedRevision: card.revision })
  assert.throws(() => createEntry(db, expense(card)), /归档/)
  createEntry(db, expense(card, { type: 'refund', relatedEntryId: parent.id, money: { amount: '1', currency: 'USD' } }))
})

test('imports require verified source and discard all arbitrary sensitive fields', () => {
  const db = emptyLedger(), card = createCard(db, cardInput())
  const source = billSnapshot({ id: 'bill-one', revision: 1, imageBase64: 'not-stored', confirmed: { cardLast4: '4242424242424242', deduction: { amount: '10', currency: 'USD' }, cvv: '123' } })
  assert.equal(source.last4, null)
  assert.equal(JSON.stringify(source).includes('not-stored'), false)
  assert.throws(() => createEntry(db, expense(card, { sourceBillId: 'bill-one' })), /核验/)
  const row = createEntry(db, expense(card, { sourceBillId: 'bill-one' }), source)
  assert.equal(row.source, 'bill')
  assert.throws(() => createEntry(db, expense(card, { sourceBillId: 'bill-one' }), source), /已经记入/)
  const refundSource = billSnapshot({ id: 'refund-bill', confirmed: { status: 'refunded', deduction: { amount: '2', currency: 'USD' } } })
  assert.throws(() => createEntry(db, expense(card, { sourceBillId: 'refund-bill' }), refundSource), /退款账单/)
})

test('incomplete OCR money stays unknown while corrected entry can be imported', () => {
  const source = billSnapshot({ id: 'partial', confirmed: {
    original: { amount: '10', currency: null }, deduction: { amount: 'NaN', currency: 'USD' },
  } })
  assert.equal(source.original, null)
  assert.equal(source.deduction, null)
  const db = emptyLedger(), card = createCard(db, cardInput())
  const saved = createEntry(db, expense(card, { sourceBillId: 'partial' }), source)
  assert.equal(saved.money.amount, '10.1')
  assert.equal(saved.sourceSnapshot.deduction, null)
})

test('encrypted storage survives restart, isolates owners and rolls back failed changes', () => {
  const dir = mkdtempSync(join(tmpdir(), 'cardfi-ledger-')), file = join(dir, 'ledger.sqlite'), key = randomBytes(32)
  let store = new LedgerStore(file, key)
  try {
    store.change('alice', data => createCard(data, cardInput({ nickname: 'PRIVATE_LEDGER_MARKER' })))
    assert.equal(store.read('bob').cards.length, 0)
    assert.throws(() => store.change('alice', data => { data.cards = []; throw new Error('abort') }))
    assert.equal(store.read('alice').cards.length, 1)
    store.close()
    assert.equal(readFileSync(file).includes(Buffer.from('PRIVATE_LEDGER_MARKER')), false)
    store = new LedgerStore(file, key)
    assert.equal(store.read('alice').cards[0].nickname, 'PRIVATE_LEDGER_MARKER')
    store.erase('alice')
    assert.equal(store.read('alice').cards.length, 0)
    assert.throws(() => store.change('alice', data => createCard(data, cardInput())), /账号数据已清除/)
  } finally {
    store.close()
    const target = resolve(dir)
    assert.ok(target.startsWith(resolve(tmpdir()) + '\\cardfi-ledger-') || target.startsWith(resolve(tmpdir()) + '/cardfi-ledger-'))
    rmSync(target, { recursive: true })
  }
})

test('HTTP verifies ownership, paginates while summary includes every record, deletes account data', async () => {
  const store = new LedgerStore(':memory:', randomBytes(32))
  let verified = 0
  const server = ledgerServer({ store, verify: async token => { verified++; return token }, loadBill: async () => { throw new Error('unexpected') } })
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  const base = `http://127.0.0.1:${server.address().port}/api/user/card-ledger`
  const request = (path, token = 'alice', method = 'GET', body) => fetch(`${base}${path}`, { method, headers: { ...(token ? { authorization: `Bearer ${token}` } : {}), 'content-type': 'application/json' }, body: body ? JSON.stringify(body) : undefined })
  try {
    assert.equal((await request('/cards', null)).status, 401)
    assert.equal(verified, 0)
    assert.equal((await request('cards')).status, 404)
    assert.equal((await request('/cards', 'alice', 'POST', [])).status, 400)
    const created = await (await request('/cards', 'alice', 'POST', cardInput())).json()
    assert.equal((await (await request('/cards', 'bob')).json()).cards.length, 0)
    assert.equal((await request(`/cards/${created.card.id}`, 'bob', 'PATCH', { ...cardInput(), expectedRevision: 1 })).status, 404)
    for (let i = 0; i < 55; i++) store.change('alice', data => createEntry(data, expense(created.card, { money: { amount: '1', currency: 'USD' } })))
    const first = await (await request('/entries?limit=20&month=2026-10')).json()
    assert.equal(first.entries.length, 20)
    assert.ok(first.nextCursor)
    const second = await (await request(`/entries?limit=20&month=2026-10&cursor=${first.nextCursor}`)).json()
    assert.equal(second.entries.length, 20)
    assert.equal(new Set([...first.entries, ...second.entries].map(entry => entry.id)).size, 40)
    const summary = await (await request('/summary?month=2026-10')).json()
    assert.equal(summary.summary.currencies[0].spent, '55')
    assert.equal((await request('', 'alice', 'DELETE')).status, 200)
    assert.equal(store.read('alice').cards.length, 0)
    assert.equal(store.read('alice').entries.length, 0)
  } finally { await new Promise(resolve => server.close(resolve)); store.close() }
})

test('identity verification fails closed for unverified accounts and network errors', async () => {
  const config = { origin: 'https://example.supabase.co', publicKey: 'public' }
  const unverified = supabaseVerifier({ ...config, fetcher: async () => new Response(JSON.stringify({ id: 'alice' })) })
  await assert.rejects(unverified('token'), /邮箱验证/)
  const failure = supabaseVerifier({ ...config, fetcher: async () => { throw new Error('secret-token') } })
  await assert.rejects(failure('token'), error => error.status === 503 && !error.message.includes('secret-token'))
  assert.throws(() => supabaseVerifier({ ...config, origin: 'http://insecure.example' }))
})

test('signed deletion callback clears old-client data even when new feature is disabled', async () => {
  const store = new LedgerStore(':memory:', randomBytes(32)), secret = randomBytes(32).toString('hex')
  store.change('alice', data => createCard(data, cardInput()))
  const server = ledgerServer({ store, enabled: false, deletionSecret: secret, verify: async () => 'alice' })
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve))
  const base = `http://127.0.0.1:${server.address().port}`
  const timestamp = Date.now().toString(), signature = createHmac('sha256', secret).update(`${timestamp}.alice`).digest('hex')
  const request = signed => fetch(`${base}/api/internal/card-ledger/account-deleted`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-ledger-timestamp': timestamp, 'x-ledger-signature': signed }, body: JSON.stringify({ userId: 'alice' }) })
  try {
    assert.equal((await request('0'.repeat(64))).status, 401)
    assert.equal(store.read('alice').cards.length, 1)
    assert.equal((await request(signature)).status, 200)
    assert.equal(store.read('alice').cards.length, 0)
    assert.equal((await request(signature)).status, 200)
    const response = await fetch(`${base}/api/user/card-ledger`, { method: 'DELETE', headers: { authorization: 'Bearer token' } })
    assert.equal(response.status, 200)
  } finally { await new Promise(resolve => server.close(resolve)); store.close() }
})
