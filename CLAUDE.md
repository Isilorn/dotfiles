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
- **starship** — Homebrew on macOS, script officiel sur Linux (pas dans apt).
- **tmux prefix** — changed to `Ctrl-a`; splits use `|` and `-`.
- **Titres tmux/WezTerm** — hooks zsh `precmd`/`preexec` envoient OSC 0 + `\ek` (tmux rename).

## Comportement attendu de Claude

### Gestion de session

Proposer de fermer et rouvrir la session quand :
- Le contexte devient long et commence à dégrader la qualité des réponses
- Une tâche importante vient d'être complétée (bon point de sauvegarde)
- Une nouvelle thématique distincte démarre

Avant de fermer, toujours :
1. Mettre à jour la mémoire dans `.claude/projects/.../memory/` (fichiers `user_*.md`, `feedback_*.md`, `project_*.md`)
2. Mettre à jour `MEMORY.md` (index)
3. Résumer ce qui a été accompli et ce qui reste à faire, pour que la prochaine session puisse reprendre sans friction

### Utilisation des subagents

Les subagents sont configurés en Haiku. Proposer proactivement de déléguer à un subagent (`Agent` tool) dans les situations suivantes :
- **Collecte longue et prévisible** : récupérer des artefacts sur plusieurs hôtes distants, lire de nombreux fichiers de logs, exécuter des séquences SSH dont le résultat sera volumineux. Utiliser `general-purpose` ou `Explore`.
- **Exploration large du repo** : quand la tâche nécessite plus de 3-4 recherches Glob/Grep indépendantes. Utiliser `Explore`.
- **Recherche documentaire** : questions sur Claude Code, l'API Anthropic, les SDKs. Utiliser `claude-code-guide`.
- **Tâches parallélisables** : deux collectes indépendantes peuvent être lancées en parallèle dans deux subagents simultanés.

Ne pas déléguer à un subagent les analyses et diagnostics complexes qui nécessitent le contexte complet de la session — ces tâches restent dans le contexte principal.
