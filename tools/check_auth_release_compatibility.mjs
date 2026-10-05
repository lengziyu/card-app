import { readFile } from 'node:fs/promises'

const [
  configPath = 'config/supabase.local.json',
  apiBase = 'https://card.lengziyu.cn',
  target = 'ipa'
] = process.argv.slice(2)

const fail = (message) => {
  console.error(`Auth release preflight failed: ${message}`)
  process.exit(78)
}

let local
try {
  local = JSON.parse(await readFile(configPath, 'utf8'))
} catch (error) {
  fail(`cannot read ${configPath}: ${error.message}`)
}

if (local.ENABLE_SUPABASE_AUTH !== true) {
  fail('ENABLE_SUPABASE_AUTH must be true')
}

let remote
const configUrl = new URL('/api/auth/config', apiBase).toString()
try {
  const response = await fetch(configUrl, {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(15_000)
  })
  if (!response.ok) fail(`${configUrl} returned HTTP ${response.status}`)
  remote = await response.json()
} catch (error) {
  fail(`cannot read ${configUrl}: ${error.message}`)
}

const failures = []
if (target !== 'ipa' && target !== 'appbundle') {
  failures.push(`unsupported store target: ${target}`)
}
if (remote?.supabaseEnabled !== true) failures.push('remote Supabase Auth is not enabled')
if (remote?.firebaseEnabled !== true) {
  failures.push('Firebase Auth must remain enabled during review and the first release')
}
if (remote?.legacyPasswordAuth !== true) {
  failures.push('legacy password Auth must remain enabled during review and the first release')
}

const googleEnabled = local.ENABLE_GOOGLE_AUTH === true
const appleEnabled = local.ENABLE_APPLE_AUTH === true
if (!googleEnabled) {
  failures.push('Google Auth must be enabled for both iOS and Android store releases')
}
if (target === 'ipa' && !appleEnabled) {
  failures.push('Apple Auth must be enabled for the iOS store release')
}
if (googleEnabled) {
  if (!String(local.GOOGLE_WEB_CLIENT_ID || '').trim()) {
    failures.push('GOOGLE_WEB_CLIENT_ID is required when Google Auth is enabled')
  }
  if (!String(local.GOOGLE_IOS_CLIENT_ID || '').trim()) {
    failures.push('GOOGLE_IOS_CLIENT_ID is required for the shared iOS/Android release config')
  }
  if (target === 'ipa') {
    try {
      const authConfig = await readFile('ios/Flutter/Auth.local.xcconfig', 'utf8')
      const reversedClientId =
        authConfig.match(/^\s*GOOGLE_REVERSED_CLIENT_ID\s*=\s*(\S+)\s*$/m)?.[1] || ''
      const iosClientId = String(local.GOOGLE_IOS_CLIENT_ID || '').trim()
      const expectedSuffix = iosClientId.replace(/\.apps\.googleusercontent\.com$/, '')
      if (
        !reversedClientId ||
        !expectedSuffix ||
        reversedClientId !== `com.googleusercontent.apps.${expectedSuffix}`
      ) {
        failures.push('ios/Flutter/Auth.local.xcconfig does not match GOOGLE_IOS_CLIENT_ID')
      }
    } catch {
      failures.push('ios/Flutter/Auth.local.xcconfig is required for iOS Google Sign-In')
    }
  }
  if (target === 'appbundle') {
    try {
      const googleServices = JSON.parse(
        await readFile('android/app/google-services.json', 'utf8')
      )
      const packageNames = (googleServices?.client || [])
        .map((entry) => entry?.client_info?.android_client_info?.package_name)
        .filter(Boolean)
      if (!packageNames.includes('cn.lengziyu.cardapp')) {
        failures.push('android/app/google-services.json does not contain cn.lengziyu.cardapp')
      }
    } catch {
      failures.push('android/app/google-services.json is required for Android Google Sign-In')
    }
  }
}
if (appleEnabled && remote?.appleCredentialApiEnabled !== true) {
  failures.push('the Apple credential API must be configured before Apple Auth is enabled')
}

if (googleEnabled || appleEnabled) {
  const supabaseUrl = String(local.SUPABASE_URL || '').replace(/\/+$/, '')
  const publishableKey = String(local.SUPABASE_PUBLISHABLE_KEY || '').trim()
  if (!supabaseUrl || !publishableKey) {
    failures.push('Supabase URL and publishable key are required for provider verification')
  } else {
    try {
      const response = await fetch(`${supabaseUrl}/auth/v1/settings`, {
        headers: { apikey: publishableKey, accept: 'application/json' },
        signal: AbortSignal.timeout(15_000)
      })
      if (!response.ok) {
        failures.push(`Supabase Auth settings returned HTTP ${response.status}`)
      } else {
        const settings = await response.json()
        if (googleEnabled && settings?.external?.google !== true) {
          failures.push('Supabase Google provider is not enabled')
        }
        if (appleEnabled && settings?.external?.apple !== true) {
          failures.push('Supabase Apple provider is not enabled')
        }
      }
    } catch (error) {
      failures.push(`cannot verify Supabase providers: ${error.message}`)
    }
  }
}

if (failures.length) fail(failures.join('; '))

console.log(
  `Auth release preflight passed for ${target}: Supabase and required native providers are active; Firebase and legacy Auth remain compatible at ${configUrl}`
)
