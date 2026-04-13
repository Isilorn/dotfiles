# dotfiles

Personal dotfiles for **Mac (arm64)** and **Bluemoon (Ubuntu 24.04)**, managed with [GNU Stow](https://www.gnu.org/software/stow/).

Stack : `zsh` · `zinit` · `git` + `delta` · `tmux` · `starship`

## Structure

| Package | Symlink cible |
|---|---|
| `git/` | `~/.gitconfig` |
| `zsh/` | `~/.zshrc` |
| `tmux/` | `~/.tmux.conf` |
| `starship/` | `~/.config/starship.toml` |

## Installation

```bash
git clone git@github.com:Isilorn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Le script installe les dépendances (Homebrew sur macOS, apt sur Ubuntu), stow les packages et configure zsh comme shell par défaut.

```bash
./install.sh --dry-run    # aperçu sans modifier quoi que ce soit
./install.sh --rollback   # supprime les symlinks et rétablit le shell précédent
./install.sh --no-packages  # stow uniquement, sans installer de packages
```

## Fichiers locaux (jamais commités)

| Fichier | Contenu |
|---|---|
| `~/.gitconfig.local` | `user.name`, `user.email`, GPG signing |
| `~/.zshrc.local` | Variables d'environnement, PATH et alias propres à la machine |

`~/.gitconfig` inclut `~/.gitconfig.local` via `[include]`.  
`~/.zshrc` source `~/.zshrc.local` s'il existe.

Un scaffold vide de `~/.gitconfig.local` est créé automatiquement par `install.sh`.
