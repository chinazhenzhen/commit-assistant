#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_PATH="${ROOT_DIR}/SKILL.md"
README_PATH="${ROOT_DIR}/README.md"
README_EN_PATH="${ROOT_DIR}/README_EN.md"

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

skill_content="$(cat "${SKILL_PATH}")"
readme_content="$(cat "${README_PATH}")"
readme_en_content="$(cat "${README_EN_PATH}")"

assert_contains "${skill_content}" "Do not ask the user to confirm a dry run, message preview, or commit execution when they already asked to commit." "skill should explicitly forbid confirmation loops"
assert_contains "${skill_content}" "Default to commit-and-push automation." "skill should prefer full automation"
assert_contains "${skill_content}" "Treat normal commit and push operations as pre-authorized" "skill should explicitly pre-authorize commit and push"
assert_contains "${skill_content}" "Only pause for confirmation when the next action is genuinely high-risk" "skill should only stop for high-risk operations"
assert_not_contains "${skill_content}" "Run \`scripts/auto-commit.sh --dry-run\` first" "skill should not force dry-run before commit"
assert_not_contains "${skill_content}" "Push only when the user explicitly asks for it" "skill should no longer require explicit push requests"

assert_not_contains "${readme_content}" "先预览：" "README should not promote preview-first as the default flow"
assert_not_contains "${readme_en_content}" "Preview first:" "English README should not promote preview-first as the default flow"
assert_contains "${readme_content}" "默认直接提交并推送" "README should document push as the default flow"
assert_contains "${readme_en_content}" "Direct commit and push by default" "English README should document push as the default flow"
