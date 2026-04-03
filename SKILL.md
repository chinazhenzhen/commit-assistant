---
name: commit-assistant
description: Use when the user asks to generate git commits (and optional push) where the commit header/body must reflect user intent and staged code changes in an open-source friendly style
---

# Commit Assistant

Use this skill when the user wants automated commit creation in a local git repository.

## When to use / not use

Use when:

- The user asks to create a commit (optionally with push).
- Commit message quality must reflect conversation intent and staged diff evidence.
- The workflow expects Conventional Commit format plus structured description.

Do not use when:

- The user only asks for a draft message and explicitly does not want an actual commit.
- The repository has no staged changes and the user does not want `--all`.

## Autonomous execution policy

- Do not ask the user to confirm a dry run, message preview, or commit execution when they already asked to commit.
- Do not ask whether you should inspect staged changes, infer commit fields, or run the script. Those are part of the skill.
- Default to commit-and-push automation.
- Treat normal commit and push operations as pre-authorized when the user asks to commit changes with this skill.
- Only pause for confirmation when the next action is genuinely high-risk, such as force-push, history rewrite, branch deletion, destructive reset, or pushing to an unclear target.
- Use `--dry-run` only when the user explicitly asks to preview, review, or draft the commit message without creating the commit.
- Ask a follow-up only when automation is blocked by missing staged changes, missing git identity, or an unresolved push target that cannot be inferred safely.

## Workflow (intent + diff first)

1. Load conversation context first:
   - latest user prompt
   - user constraints from earlier turns
   - any explicit "why" or acceptance criteria from the dialogue
2. Distill two short inputs:
   - `intent`: what the user wants this commit to accomplish
   - `context`: supporting constraints/background from conversation
3. Inspect staged changes (`git diff --cached --name-status` and key hunks) to confirm what actually changed.
4. Generate Conventional Commit `type/scope/subject` that matches intent + context + diff evidence.
5. Generate open-source style description (`Why / What changed / Impact`).
6. Run `scripts/auto-commit.sh` directly for actual commits.
7. Add `--dry-run` only for preview-only requests.
8. Let the script push by default for normal automation.
9. Add `--no-push` only when the user explicitly wants a local-only commit.

If conversation intent and staged diff conflict, prioritize actual staged code and call out the mismatch.

## Validation checklist

- Confirm staged files are not empty before commit.
- Do not insert a preview/confirmation step unless the user asked for one.
- Ensure the final body contains `Why / What changed / Impact`.
- Treat normal push as part of the default execution path.
- Stop only for high-risk git operations or an unresolved push destination.

## Script

Use:

```bash
scripts/auto-commit.sh [options]
```

Options:

- `--all` include untracked files (`git add -A`)
- `--type <type>` commit type (`feat|fix|docs|style|refactor|test|chore|perf|build|ci`)
- `--scope <scope>` commit scope
- `--subject <text>` commit subject
- `--body <text>` commit body (description)
- `--intent <text>` pass distilled user intent to guide type/subject/body inference
- `--intent-file <path>` load additional prompt/context from file
- `--context <text>` pass conversation constraints/background
- `--context-file <path>` load conversation constraints/background from file
- `COMMIT_ASSISTANT_INTENT` (env) fallback intent source
- `COMMIT_ASSISTANT_CONTEXT` (env) fallback context source
- `--no-auto-body` disable auto-generated open-source style body
- `--no-verify` pass through to `git commit`
- `--push` explicitly enable push after commit (matches default behavior)
- `--no-push` disable push after commit
- `--remote <name>` push to a specific remote
- `--branch <name>` push to a specific branch
- `--set-upstream` push with `--set-upstream`
- `--dry-run` show generated commit message and stop before commit

## Recommended invocation

For the normal automatic path, commit and push directly without a preview round trip:

```bash
scripts/auto-commit.sh \
  --intent "修复登录重试导致死循环并补充错误提示" \
  --context "线上稳定性优先，需要回归验证说明"
```

When the user only wants a preview, switch to `--dry-run`:

```bash
scripts/auto-commit.sh \
  --dry-run \
  --intent "修复登录重试导致死循环并补充错误提示" \
  --context "用户反馈线上频繁超时，需要优先稳定性并说明回归验证范围"
```

When the user explicitly wants a local-only commit, add `--no-push`:

```bash
scripts/auto-commit.sh \
  --no-push \
  --intent "修复登录重试导致死循环并补充错误提示" \
  --context "线上稳定性优先，需要回归验证说明"
```

## Open-source description standard

Commit description must explain intent and behavior impact, not just file lists.

Required structure:

```text
Why:
- one bullet for change motivation/type context
- one bullet that directly references user intent (if provided)
- one bullet for conversation context/constraints (if provided)

What changed:
- action + file/path + concrete change point
- action + file/path + concrete change point

Impact:
- scope summary across changed file types
- diff-level verification summary
- explicit compatibility note
```

### Writing rules

- Use concrete verbs: `add`, `update`, `remove`, `rename`.
- Mention meaningful paths and impacted modules/components.
- Tie statements to observable diff evidence.
- Prefer behavior-level wording over implementation trivia.
- Include compatibility/risk signal in `Impact`.
- Keep body scoped to this commit only; avoid roadmap text.
- If auto body is too generic, provide explicit `--body`.

### Scope hints

- Source changes: describe behavior/API impact.
- Dependency/build changes: describe compatibility, tooling, or release impact.
- Test changes: describe what regression risk is covered.
- Context-heavy changes: describe why the conversation constraints matter for maintainers/reviewers.

## Default behavior

- If the user asks to create a commit, treat that as authorization to inspect staged changes and run the commit end-to-end.
- If no `--type` is provided, the script infers from `--intent + --context` first, then falls back to changed-file heuristics.
- If no `--subject` is provided, the script generates one from intent/context (when available), otherwise from staged files.
- If no `--body` is provided, the script auto-generates `Why/What changed/Impact` and includes intent/context when provided.
- After commit, the script pushes by default. Use `--no-push` when the user explicitly wants to keep it local.

## Typical prompts that should trigger this skill

- "帮我自动提交这次改动"
- "帮我生成 commit message 并提交"
- "按我的需求和代码改动生成开源风格 commit + description"
- "用 conventional commits 自动提交"
