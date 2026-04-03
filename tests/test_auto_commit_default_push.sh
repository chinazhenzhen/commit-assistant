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

assert_equals() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Assertion failed: ${message}"
    echo "Expected: ${expected}"
    echo "Actual:   ${actual}"
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

remote_dir="${tmp_dir}/remote.git"
repo_dir="${tmp_dir}/repo"

git init --bare -q "${remote_dir}"
git init -q "${repo_dir}"

cd "${repo_dir}"
git config user.name "Test User"
git config user.email "test@example.com"

cat > app.txt <<'EOF'
v1
EOF

git add app.txt
git commit -q -m "chore: bootstrap"
git branch -M main
git remote add origin "${remote_dir}"
git push -q -u origin main

cat > app.txt <<'EOF'
v2
EOF

git add app.txt

previous_remote_head="$(git ls-remote origin refs/heads/main | awk '{print $1}')"
output="$("${SCRIPT_PATH}" --type chore --subject "update app text" 2>&1)"
current_remote_head="$(git ls-remote origin refs/heads/main | awk '{print $1}')"
current_subject="$(git log -1 --pretty=%s)"
current_local_head="$(git rev-parse HEAD)"

assert_equals "${current_subject}" "chore: update app text" "script should still create the commit locally"
assert_equals "${current_remote_head}" "${current_local_head}" "script should push by default"
assert_contains "${output}" "Push completed successfully." "script should report successful push by default"
