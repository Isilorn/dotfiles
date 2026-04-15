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

`~/.gitconfig` includes `~/.gitconfig.local` via `[include]`. `.zshrc` sources `~/.zshrc.local` if present.

## Key design decisions

- **No user identity in `.gitconfig`** — always machine-local via `~/.gitconfig.local`.
- **Homebrew detection** — `.zshrc` auto-detects Homebrew prefix; no hardcoded paths.
- **zinit** — Homebrew on macOS, standalone bootstrap on Linux.
- **starship** — Homebrew on macOS, official install script on Linux (not in apt).
- **tmux prefix** — changed to `Ctrl-a`; splits use `|` and `-`.
- **tmux/WezTerm titles** — zsh `precmd`/`preexec` hooks emit OSC 0 + `\ek` (tmux rename).
- **tmux auto-attach** — `.zshrc` asks at login if a session exists (y/n prompt).

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

Subagents are configured as Haiku. Proactively suggest delegating to a subagent (`Agent` tool) in these situations:
- **Long, predictable data collection**: fetching artifacts from multiple remote hosts, reading many log files, running SSH sequences with large output. Use `general-purpose` or `Explore`.
- **Broad repo exploration**: when the task requires more than 3-4 independent Glob/Grep searches. Use `Explore`.
- **Documentation research**: questions about Claude Code, the Anthropic API, SDKs. Use `claude-code-guide`.
- **Parallelizable tasks**: two independent collections can be launched in parallel in two simultaneous subagents.

Do not delegate complex analyses and diagnostics that require the full session context — those stay in the main context.
