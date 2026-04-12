# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Personal dotfiles managed with GNU Stow. Target machines:
- **Mac** — arm64, macOS, Homebrew at `/opt/homebrew`
- **Bluemoon** — Ubuntu 24.04 devbox, Homebrew optionally at `/home/linuxbrew/.linuxbrew`

Stack: zsh (zinit), git + delta, tmux.

## Stow layout

Each subdirectory is a Stow package. Running `stow <package>` from this repo root creates symlinks in `$HOME`.

```
dotfiles/
├── git/      → ~/.gitconfig
├── zsh/      → ~/.zshrc
├── tmux/     → ~/.tmux.conf
└── old_dotfiles/   (reference only, not stowed)
```

## Deploying

```bash
# From the dotfiles repo root:
stow git zsh tmux

# Unlink a package:
stow -D git
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
- **zinit** — plugins declared in `.zshrc`; zinit itself installed via Homebrew or its own installer.
- **tmux prefix** — changed to `Ctrl-a`; splits use `|` and `-`.
