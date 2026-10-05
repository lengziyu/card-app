const [target = '', rawBaseUrl = 'https://card.lengziyu.cn'] = process.argv.slice(2)

const platform = target === 'ipa' ? 'ios' : target === 'appbundle' ? 'android' : ''
if (!platform) {
  console.error('Usage: node tools/check_comment_release_config.mjs <ipa|appbundle> [api-base-url]')
  process.exit(64)
}

const baseUrl = new URL(rawBaseUrl)
const url = new URL('/api/cards/etherfi-core/comments', baseUrl)
url.searchParams.set('platform', platform)
url.searchParams.set('limit', '1')

const controller = new AbortController()
const timeout = setTimeout(() => controller.abort(), 15_000)

try {
  const response = await fetch(url, {
    headers: { accept: 'application/json' },
    signal: controller.signal
  })
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`)
  }
  const payload = await response.json()
  const enabled = payload?.enabled === true
  const writeEnabled = payload?.writeEnabled === true
  const moderationRequired = payload?.moderationRequired === true

  if (enabled && writeEnabled && !moderationRequired) {
    console.error(
      `Comment release configuration failed for ${platform}: comments are writable without pre-publication moderation. Enable cardCommentModerationEnabled or disable comment writes before building.`
    )
    process.exit(78)
  }

  console.log(
    `Comment release configuration is valid for ${platform}: enabled=${enabled}, writeEnabled=${writeEnabled}, moderationRequired=${moderationRequired}.`
  )
} catch (error) {
  const message = error?.name === 'AbortError' ? 'request timed out' : error?.message || String(error)
  console.error(`Unable to validate comment release configuration for ${platform}: ${message}`)
  process.exit(69)
} finally {
  clearTimeout(timeout)
}
