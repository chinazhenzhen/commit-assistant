# commit-assistant

`commit-assistant` is a Codex skill + shell script for generating Conventional Commits with open-source style commit bodies (`Why / What changed / Impact`).

## Docs (ZH/EN toggle)

- Open [docs/index.html](docs/index.html)
- Click `中文` / `English` in the top-right switcher

If you publish this repo with GitHub Pages, the same page can be used as public documentation.

## Quick Start

1. Clone the repository.
2. Ensure `git` is installed and available in PATH.
3. Run:

```bash
scripts/auto-commit.sh --dry-run --no-push
```

## Install as Codex Skill

Copy this folder into your local skills directory (example):

```bash
mkdir -p ~/.codex/skills
cp -R commit-assistant ~/.codex/skills/
```

Then use prompts like:

- "帮我自动提交这次改动"
- "Generate a conventional commit from staged changes"

## Skill Standards Check

This repository is aligned with current practical skill expectations:

- `SKILL.md` with trigger-focused `name` + `description` frontmatter
- executable `scripts/auto-commit.sh` for deterministic behavior
- `tests/*.sh` for behavior validation
- `agents/openai.yaml` for UI-facing metadata and default prompt

## 中文简介

`commit-assistant` 是一个 Codex skill，配套 `scripts/auto-commit.sh`，用于基于已暂存改动自动生成规范化提交信息，并输出开源风格提交说明（`Why / What changed / Impact`）。

- 双语文档入口：`docs/index.html`（右上角一键切换中英文）
- 适用场景：你希望让提交信息同时反映用户意图、会话约束和实际 diff
