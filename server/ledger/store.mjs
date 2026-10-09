import { DatabaseSync } from 'node:sqlite'
import { createCipheriv, createDecipheriv, createHmac, randomBytes } from 'node:crypto'
import { emptyLedger, fail } from './domain.mjs'

export class LedgerStore {
  constructor(path, key) {
    if (!Buffer.isBuffer(key) || key.length !== 32) throw new Error('LEDGER_ENCRYPTION_KEY must contain 32 bytes')
    this.key = key
    this.db = new DatabaseSync(path)
    this.db.exec('PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000; CREATE TABLE IF NOT EXISTS ledgers (owner TEXT PRIMARY KEY, payload BLOB NOT NULL)')
    this.db.exec('CREATE TABLE IF NOT EXISTS erased_owners (owner TEXT PRIMARY KEY)')
  }
  owner(subject) { return createHmac('sha256', this.key).update(`ledger:${subject}`).digest('hex') }
  read(subject) {
    const owner = this.owner(subject)
    const row = this.db.prepare('SELECT payload FROM ledgers WHERE owner = ?').get(owner)
    if (!row) return emptyLedger()
    const payload = Buffer.from(row.payload)
    const decipher = createDecipheriv('aes-256-gcm', this.key, payload.subarray(0, 12))
    decipher.setAAD(Buffer.from(owner))
    decipher.setAuthTag(payload.subarray(12, 28))
    return JSON.parse(Buffer.concat([decipher.update(payload.subarray(28)), decipher.final()]).toString('utf8'))
  }
  change(subject, operation) {
    this.db.exec('BEGIN IMMEDIATE')
    try {
      if (this.db.prepare('SELECT owner FROM erased_owners WHERE owner = ?').get(this.owner(subject))) fail('账号数据已清除，请完成账号删除', 410, 'ACCOUNT_DATA_ERASED')
      const data = this.read(subject)
      const result = operation(data)
      const owner = this.owner(subject), iv = randomBytes(12)
      const cipher = createCipheriv('aes-256-gcm', this.key, iv)
      cipher.setAAD(Buffer.from(owner))
      const encrypted = Buffer.concat([cipher.update(JSON.stringify(data), 'utf8'), cipher.final()])
      const payload = Buffer.concat([iv, cipher.getAuthTag(), encrypted])
      this.db.prepare('INSERT INTO ledgers VALUES (?, ?) ON CONFLICT(owner) DO UPDATE SET payload = excluded.payload').run(owner, payload)
      this.db.exec('COMMIT')
      return result
    } catch (error) { this.db.exec('ROLLBACK'); throw error }
  }
  erase(subject) {
    // Tombstone prevents an already-authenticated in-flight request from
    // recreating records while identity deletion is completing upstream.
    this.db.exec('BEGIN IMMEDIATE')
    try {
      this.db.prepare('DELETE FROM ledgers WHERE owner = ?').run(this.owner(subject))
      this.db.prepare('INSERT OR IGNORE INTO erased_owners VALUES (?)').run(this.owner(subject))
      this.db.exec('COMMIT')
    } catch (error) { this.db.exec('ROLLBACK'); throw error }
  }
  close() { this.db.close() }
}
