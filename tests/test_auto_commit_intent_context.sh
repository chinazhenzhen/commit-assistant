#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/scripts/auto-commit.sh"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    echo "Assertion failed: ${message}"
    echo "Expected to find: ${needle}"
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

cd "${tmp_dir}"
git init -q
git config user.name "Test User"
git config user.email "test@example.com"

mkdir -p src
cat > src/login.js <<'EOF'
export function retryLogin(token) {
  return token;
}
EOF

git add src/login.js
git commit -q -m "chore: bootstrap"

cat > src/login.js <<'EOF'
export function retryLogin(token, retries = 3) {
  if (!token) {
    throw new Error("missing token");
  }
  if (retries < 1) {
    return token;
  }
  return retryLogin(token, retries - 1);
}
EOF

git add src/login.js

intent_text="修复登录重试导致死循环并补充错误提示"
output="$("${SCRIPT_PATH}" --dry-run --no-push --intent "${intent_text}" 2>&1)"

assert_contains "${output}" "fix:" "intent keyword should guide commit type inference"
assert_contains "${output}" "${intent_text}" "commit body should include user intent context"
assert_contains "${output}" "- update src/login.js (source)" "commit body should still include concrete file-level changes"
