[简体中文](README.md) | English

# commit-assistant

`commit-assistant` is a Skill for Codex / Claude Code with a companion script (`scripts/auto-commit.sh`).
It generates Conventional Commits and OSS-friendly commit bodies (`Why / What changed / Impact`) from staged diffs, user intent, and conversation context.

## Documentation Layout

- This repository uses `README.md` (Chinese) and `README_EN.md` (English) as the only documentation entry points.
- Language switching is implemented with cross-links at the top of both files, which is fully visible on GitHub.

## Install in Codex

Based on the latest Codex Skills docs, `.agents/skills` is the recommended location.

### 1. User-level install (global)

```bash
mkdir -p ~/.agents/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git ~/.agents/skills/commit-assistant
```

### 2. Project-level install (current repo only)

Run in your project root:

```bash
mkdir -p .agents/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git .agents/skills/commit-assistant
```

### 3. Verify

- Run `/skills` in Codex and confirm it is listed
- Explicitly invoke: `$commit-assistant generate and execute a commit directly from staged changes`
- Restart Codex if it does not show up immediately

### Compatibility note

Some legacy/community setups still load from `~/.codex/skills`. If your environment uses that layout, copy the same folder there.

## Install in Claude Code

Based on Claude Code Skills docs, both personal and project scopes are supported:

### 1. User-level install (global)

```bash
mkdir -p ~/.claude/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git ~/.claude/skills/commit-assistant
```

### 2. Project-level install (current project only)

Run in your project root:

```bash
mkdir -p .claude/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git .claude/skills/commit-assistant
```

### 3. Verify

- In Claude Code, run: `/commit-assistant`
- Or trigger naturally: "Generate a conventional commit from staged changes"

## Usage Example

Direct commit and push by default:

```bash
scripts/auto-commit.sh \
  --intent "Fix retry loop and improve error feedback" \
  --context "Production stability first with clear regression notes"
```

Use preview mode only when the user explicitly asks for it:

```bash
scripts/auto-commit.sh --dry-run \
  --intent "Fix retry loop and improve error feedback" \
  --context "Production stability first with clear regression notes"
```

Add `--no-push` only when the user explicitly wants a local-only commit:

```bash
scripts/auto-commit.sh --no-push \
  --intent "Fix retry loop and improve error feedback" \
  --context "Production stability first with clear regression notes"
```

## Standards Alignment

- `SKILL.md`: trigger-focused `name` and `description`
- `scripts/auto-commit.sh`: executable and reusable
- `tests/*.sh`: quality checks for body generation and context handling
- `agents/openai.yaml`: UI-facing metadata and default prompt
