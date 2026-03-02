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

run_case() {
  local content="$1"
  local expected_type="$2"
  local intent="$3"
  local context="$4"
  local tmp_dir output
  local cmd=("${SCRIPT_PATH}" --dry-run --no-push)

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN
  cd "${tmp_dir}"

  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  cat > app.txt <<'EOF'
v1
EOF
  git add app.txt
  git commit -q -m "chore: bootstrap"

  cat > app.txt <<EOF
${content}
EOF
  git add app.txt

  if [[ -n "$intent" ]]; then
    cmd+=(--intent "${intent}")
  fi
  if [[ -n "$context" ]]; then
    cmd+=(--context "${context}")
  fi

  output="$("${cmd[@]}" 2>&1)"
  assert_contains "${output}" "${expected_type}:" "keyword mapping should infer ${expected_type}"
}

run_case "security patch" "fix" "" "修复鉴权安全漏洞并阻断越权访问"
run_case "faster cache" "perf" "优化缓存命中路径并降低延迟" ""
run_case "docs update" "docs" "补充部署文档和升级说明" ""
