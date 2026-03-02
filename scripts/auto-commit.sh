#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  auto-commit.sh [options]

Options:
  --all               Include untracked files (git add -A)
  --type TYPE         Commit type (feat|fix|docs|style|refactor|test|chore|perf|build|ci)
  --scope SCOPE       Commit scope
  --subject TEXT      Commit subject
  --body TEXT         Commit body (description)
  --intent TEXT       User intent/prompt context to guide type, subject, and body
  --intent-file PATH  Read additional user intent context from file
  --context TEXT      Conversation context to improve intent understanding
  --context-file PATH Read conversation context from file
  --no-auto-body      Disable auto-generated open-source style body
  --no-verify         Pass --no-verify to git commit
  --push              Force push after commit (default behavior)
  --no-push           Disable push after commit
  --remote REMOTE     Push to specific remote
  --branch BRANCH     Push to specific branch (default: current branch)
  --set-upstream      Use --set-upstream when pushing
  --dry-run           Print generated message and exit without committing
  -h, --help          Show this help
EOF
}

ensure_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: not inside a git repository."
    exit 1
  fi
}

stage_changes() {
  if [[ "$ADD_ALL" == "1" ]]; then
    git add -A
  else
    git add -u
  fi
}

normalize_intent() {
  local raw="$1"
  local normalized

  normalized="$(printf "%s" "$raw" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  normalized="$(printf "%s" "$normalized" | sed -E 's/^[Pp]lease[[:space:]]+//; s/^[Pp]ls[[:space:]]+//')"
  normalized="${normalized#请帮我}"
  normalized="${normalized#请}"
  normalized="${normalized#帮我}"
  normalized="$(printf "%s" "$normalized" | sed -E 's/[[:space:]]*[。.!！]+$//; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
  normalized="$(printf "%s" "$normalized" | cut -c1-160)"

  printf "%s" "$normalized"
}

normalize_context() {
  local raw="$1"
  local normalized

  normalized="$(printf "%s" "$raw" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  normalized="$(printf "%s" "$normalized" | sed -E 's/[[:space:]]*[。.!！]+$//; s/[[:space:]]+/ /g; s/^ //; s/ $//')"
  normalized="$(printf "%s" "$normalized" | cut -c1-240)"

  printf "%s" "$normalized"
}

build_semantic_signal() {
  local intent="$1"
  local context="$2"
  local signal=""

  if [[ -n "$intent" ]]; then
    signal="$intent"
  fi
  if [[ -n "$context" ]]; then
    if [[ -n "$signal" ]]; then
      signal+=" "
    fi
    signal+="$context"
  fi

  printf "%s" "$signal" | tr '[:upper:]' '[:lower:]'
}

contains_any() {
  local haystack="$1"
  shift
  local needle

  for needle in "$@"; do
    if [[ "$haystack" == *"$needle"* ]]; then
      return 0
    fi
  done
  return 1
}

infer_type_from_intent() {
  local intent="$1"
  local lowered

  [[ -z "$intent" ]] && { echo ""; return; }

  lowered="$(printf "%s" "$intent" | tr '[:upper:]' '[:lower:]')"

  if contains_any "$lowered" \
    "fix" "bug" "hotfix" "regression" "error" "crash" "panic" "issue" "defect" "timeout" "deadlock" "infinite loop" \
    "security" "vulnerability" "cve" "xss" "csrf" "sqli" "auth bypass" "privilege escalation" \
    "修复" "修正" "修補" "修復" "错误" "錯誤" "故障" "异常" "異常" "崩溃" "崩潰" "超时" "超時" "死循环" "死循環" \
    "安全" "漏洞" "越权" "越權" "注入" "绕过" "繞過"; then
    echo "fix"
    return
  fi

  if contains_any "$lowered" "perf" "performance" "optimize" "optimise" "latency" "throughput" "speed up" "reduce overhead" "性能" "优化" "優化" "提速" "降耗"; then
    echo "perf"
    return
  fi

  if contains_any "$lowered" "refactor" "cleanup" "clean up" "restructure" "simplify" "decouple" "重构" "重構" "重整" "整理" "解耦" "简化" "簡化"; then
    echo "refactor"
    return
  fi

  if contains_any "$lowered" "test" "testing" "coverage" "unit test" "integration test" "e2e" "regression test" "测试" "測試" "用例" "回归测试" "回歸測試" "补测" "補測"; then
    echo "test"
    return
  fi

  if contains_any "$lowered" "docs" "doc " "readme" "changelog" "documentation" "guide" "adr" "文档" "文檔" "说明" "說明" "手册" "手冊"; then
    echo "docs"
    return
  fi

  if contains_any "$lowered" "ci" "pipeline" "workflow" "github action" "gitlab ci" "jenkins" "buildkite" "持续集成" "持續集成" "流水线" "流水線"; then
    echo "ci"
    return
  fi

  if contains_any "$lowered" "build" "dependency" "dependencies" "deps" "version bump" "release" "packaging" "toolchain" "lockfile" "bump" "upgrade" "downgrade" "构建" "構建" "依赖" "依賴" "升级" "升級" "降级" "降級"; then
    echo "build"
    return
  fi

  if contains_any "$lowered" "format" "lint" "style" "prettier" "eslint" "flake8" "black" "ruff" "isort" "代码风格" "代碼風格" "格式化"; then
    echo "style"
    return
  fi

  if contains_any "$lowered" "chore" "maintenance" "housekeeping" "cleanup task" "rename" "move file" "sync metadata" "日常维护" "日常維護" "维护" "維護" "重命名" "迁移文件" "遷移文件"; then
    echo "chore"
    return
  fi

  if contains_any "$lowered" "add" "implement" "introduce" "support" "enable" "create" "new " "新增" "添加" "实现" "實現" "支持" "支援" "引入"; then
    echo "feat"
    return
  fi

  echo ""
}

infer_type_from_files() {
  local files="$1"
  local has_src=0
  local has_docs=0
  local has_tests=0
  local has_cfg=0

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    [[ "$f" =~ (^|/)(README|CHANGELOG|LICENSE|docs?)/|\.md$|\.rst$|\.txt$ ]] && has_docs=1
    [[ "$f" =~ (^|/)(test|tests|__tests__)/|(_test\.)|(\.test\.)|(\.spec\.) ]] && has_tests=1
    [[ "$f" =~ (^|/)(\.github|\.gitlab|scripts|config)/|(^|/)(Dockerfile|Makefile|compose\.ya?ml)|\.(ya?ml|toml|ini|cfg|conf)$ ]] && has_cfg=1
    [[ "$f" =~ \.(js|jsx|ts|tsx|py|go|rs|java|kt|swift|c|cc|cpp|h|hpp|rb|php|scala|cs)$ ]] && has_src=1
  done <<< "$files"

  if [[ "$has_src" == "1" ]]; then
    echo "feat"
  elif [[ "$has_tests" == "1" && "$has_docs" == "0" && "$has_cfg" == "0" ]]; then
    echo "test"
  elif [[ "$has_docs" == "1" && "$has_src" == "0" && "$has_cfg" == "0" ]]; then
    echo "docs"
  elif [[ "$has_cfg" == "1" && "$has_src" == "0" ]]; then
    echo "chore"
  else
    echo "chore"
  fi
}

infer_type() {
  local files="$1"
  local intent="$2"
  local context="$3"
  local semantic
  local type_from_intent

  semantic="$(build_semantic_signal "$intent" "$context")"
  type_from_intent="$(infer_type_from_intent "$semantic")"
  if [[ -n "$type_from_intent" ]]; then
    echo "$type_from_intent"
    return
  fi

  infer_type_from_files "$files"
}

subject_from_intent() {
  local intent="$1"
  local commit_type="$2"
  local lowered

  [[ -z "$intent" ]] && { echo ""; return; }
  lowered="$(printf "%s" "$intent" | tr '[:upper:]' '[:lower:]')"

  case "$commit_type" in
    fix)
      if [[ "$lowered" == fix* || "$lowered" == resolve* || "$lowered" == repair* || "$lowered" == correct* ]] || [[ "$intent" =~ ^(修复|修正|修補|修復) ]]; then
        echo "$intent"
      else
        echo "fix ${intent}"
      fi
      ;;
    feat)
      if [[ "$lowered" == add* || "$lowered" == implement* || "$lowered" == introduce* || "$lowered" == support* || "$lowered" == enable* || "$lowered" == create* ]] || [[ "$intent" =~ ^(新增|添加|实现|實現|支持|支援|引入) ]]; then
        echo "$intent"
      else
        echo "add ${intent}"
      fi
      ;;
    docs)
      if [[ "$lowered" == docs* || "$lowered" == doc* || "$lowered" == document* || "$lowered" == update\ docs* ]] || [[ "$intent" =~ ^(文档|文檔|说明|說明) ]]; then
        echo "$intent"
      else
        echo "document ${intent}"
      fi
      ;;
    test)
      if [[ "$lowered" == test* || "$lowered" == add\ test* || "$lowered" == improve\ test* ]] || [[ "$intent" =~ ^(测试|測試|补充测试|補充測試) ]]; then
        echo "$intent"
      else
        echo "add tests for ${intent}"
      fi
      ;;
    refactor)
      if [[ "$lowered" == refactor* || "$lowered" == cleanup* || "$lowered" == clean\ up* ]] || [[ "$intent" =~ ^(重构|重構|整理|重整) ]]; then
        echo "$intent"
      else
        echo "refactor ${intent}"
      fi
      ;;
    perf)
      if [[ "$lowered" == perf* || "$lowered" == optimize* || "$lowered" == optimise* ]] || [[ "$intent" =~ ^(优化|優化|性能|提速) ]]; then
        echo "$intent"
      else
        echo "optimize ${intent}"
      fi
      ;;
    build)
      if [[ "$lowered" == build* || "$lowered" == bump* || "$lowered" == upgrade* || "$lowered" == update\ dependencies* ]] || [[ "$intent" =~ ^(构建|構建|升级|升級|依赖|依賴) ]]; then
        echo "$intent"
      else
        echo "update build for ${intent}"
      fi
      ;;
    ci)
      if [[ "$lowered" == ci* || "$lowered" == update\ ci* || "$lowered" == workflow* || "$lowered" == pipeline* ]] || [[ "$intent" =~ ^(持续集成|持續集成|流水线|流水線) ]]; then
        echo "$intent"
      else
        echo "update ci for ${intent}"
      fi
      ;;
    style)
      if [[ "$lowered" == style* || "$lowered" == lint* || "$lowered" == format* ]] || [[ "$intent" =~ ^(格式化|代码风格|代碼風格) ]]; then
        echo "$intent"
      else
        echo "clean up style for ${intent}"
      fi
      ;;
    chore)
      if [[ "$lowered" == chore* || "$lowered" == maintain* || "$lowered" == maintenance* ]] || [[ "$intent" =~ ^(维护|維護|日常维护|日常維護) ]]; then
        echo "$intent"
      else
        echo "maintain ${intent}"
      fi
      ;;
    *)
      echo "$intent"
      ;;
  esac
}

generate_subject_from_files() {
  local files="$1"
  local first count
  local first_dir action

  count=$(printf "%s\n" "$files" | sed '/^$/d' | wc -l | tr -d ' ')
  first=$(printf "%s\n" "$files" | sed '/^$/d' | head -n 1)

  if [[ -z "${first:-}" ]]; then
    echo "update repository files"
    return
  fi

  first_dir=$(dirname "$first")
  if [[ "$first_dir" == "." ]]; then
    first_dir="root"
  fi

  action="$(git diff --cached --name-status | awk '
    BEGIN{a=0;m=0;d=0}
    $1 ~ /^A/ {a++}
    $1 ~ /^D/ {d++}
    $1 ~ /^M/ || $1 ~ /^R/ || $1 ~ /^C/ {m++}
    END{
      if (a>0 && d==0 && m==0) print "add";
      else if (d>0 && a==0 && m==0) print "remove";
      else print "update";
    }
  ')"

  if [[ "$count" -eq 1 ]]; then
    echo "${action} ${first}"
  else
    echo "${action} ${first_dir} files"
  fi
}

generate_subject() {
  local files="$1"
  local intent="$2"
  local context="$3"
  local commit_type="$4"
  local subject_source
  local intent_subject

  subject_source="$intent"
  if [[ -z "$subject_source" ]]; then
    subject_source="$context"
  fi

  intent_subject="$(subject_from_intent "$subject_source" "$commit_type")"
  if [[ -n "$intent_subject" ]]; then
    echo "$intent_subject"
    return
  fi

  generate_subject_from_files "$files"
}

validate_type() {
  case "$1" in
    feat|fix|docs|style|refactor|test|chore|perf|build|ci) ;;
    *)
      echo "Error: invalid --type '$1'."
      exit 1
      ;;
  esac
}

motivation_for_type() {
  local commit_type="$1"

  case "$commit_type" in
    feat) echo "Introduce behavior changes while keeping interfaces predictable for users and contributors." ;;
    fix) echo "Correct defects and reduce regression risk for downstream usage." ;;
    docs) echo "Keep contributor and user documentation aligned with the latest code behavior." ;;
    refactor) echo "Improve maintainability without changing expected behavior." ;;
    test) echo "Increase regression coverage to make future changes safer." ;;
    perf) echo "Reduce runtime overhead without weakening correctness checks." ;;
    build) echo "Keep dependency and build flows stable for local and CI environments." ;;
    ci) echo "Keep automation pipelines deterministic and easier to debug for contributors." ;;
    style) echo "Improve code readability and consistency while preserving behavior." ;;
    chore) echo "Apply maintenance updates needed to keep day-to-day development smooth." ;;
    *) echo "Keep this change set clear and reviewable for open-source collaboration." ;;
  esac
}

classify_file_area() {
  local file="$1"

  if [[ "$file" =~ (^|/)(test|tests|__tests__)/ ]] || [[ "$file" =~ (_test\.go$|\.test\.|\.spec\.|(^|/)test_.*\.py$|_test\.py$) ]]; then
    echo "tests"
    return
  fi

  case "$file" in
    go.mod|go.sum|*/go.mod|*/go.sum|pyproject.toml|*/pyproject.toml|poetry.lock|*/poetry.lock|Pipfile|*/Pipfile|Pipfile.lock|*/Pipfile.lock|requirements*.txt|*/requirements*.txt|setup.py|*/setup.py|setup.cfg|*/setup.cfg|package.json|*/package.json|package-lock.json|*/package-lock.json|yarn.lock|*/yarn.lock|pnpm-lock.yaml|*/pnpm-lock.yaml|Cargo.toml|*/Cargo.toml|Cargo.lock|*/Cargo.lock|Gemfile|*/Gemfile|Gemfile.lock|*/Gemfile.lock|composer.json|*/composer.json|composer.lock|*/composer.lock)
      echo "dependencies"
      return
      ;;
  esac

  if [[ "$file" =~ \.(go|py|js|jsx|ts|tsx|rs|java|kt|swift|c|cc|cpp|h|hpp|rb|php|scala|cs|sh|bash|zsh)$ ]]; then
    echo "source"
    return
  fi

  if [[ "$file" =~ (^|/)(README|CHANGELOG|LICENSE|docs?)/|\.md$|\.rst$|\.txt$ ]]; then
    echo "documentation"
    return
  fi

  if [[ "$file" =~ (^|/)(\.github|\.gitlab|scripts|config)/|(^|/)(Dockerfile|Makefile|compose\.ya?ml)|\.(ya?ml|toml|ini|cfg|conf)$ ]]; then
    echo "ci/config"
    return
  fi

  echo "project files"
}

collect_focus_areas() {
  local files="$1"
  local segments=()
  local seen="|"
  local file segment
  local max_segments=3

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    segment="${file%%/*}"
    if [[ "$seen" == *"|${segment}|"* ]]; then
      continue
    fi
    segments+=("${segment}")
    seen+="${segment}|"
    if [[ "${#segments[@]}" -ge "$max_segments" ]]; then
      break
    fi
  done <<< "$files"

  if [[ "${#segments[@]}" -eq 0 ]]; then
    echo "repository files"
  elif [[ "${#segments[@]}" -eq 1 ]]; then
    echo "${segments[0]}"
  elif [[ "${#segments[@]}" -eq 2 ]]; then
    echo "${segments[0]} and ${segments[1]}"
  else
    echo "${segments[0]}, ${segments[1]}, and ${segments[2]}"
  fi
}

generate_change_items() {
  local status_lines="$1"
  local out=""
  local status path_a path_b area
  local count=0
  local limit=10

  while IFS=$'\t' read -r status path_a path_b; do
    [[ -z "${status:-}" ]] && continue

    if [[ "$count" -lt "$limit" ]]; then
      case "$status" in
        A*)
          area="$(classify_file_area "$path_a")"
          out+="- add ${path_a} (${area})"$'\n'
          ;;
        D*)
          area="$(classify_file_area "$path_a")"
          out+="- remove ${path_a} (${area})"$'\n'
          ;;
        M*)
          area="$(classify_file_area "$path_a")"
          out+="- update ${path_a} (${area})"$'\n'
          ;;
        R*)
          area="$(classify_file_area "${path_b:-$path_a}")"
          out+="- rename ${path_a} -> ${path_b} (${area})"$'\n'
          ;;
        C*)
          area="$(classify_file_area "${path_b:-$path_a}")"
          out+="- copy ${path_a} -> ${path_b} (${area})"$'\n'
          ;;
        *)
          area="$(classify_file_area "${path_a:-${path_b:-files}}")"
          out+="- update ${path_a:-${path_b:-files}} (${area})"$'\n'
          ;;
      esac
    fi

    count=$((count + 1))
  done <<< "$status_lines"

  if [[ "$count" -gt "$limit" ]]; then
    out+="- ...and $((count - limit)) more change(s)"$'\n'
  fi
  if [[ -z "$out" ]]; then
    out="- update tracked files"$'\n'
  fi

  printf "%s" "$out"
}

summarize_area_scope() {
  local files="$1"
  local source=0
  local deps=0
  local tests=0
  local docs=0
  local cfg=0
  local other=0
  local file area
  local parts=()
  local out=""
  local part

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    area="$(classify_file_area "$file")"
    case "$area" in
      "source") source=$((source + 1)) ;;
      "dependencies") deps=$((deps + 1)) ;;
      "tests") tests=$((tests + 1)) ;;
      "documentation") docs=$((docs + 1)) ;;
      "ci/config") cfg=$((cfg + 1)) ;;
      *) other=$((other + 1)) ;;
    esac
  done <<< "$files"

  [[ "$source" -gt 0 ]] && parts+=("${source} source file")
  [[ "$deps" -gt 0 ]] && parts+=("${deps} dependency file")
  [[ "$tests" -gt 0 ]] && parts+=("${tests} test file")
  [[ "$docs" -gt 0 ]] && parts+=("${docs} documentation file")
  [[ "$cfg" -gt 0 ]] && parts+=("${cfg} ci/config file")
  [[ "$other" -gt 0 ]] && parts+=("${other} project file")

  if [[ "${#parts[@]}" -eq 0 ]]; then
    echo "tracked files"
    return
  fi

  for part in "${parts[@]}"; do
    if [[ -n "$out" ]]; then
      out+=", "
    fi
    out+="$part"
  done
  printf "%s" "$out"
}

compatibility_note() {
  local files="$1"
  local semantic="$2"
  local file

  if contains_any "$semantic" "breaking change" "incompatible" "major version" "migration" "migrate" "api break" "破坏性" "破壞性" "不兼容" "不相容" "迁移" "遷移"; then
    echo "Potential compatibility impact is signaled by context; confirm migration notes for downstream users."
    return
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" =~ (^|/)(api|apis|public|contracts?|schema|schemas|proto|protobuf|types?|interfaces?)/ ]] || [[ "$file" =~ \.(proto|graphql|avsc)$ ]]; then
      echo "Public contract-related files changed; verify downstream integrations and API compatibility."
      return
    fi
  done <<< "$files"

  echo "No obvious public API breaking change is inferred from staged files."
}

generate_body() {
  local files="$1"
  local intent="$2"
  local context="$3"
  local total why focus status_lines changes shortstat scope_summary why_intent why_context semantic compat_note

  total=$(printf "%s\n" "$files" | sed '/^$/d' | wc -l | tr -d ' ')
  why="$(motivation_for_type "$TYPE")"
  focus="$(collect_focus_areas "$files")"
  status_lines="$(git diff --cached --name-status)"
  changes="$(generate_change_items "$status_lines")"
  shortstat="$(git diff --cached --shortstat | sed 's/^ *//')"
  scope_summary="$(summarize_area_scope "$files")"
  semantic="$(build_semantic_signal "$intent" "$context")"
  if [[ -z "$shortstat" ]]; then
    shortstat="${total} file(s) changed"
  fi

  why_intent=""
  if [[ -n "$intent" ]]; then
    why_intent="- Address user intent: ${intent}
"
  else
    why_intent="- User intent is inferred from staged changes.
"
  fi

  why_context=""
  if [[ -n "$context" ]]; then
    why_context="- Conversation context: ${context}
"
  fi

  compat_note="$(compatibility_note "$files" "$semantic")"

  cat <<EOF
Why:
- ${why}
${why_intent}${why_context}- Keep updates in ${focus} easy to review and release.

What changed:
${changes}
Impact:
- scope: ${scope_summary}
- Diff summary: ${shortstat}
- Compatibility: ${compat_note}
EOF
}

push_commit() {
  local remote="$1"
  local branch="$2"
  local set_upstream="$3"
  local remote_count
  local cmd=(git push)

  if [[ -z "$branch" ]]; then
    branch="$(git symbolic-ref --quiet --short HEAD || true)"
  fi
  if [[ -z "$branch" ]]; then
    echo "Skip push: detached HEAD and no --branch provided."
    return 0
  fi

  if [[ "$set_upstream" == "1" ]]; then
    if [[ -z "$remote" ]]; then
      remote="origin"
    fi
    cmd+=(--set-upstream "$remote" "$branch")
  else
    if [[ -n "$remote" ]]; then
      cmd+=("$remote" "$branch")
    else
      if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        :
      else
        remote_count="$(git remote | wc -l | tr -d ' ')"
        if [[ "$remote_count" -eq 1 ]]; then
          remote="$(git remote | head -n 1)"
          cmd+=(--set-upstream "$remote" "$branch")
        else
          echo "Skip push: no upstream branch. Use --remote <name> or --set-upstream."
          return 0
        fi
      fi
    fi
  fi

  echo "Running: ${cmd[*]}"
  "${cmd[@]}"
  echo "Push completed successfully."
}

ADD_ALL=0
TYPE=""
SCOPE=""
SUBJECT=""
BODY=""
INTENT_TEXT=""
INTENT_SUMMARY=""
INTENT_FILES=()
CONTEXT_TEXT=""
CONTEXT_SUMMARY=""
CONTEXT_FILES=()
AUTO_BODY=1
NO_VERIFY=0
DO_PUSH=1
REMOTE=""
BRANCH=""
SET_UPSTREAM=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) ADD_ALL=1 ;;
    --type) TYPE="${2:-}"; shift ;;
    --scope) SCOPE="${2:-}"; shift ;;
    --subject) SUBJECT="${2:-}"; shift ;;
    --body) BODY="${2:-}"; shift ;;
    --intent)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --intent requires a value."
        exit 1
      fi
      if [[ -n "$INTENT_TEXT" ]]; then
        INTENT_TEXT+=$'\n'
      fi
      INTENT_TEXT+="${2}"
      shift
      ;;
    --intent-file)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --intent-file requires a path."
        exit 1
      fi
      INTENT_FILES+=("${2}")
      shift
      ;;
    --context)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --context requires a value."
        exit 1
      fi
      if [[ -n "$CONTEXT_TEXT" ]]; then
        CONTEXT_TEXT+=$'\n'
      fi
      CONTEXT_TEXT+="${2}"
      shift
      ;;
    --context-file)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --context-file requires a path."
        exit 1
      fi
      CONTEXT_FILES+=("${2}")
      shift
      ;;
    --no-auto-body) AUTO_BODY=0 ;;
    --no-verify) NO_VERIFY=1 ;;
    --push) DO_PUSH=1 ;;
    --no-push) DO_PUSH=0 ;;
    --remote) REMOTE="${2:-}"; shift ;;
    --branch) BRANCH="${2:-}"; shift ;;
    --set-upstream) SET_UPSTREAM=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "Error: unknown option '$1'"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$INTENT_TEXT" && -n "${COMMIT_ASSISTANT_INTENT:-}" ]]; then
  INTENT_TEXT="${COMMIT_ASSISTANT_INTENT}"
fi

if [[ -z "$CONTEXT_TEXT" && -n "${COMMIT_ASSISTANT_CONTEXT:-}" ]]; then
  CONTEXT_TEXT="${COMMIT_ASSISTANT_CONTEXT}"
fi

if [[ "${#INTENT_FILES[@]}" -gt 0 ]]; then
  for intent_file in "${INTENT_FILES[@]}"; do
    if [[ ! -f "$intent_file" ]]; then
      echo "Error: intent file not found: ${intent_file}"
      exit 1
    fi
    intent_content="$(cat "$intent_file")"
    [[ -z "$intent_content" ]] && continue
    if [[ -n "$INTENT_TEXT" ]]; then
      INTENT_TEXT+=$'\n'
    fi
    INTENT_TEXT+="$intent_content"
  done
fi

if [[ "${#CONTEXT_FILES[@]}" -gt 0 ]]; then
  for context_file in "${CONTEXT_FILES[@]}"; do
    if [[ ! -f "$context_file" ]]; then
      echo "Error: context file not found: ${context_file}"
      exit 1
    fi
    context_content="$(cat "$context_file")"
    [[ -z "$context_content" ]] && continue
    if [[ -n "$CONTEXT_TEXT" ]]; then
      CONTEXT_TEXT+=$'\n'
    fi
    CONTEXT_TEXT+="$context_content"
  done
fi

INTENT_SUMMARY="$(normalize_intent "$INTENT_TEXT")"
CONTEXT_SUMMARY="$(normalize_context "$CONTEXT_TEXT")"

ensure_git_repo
stage_changes

if git diff --cached --quiet; then
  echo "No staged changes to commit."
  exit 0
fi

FILES="$(git diff --cached --name-only)"

if [[ -z "$TYPE" ]]; then
  TYPE="$(infer_type "$FILES" "$INTENT_SUMMARY" "$CONTEXT_SUMMARY")"
fi
validate_type "$TYPE"

if [[ -z "$SUBJECT" ]]; then
  SUBJECT="$(generate_subject "$FILES" "$INTENT_SUMMARY" "$CONTEXT_SUMMARY" "$TYPE")"
fi

# Normalize: lowercase first letter and strip trailing period.
SUBJECT="${SUBJECT%.}"
if [[ -n "$SUBJECT" ]]; then
  first_char="${SUBJECT:0:1}"
  rest_chars="${SUBJECT:1}"
  if [[ "$first_char" =~ [A-Z] ]]; then
    first_char="${first_char,,}"
  fi
  SUBJECT="${first_char}${rest_chars}"
fi
SUBJECT="$(printf "%s" "$SUBJECT" | cut -c1-72)"

if [[ -n "$SCOPE" ]]; then
  HEADER="${TYPE}(${SCOPE}): ${SUBJECT}"
else
  HEADER="${TYPE}: ${SUBJECT}"
fi

if [[ -z "$BODY" && "$AUTO_BODY" == "1" ]]; then
  BODY="$(generate_body "$FILES" "$INTENT_SUMMARY" "$CONTEXT_SUMMARY")"
fi

echo "Generated commit message:"
echo "$HEADER"
if [[ -n "$BODY" ]]; then
  echo
  echo "$BODY"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo
  echo "Dry run enabled; no commit created."
  if [[ "$DO_PUSH" == "1" ]]; then
    echo "Dry run: push step would run after commit."
  fi
  exit 0
fi

if [[ "$NO_VERIFY" == "1" ]]; then
  if [[ -n "$BODY" ]]; then
    git commit --no-verify -m "$HEADER" -m "$BODY"
  else
    git commit --no-verify -m "$HEADER"
  fi
else
  if [[ -n "$BODY" ]]; then
    git commit -m "$HEADER" -m "$BODY"
  else
    git commit -m "$HEADER"
  fi
fi

echo "Commit created successfully."

if [[ "$DO_PUSH" == "1" ]]; then
  push_commit "$REMOTE" "$BRANCH" "$SET_UPSTREAM"
else
  echo "Push skipped (--no-push)."
fi
