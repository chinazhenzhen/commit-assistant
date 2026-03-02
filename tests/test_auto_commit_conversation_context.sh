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
cat > src/api.js <<'EOF'
export function fetchProfile() {
  return "ok";
}
EOF

git add src/api.js
git commit -q -m "chore: bootstrap"

cat > src/api.js <<'EOF'
export function fetchProfile() {
  throw new Error("timeout");
}
EOF

cat > context.txt <<'EOF'
用户反馈线上登录超时，请优先修复并补充回归检查说明，避免再次出现相同问题。
EOF

git add src/api.js

output="$("${SCRIPT_PATH}" --dry-run --no-push --context-file context.txt 2>&1)"

assert_contains "${output}" "fix:" "conversation context should guide commit type inference"
assert_contains "${output}" "Conversation context:" "commit body should include conversation context"
assert_contains "${output}" "线上登录超时" "conversation context text should be loaded into commit body"
assert_contains "${output}" "Compatibility:" "commit body should include compatibility information"
