简体中文 | [English](README_EN.md)

# commit-assistant

`commit-assistant` 是一个面向 Codex / Claude Code 的 Skill，配套 `scripts/auto-commit.sh`，用于根据已暂存 diff、用户意图与会话约束，生成高质量 Conventional Commit 与开源风格提交说明（`Why / What changed / Impact`）。

## 文档

- 页面文档（支持点击切换中英文）：[docs/index.html](docs/index.html)

## 安装到 Codex

根据 OpenAI Codex Skills 文档，推荐路径是 `.agents/skills`。

### 1. 用户级安装（全局可用）

```bash
mkdir -p ~/.agents/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git ~/.agents/skills/commit-assistant
```

### 2. 项目级安装（仅当前仓库可用）

在你的项目根目录执行：

```bash
mkdir -p .agents/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git .agents/skills/commit-assistant
```

### 3. 验证

- 在 Codex 中输入 `/skills` 查看是否已加载
- 显式调用：`$commit-assistant 帮我基于已暂存改动生成 commit，先 dry-run`
- 如果没有立即出现，重启 Codex

### 兼容说明

部分旧版或社区配置仍使用 `~/.codex/skills`。若你的环境按该路径加载技能，可将同一文件夹放到该目录。

## 安装到 Claude Code

根据 Claude Code Skills 文档，支持个人和项目两级目录：

### 1. 用户级安装（全局可用）

```bash
mkdir -p ~/.claude/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git ~/.claude/skills/commit-assistant
```

### 2. 项目级安装（仅当前项目可用）

在你的项目根目录执行：

```bash
mkdir -p .claude/skills
git clone git@github.com:chinazhenzhen/commit-assistant.git .claude/skills/commit-assistant
```

### 3. 验证

- 在 Claude Code 会话中输入：`/commit-assistant`
- 或直接用自然语言触发："帮我按已暂存改动自动提交"

## 使用示例

先预览：

```bash
scripts/auto-commit.sh --dry-run --no-push \
  --intent "修复登录死循环并补充错误提示" \
  --context "线上稳定性优先，需要回归验证说明"
```

确认后执行实际提交：

```bash
scripts/auto-commit.sh --no-push
```

## Skill 标准对齐

- `SKILL.md`：包含触发导向的 `name` 与 `description`
- `scripts/auto-commit.sh`：可执行、可复用
- `tests/*.sh`：覆盖描述质量、意图上下文与关键词映射
- `agents/openai.yaml`：提供 UI 元数据与默认提示词
