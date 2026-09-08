# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal dotfiles managed with GNU Stow. Target machines:
- **Mac** — arm64, macOS, Homebrew at `/opt/homebrew`
- **Bluemoon** — Ubuntu 24.04 devbox, no Homebrew

Stack: zsh (zinit), git + delta, tmux, starship, wezterm (macOS only).

## Stow layout

Each subdirectory is a Stow package. Running `stow <package>` from this repo root creates symlinks in `$HOME`.

```
dotfiles/
├── git/      → ~/.gitconfig
├── zsh/      → ~/.zshrc
├── tmux/     → ~/.tmux.conf
├── starship/ → ~/.config/starship.toml
├── claude/   → ~/.claude/{settings.json,keybindings.json,statusline-command.sh,hooks/,agents/}
└── wezterm/  → ~/.config/wezterm/wezterm.lua  (macOS only)
```

## Deploying

```bash
# Full install (packages + stow):
./install.sh

# Stow only (already configured machine):
./install.sh --no-packages

# Preview without modifying:
./install.sh --dry-run

# Undo:
./install.sh --rollback
```

## Machine-local files (never committed)

| File | Purpose |
|---|---|
| `~/.gitconfig.local` | `user.name`, `user.email`, GPG signing, machine aliases |
| `~/.zshrc.local` | Machine-specific env vars, PATH additions, aliases |
| `~/.claude/settings.local.json` | Optional Claude Code overrides (extra `additionalDirectories`, env, hooks) |

`~/.gitconfig` includes `~/.gitconfig.local` via `[include]`. `.zshrc` sources `~/.zshrc.local` if present.

## Key design decisions

- **No user identity in `.gitconfig`** — always machine-local via `~/.gitconfig.local`.
- **Homebrew detection** — `.zshrc` auto-detects Homebrew prefix; no hardcoded paths.
- **zinit** — Homebrew on macOS, standalone bootstrap on Linux.
- **starship** — Homebrew on macOS, official install script on Linux (not in apt).
- **tmux prefix** — changed to `Ctrl-a`; splits use `|` and `-`.
- **tmux/WezTerm titles** — zsh `precmd`/`preexec` hooks emit OSC 0 + `\ek` (tmux rename).
- **tmux auto-attach** — `.zshrc` asks at login if a session exists (y/n prompt).
- **Claude Code uses `bypassPermissions`** — `settings.json` opts in to auto-approval globally; per-machine extras (e.g. extra `additionalDirectories`) go in `~/.claude/settings.local.json`.

## Language convention

Everything in this repo is written in **English** — comments, runtime messages, docs — because
the repository is public.

**Two deliberate exceptions, in `claude/`. Do not "fix" them:**

- **`claude/.claude/agents/*.md`** — the `description:` field of an agent is what Claude matches
  a task against to decide whether to invoke it. These descriptions are written in French because
  the user works in French, and their trigger phrases (« résume-moi ces artefacts », « vérifie ce
  rapport ») are the literal strings being matched. Translating them would silently stop the
  agents from ever triggering: the file would still look correct, and nothing would report an
  error. Same for their `name:` fields, which are referenced by the descriptions.
- **`claude/.claude/statusline-command.sh` and `hooks/context-alert.sh`** — their header comments
  and the alert strings they print are French, deliberately: they are read by the user, on screen,
  mid-session. The surrounding code stays English.

The rule of thumb: English everywhere, except where the French text **is the mechanism** rather
than a description of it.

## Expected Claude behavior

### Session management

Suggest closing and reopening the session when:
- The context becomes long and starts to degrade response quality
- An important task has just been completed (good save point)
- A distinct new topic begins

Before closing, always:
1. Update memory files in `.claude/projects/.../memory/` (`user_*.md`, `feedback_*.md`, `project_*.md`)
2. Update `MEMORY.md` (index)
3. Summarize what was done and what remains, so the next session can resume without friction

### Subagent usage

`settings.json` sets `CLAUDE_CODE_SUBAGENT_MODEL`, but since Claude Code v2.1.251 an agent's own
`model:` field **takes precedence** over that variable — the variable is only a floor for agents
that declare nothing (including the built-in `Plan` and `general-purpose`).

This repo ships four agents in `claude/.claude/agents/`. Their model tracks how **verifiable**
their output is: an extraction run against a written instruction can be re-checked line by line,
a judgement cannot, and a verifier weaker than what it verifies verifies nothing.

| Agent | Model | Shape of task |
|---|---|---|
| `digesteur` | haiku | read a large volume, return a short synthesis |
| `extracteur` | haiku | written instruction → structured output |
| `analyste` | sonnet | judgement on a self-contained piece |
| `verificateur` | opus | check a text against its sources |

Their `tools:` allowlist matters more than the model: an instruction written in prose can be
ignored, a tool that is not in the list does not exist for the agent.

Proactively suggest delegating to a subagent (`Agent` tool) in these situations:
- **Long, predictable data collection**: fetching artifacts from multiple remote hosts, reading many log files, running SSH sequences with large output. Use `general-purpose` or `Explore`.
- **Broad repo exploration**: when the task requires more than 3-4 independent Glob/Grep searches. Use `Explore`.
- **Documentation research**: questions about Claude Code, the Anthropic API, SDKs. Use `claude-code-guide`.
- **Parallelizable tasks**: two independent collections can be launched in parallel in two simultaneous subagents.

Do not delegate complex analyses and diagnostics that require the full session context — those stay in the main context.
