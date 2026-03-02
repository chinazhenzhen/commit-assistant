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

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    echo "Assertion failed: ${message}"
    echo "Unexpected content: ${needle}"
    exit 1
  fi
}

run_go_case() {
  local tmp_dir output
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  cd "${tmp_dir}"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  mkdir -p internal/service
  cat > go.mod <<'EOF'
module example.com/demo

go 1.22
EOF
  cat > internal/service/user.go <<'EOF'
package service

func Name() string {
    return "v1"
}
EOF
  git add .
  git commit -q -m "chore: bootstrap go"

  cat > go.mod <<'EOF'
module example.com/demo

go 1.23
EOF
  cat > internal/service/user.go <<'EOF'
package service

func Name() string {
    return "v2"
}
EOF
  cat > internal/service/user_test.go <<'EOF'
package service

import "testing"

func TestName(t *testing.T) {
    if Name() == "" {
        t.Fatal("empty")
    }
}
EOF

  git add .
  output="$("${SCRIPT_PATH}" --dry-run --no-push --type fix --subject "tighten go behavior" 2>&1)"

  assert_contains "${output}" "- update go.mod (dependencies)" "dependencies should be identified generically"
  assert_contains "${output}" "- update internal/service/user.go (source)" "source should be identified generically"
  assert_contains "${output}" "- add internal/service/user_test.go (tests)" "go tests should be identified"
  assert_not_contains "${output}" "go dependencies" "language-specific dependency label should be removed"
  assert_not_contains "${output}" "go source" "language-specific source label should be removed"
}

run_python_case() {
  local tmp_dir output
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "${tmp_dir}"' RETURN

  cd "${tmp_dir}"
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  mkdir -p src/app tests
  cat > pyproject.toml <<'EOF'
[project]
name = "demo"
version = "0.1.0"
EOF
  cat > src/app/core.py <<'EOF'
def greeting():
    return "v1"
EOF
  git add .
  git commit -q -m "chore: bootstrap py"

  cat > pyproject.toml <<'EOF'
[project]
name = "demo"
version = "0.1.1"
EOF
  cat > src/app/core.py <<'EOF'
def greeting():
    return "v2"
EOF
  cat > tests/test_core.py <<'EOF'
from app.core import greeting

def test_greeting():
    assert greeting() == "v2"
EOF

  git add .
  output="$("${SCRIPT_PATH}" --dry-run --no-push --type feat --subject "improve python behavior" 2>&1)"

  assert_contains "${output}" "- update pyproject.toml (dependencies)" "dependencies should be identified generically"
  assert_contains "${output}" "- update src/app/core.py (source)" "source should be identified generically"
  assert_contains "${output}" "- add tests/test_core.py (tests)" "python tests should be identified"
  assert_not_contains "${output}" "python dependencies" "language-specific dependency label should be removed"
  assert_not_contains "${output}" "python source" "language-specific source label should be removed"
}

run_go_case
run_python_case
