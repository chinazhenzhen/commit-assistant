[简体中文](README.md) | English

# commit-assistant

`commit-assistant` is a Skill for Codex / Claude Code with a companion script (`scripts/auto-commit.sh`).
It generates Conventional Commits and OSS-friendly commit bodies (`Why / What changed / Impact`) from staged diffs, user intent, and conversation context.

## Documentation

- Web-style docs with language switch: [docs/index.html](docs/index.html)

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
- Explicitly invoke: `$commit-assistant generate a commit from staged changes, dry-run first`
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

Preview first:

```bash
scripts/auto-commit.sh --dry-run --no-push \
  --intent "Fix retry loop and improve error feedback" \
  --context "Production stability first with clear regression notes"
```

Then run a real commit:

```bash
scripts/auto-commit.sh --no-push
```

## Standards Alignment

- `SKILL.md`: trigger-focused `name` and `description`
- `scripts/auto-commit.sh`: executable and reusable
- `tests/*.sh`: quality checks for body generation and context handling
- `agents/openai.yaml`: UI-facing metadata and default prompt
