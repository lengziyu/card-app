#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

target="${1:-ipa}"
if [[ "$target" == "--check" ]]; then
  check_only=true
  target="ipa"
else
  check_only=false
fi

if [[ "$target" != "ipa" && "$target" != "appbundle" ]]; then
  echo "Usage: tools/build_store_release.sh [ipa|appbundle|--check]" >&2
  exit 64
fi

legal_config="config/legal.local.json"
pro_config="config/pro.local.json"

for required_file in "$legal_config" "$pro_config"; do
  if [[ ! -f "$required_file" ]]; then
    echo "Missing $required_file. Copy its .example.json file and fill the release values." >&2
    exit 66
  fi
done

node - "$legal_config" "$pro_config" <<'NODE'
const fs = require('node:fs')

const [legalPath, proPath] = process.argv.slice(2)
const readJson = (path) => {
  try {
    return JSON.parse(fs.readFileSync(path, 'utf8'))
  } catch (error) {
    console.error(`Invalid JSON in ${path}: ${error.message}`)
    process.exit(65)
  }
}

const legal = readJson(legalPath)
const pro = readJson(proPath)
const failures = []
const requireHttps = (key, value) => {
  try {
    const url = new URL(String(value || ''))
    if (url.protocol !== 'https:' || !url.hostname) throw new Error('not HTTPS')
  } catch {
    failures.push(`${key} must be a public HTTPS URL`)
  }
}

requireHttps('PRIVACY_POLICY_URL', legal.PRIVACY_POLICY_URL)
requireHttps('TERMS_OF_USE_URL', legal.TERMS_OF_USE_URL)
requireHttps('ACCOUNT_DELETION_URL', legal.ACCOUNT_DELETION_URL)
requireHttps('PRO_PRIVACY_URL', pro.PRO_PRIVACY_URL)
requireHttps('PRO_TERMS_URL', pro.PRO_TERMS_URL)

if (!String(legal.SUPPORT_EMAIL || '').includes('@')) {
  failures.push('SUPPORT_EMAIL must be configured')
}
if (pro.ENABLE_PRO_BILLING !== true) {
  failures.push('ENABLE_PRO_BILLING must be true for the Pro store build')
}
if (pro.ENABLE_EDGE_SWIPE_BACK === true) {
  failures.push(
    'ENABLE_EDGE_SWIPE_BACK must stay false until the iOS/Android gesture regression is approved',
  )
}
for (const key of ['PRO_MONTHLY_PRODUCT_ID', 'PRO_YEARLY_PRODUCT_ID']) {
  if (!String(pro[key] || '').trim()) failures.push(`${key} must be configured`)
}
if (pro.ENABLE_PRO_LIFETIME === true && !String(pro.PRO_LIFETIME_PRODUCT_ID || '').trim()) {
  failures.push('PRO_LIFETIME_PRODUCT_ID must be configured when ENABLE_PRO_LIFETIME is true')
}

if (failures.length) {
  console.error(`Release configuration failed:\n- ${failures.join('\n- ')}`)
  process.exit(78)
}
NODE

release_api_base_url="${CARD_APP_API_BASE_URL:-https://card.lengziyu.cn}"
node tools/check_store_release_config.mjs "$pro_config" "$target" "$release_api_base_url"

supabase_config="config/supabase.local.json"
if [[ ! -f "$supabase_config" ]]; then
  echo "Missing $supabase_config. Store releases require an explicit Auth configuration." >&2
  exit 66
fi
node tools/check_auth_release_compatibility.mjs "$supabase_config" "$release_api_base_url" "$target"
node tools/check_comment_release_config.mjs "$target" "$release_api_base_url"

echo "Release configuration is valid: Pro billing, Auth, moderated comments and legal links are ready."
if [[ "$check_only" == true ]]; then
  exit 0
fi

defines=(
  "--dart-define-from-file=$legal_config"
  "--dart-define-from-file=$pro_config"
)

defines+=("--dart-define-from-file=$supabase_config")

firebase_config="config/firebase.ios.local.json"
if [[ "$target" == "appbundle" ]]; then
  firebase_config="config/firebase.android.local.json"
fi
if [[ -f "$firebase_config" ]]; then
  defines+=("--dart-define-from-file=$firebase_config")
fi

flutter build "$target" --release "${defines[@]}"
