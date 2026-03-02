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

cat > app.js <<'EOF'
console.log("v1");
EOF

git add app.js
git commit -q -m "chore: bootstrap"

cat > app.js <<'EOF'
console.log("v2");
EOF

mkdir -p docs
cat > docs/usage.md <<'EOF'
# Usage
EOF

git add app.js docs/usage.md

output="$("${SCRIPT_PATH}" --dry-run --no-push --type feat --subject "improve generated commit description" 2>&1)"

assert_contains "${output}" "Why:" "commit body should explain motivation"
assert_contains "${output}" "What changed:" "commit body should list key changes"
assert_contains "${output}" "Impact:" "commit body should summarize impact"
assert_contains "${output}" "Compatibility:" "impact should include compatibility signal"
assert_contains "${output}" "- update app.js" "commit body should include actionable change entries"
