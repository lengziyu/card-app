import { createServer } from 'node:http'
import { createHmac, timingSafeEqual } from 'node:crypto'
import { LedgerError, fail, identifier, createCard, updateCard, deleteCard, createEntry, updateEntry, deleteEntry, queryEntries, summarize, billSnapshot, replayedOperation } from './domain.mjs'

export function secureOrigin(value) {
  const url = new URL(value)
  if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) throw new Error('Upstream must be an HTTPS origin')
  return url.origin
}
export function supabaseVerifier({ origin, publicKey, fetcher = fetch }) {
  const base = secureOrigin(origin)
  if (!publicKey) throw new Error('SUPABASE_ANON_KEY is required')
  return async token => {
    let response
    try {
      response = await fetcher(`${base}/auth/v1/user`, {
        headers: { authorization: `Bearer ${token}`, apikey: publicKey },
        signal: AbortSignal.timeout(10000), redirect: 'error',
      })
    } catch { fail('账号验证暂不可用，请稍后重试', 503, 'AUTH_UNAVAILABLE') }
    if ([401, 403].includes(response.status)) fail('登录已失效，请重新登录', 401, 'UNAUTHORIZED')
    if (!response.ok) fail('账号验证暂不可用，请稍后重试', 503, 'AUTH_UNAVAILABLE')
    const user = await response.json()
    if (!user.id || !user.email_confirmed_at) fail('请先登录并完成邮箱验证', 403, 'UNVERIFIED_ACCOUNT')
    return identifier(user.id)
  }
}
export function legacyBillLoader({ origin, fetcher = fetch }) {
  const base = secureOrigin(origin)
  return async (token, id) => {
    const signal = AbortSignal.timeout(20000)
    let cursor
    const seen = new Set()
    for (let page = 0; page < 100; page++) {
      const url = new URL('/api/pro/bill-records', base)
      url.searchParams.set('limit', '100')
      if (cursor) url.searchParams.set('cursor', cursor)
      let response
      try {
        response = await fetcher(url, { headers: { authorization: `Bearer ${token}` }, signal, redirect: 'error' })
      } catch { fail('原账单暂不可用，请稍后重试', 503) }
      if (!response.ok) fail('无法读取原账单，请检查登录及账单访问权限', response.status === 403 ? 403 : 503)
      const data = await response.json()
      const record = (data.records ?? []).find(item => item.id === id)
      if (record) return billSnapshot(record)
      cursor = data.nextCursor
      if (!cursor || seen.has(cursor)) break
      seen.add(cursor)
    }
    fail('原账单不存在或已删除', 404, 'BILL_NOT_FOUND')
  }
}
async function readBody(req) {
  let size = 0
  const chunks = []
  for await (const chunk of req) {
    size += chunk.length
    if (size > 32768) fail('请求内容过大', 413)
    chunks.push(chunk)
  }
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')) }
  catch { fail('请求格式无效') }
}
export function ledgerServer({ store, verify, loadBill, enabled = true, deletionSecret }) {
  const rates = new Map()
  function rateLimit(key, max) {
    const now = Date.now()
    for (const [name, rate] of rates) if (rate.expires <= now) rates.delete(name)
    if (!rates.has(key)) {
      if (rates.size >= 10000) fail('服务繁忙，请稍后重试', 503)
      rates.set(key, { count: 0, expires: now + 60000 })
    }
    if (++rates.get(key).count > max) fail('操作频繁，请稍后重试', 429, 'RATE_LIMITED')
  }
  return createServer(async (req, res) => {
    function send(status, body) {
      res.writeHead(status, { 'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'x-content-type-options': 'nosniff' })
      res.end(JSON.stringify(body))
    }
    try {
      const url = new URL(req.url, 'http://localhost')
      if (req.method === 'GET' && url.pathname === '/healthz') return send(200, { available: enabled })
      if (req.method === 'POST' && url.pathname === '/api/internal/card-ledger/account-deleted') {
        if (!deletionSecret || deletionSecret.length < 32) fail('删除回调未配置', 503)
        const input = await readBody(req)
        const timestamp = req.headers['x-ledger-timestamp'] ?? ''
        const signature = req.headers['x-ledger-signature'] ?? ''
        if (!/^\d{10,13}$/.test(timestamp) || Math.abs(Date.now() - Number(timestamp)) > 300000 || !/^[0-9a-f]{64}$/.test(signature)) fail('回调验证失败', 401)
        const subject = identifier(input.userId)
        const expected = createHmac('sha256', deletionSecret).update(`${timestamp}.${subject}`).digest()
        if (!timingSafeEqual(expected, Buffer.from(signature, 'hex'))) fail('回调验证失败', 401)
        store.erase(subject)
        return send(200, { deleted: true })
      }
      const prefix = '/api/user/card-ledger'
      if (!enabled && !(req.method === 'DELETE' && url.pathname === prefix)) fail('消费账本暂未开放', 503, 'LEDGER_DISABLED')
      if (url.pathname !== prefix && !url.pathname.startsWith(`${prefix}/`)) fail('接口不存在', 404, 'NOT_FOUND')
      rateLimit(`ip:${req.socket.remoteAddress}`, 600)
      const authorization = req.headers.authorization ?? ''
      if (!/^Bearer [^\s]{1,8192}$/.test(authorization)) fail('请先登录', 401, 'UNAUTHORIZED')
      const token = authorization.slice(7)
      const subject = await verify(token)
      rateLimit(`user:${subject}`, 180)
      const path = url.pathname.slice(prefix.length).split('/').filter(Boolean)
      const query = Object.fromEntries(url.searchParams)
      if (req.method === 'DELETE' && path.length === 0) {
        store.erase(subject)
        return send(200, { deleted: true })
      }
      if (req.method === 'GET') {
        const data = store.read(subject)
        if (path.length === 1 && path[0] === 'cards') return send(200, { cards: data.cards })
        if (path.length === 1 && path[0] === 'summary') return send(200, { summary: summarize(data, query) })
        if (path.length === 1 && path[0] === 'entries') {
          const rows = queryEntries(data, query)
          const offset = query.cursor ? rows.findIndex(item => item.id === query.cursor) + 1 : 0
          if (query.cursor && offset === 0) fail('列表已变化，请刷新', 409, 'CURSOR_EXPIRED')
          const limit = Math.min(100, Math.max(1, Number.parseInt(query.limit, 10) || 50))
          const entries = rows.slice(offset, offset + limit)
          return send(200, { entries, nextCursor: offset + limit < rows.length ? entries.at(-1).id : null })
        }
      }
      if (!['POST', 'PATCH', 'DELETE'].includes(req.method) || !['cards', 'entries'].includes(path[0]) || path.length > 2) fail('接口不存在', 404, 'NOT_FOUND')
      if ((req.headers['content-type'] ?? '').split(';')[0] !== 'application/json') fail('请使用 JSON 请求', 415)
      const input = await readBody(req)
      if (!input || typeof input !== 'object' || Array.isArray(input)) fail('请求格式无效')
      let result
      if (req.method === 'POST' && path.length === 1) {
        // An acknowledged write must remain retryable even if the original
        // bill was deleted or its upstream becomes unavailable afterwards.
        const replay = replayedOperation(store.read(subject), input, path[0])
        if (replay) return send(201, { [path[0] === 'cards' ? 'card' : 'entry']: replay })
        const snapshot = path[0] === 'entries' && input.sourceBillId ? await loadBill(token, identifier(input.sourceBillId)) : null
        result = store.change(subject, data => path[0] === 'cards' ? createCard(data, input) : createEntry(data, input, snapshot))
      } else if (path.length === 2) {
        const id = identifier(path[1])
        if (req.method === 'PATCH') result = store.change(subject, data => path[0] === 'cards' ? updateCard(data, id, input) : updateEntry(data, id, input))
        else if (req.method === 'DELETE') {
          store.change(subject, data => path[0] === 'cards' ? deleteCard(data, id, input) : deleteEntry(data, id, input))
          return send(200, { deleted: true })
        } else fail('接口不存在', 404, 'NOT_FOUND')
      } else fail('接口不存在', 404, 'NOT_FOUND')
      return send(req.method === 'POST' ? 201 : 200, { [path[0] === 'cards' ? 'card' : 'entry']: result })
    } catch (error) {
      // Never serialize arbitrary exceptions, request bodies, tokens or user data.
      if (error instanceof LedgerError) return send(error.status, { code: error.code, message: error.message })
      return send(500, { code: 'LEDGER_UNAVAILABLE', message: '消费账本暂不可用，请稍后重试' })
    }
  })
}
