# dotfiles

Personal dotfiles for **Mac (arm64)** and **Bluemoon (Ubuntu 24.04)**, managed with [GNU Stow](https://www.gnu.org/software/stow/).

Stack : `zsh` · `zinit` · `git` + `delta` · `tmux` · `starship` · `wezterm`

## Structure

| Package | Symlink cible | Machines |
|---|---|---|
| `git/` | `~/.gitconfig` | toutes |
| `zsh/` | `~/.zshrc` | toutes |
| `tmux/` | `~/.tmux.conf` | toutes |
| `starship/` | `~/.config/starship.toml` | toutes |
| `wezterm/` | `~/.config/wezterm/wezterm.lua` | macOS seulement |

## Installation

```bash
git clone git@github.com:Isilorn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Le script :
1. Installe les dépendances (Homebrew sur macOS, apt sur Ubuntu)
2. **Sauvegarde** les fichiers existants avant de les remplacer
3. Stow les packages (crée les symlinks dans `$HOME`)
4. Configure zsh comme shell par défaut

### Options

```bash
./install.sh --dry-run      # aperçu complet sans rien modifier
./install.sh --rollback     # restaure les fichiers originaux et supprime les symlinks
./install.sh --no-packages  # stow uniquement, sans installer de packages
./install.sh --no-stow      # packages uniquement, sans stower
```

### Backup automatique

Si des fichiers existent déjà (`~/.zshrc`, `~/.gitconfig`, etc.), `install.sh` les déplace dans `~/.dotfiles-backup/<timestamp>/` avant de stower. Plusieurs installations successives créent chacune leur propre entrée horodatée.

`--rollback` restaure automatiquement depuis le backup le plus récent.

## Fichiers locaux (jamais commités)

| Fichier | Contenu |
|---|---|
| `~/.gitconfig.local` | `user.name`, `user.email`, GPG signing |
| `~/.zshrc.local` | Variables d'environnement, PATH et alias propres à la machine |

`~/.gitconfig` inclut `~/.gitconfig.local` via `[include]`.  
`~/.zshrc` source `~/.zshrc.local` s'il existe.

Un scaffold vide de `~/.gitconfig.local` est créé automatiquement par `install.sh`.

## Aliases

Tous les aliases sont conditionnels — ils ne sont définis que si le binaire est présent sur la machine.

| Alias | Remplace / Commande | Package requis |
|---|---|---|
| `ls` / `ll` / `lt` | eza avec options | `eza` |
| `cat` | `bat --paging=never` | `bat` |
| `tree` | `tree -C` (couleurs) | `tree` |
| `top` | `btop` → `htop` → `top` (fallback) | `btop` ou `htop` |
| `ncdu` | `ncdu --color dark -rr` | `ncdu` |
| `jq` | `jq -C` (couleurs) | `jq` |
| `duh` | `du -sh * \| sort -h` | — |
| `ports` | `ss -tlnp` | — |
| `myip` | `curl -s ifconfig.me` | `curl` |
| `python` | `python3` | si `python` absent |
| `pip` | `pip3` | si `pip` absent |

`btop` n'est pas installé par `install.sh` — si présent sur la machine, l'alias `top` s'y branche automatiquement.

## WezTerm et SSH

La config WezTerm (`wezterm/`) n'est stowée que sur macOS. Sur les machines distantes, le `.zshrc` détecte automatiquement une connexion WezTerm via SSH (grâce à `$TERM=wezterm`) et pose `TERM_PROGRAM=WezTerm` et `COLORTERM=truecolor` sans nécessiter de configuration côté serveur.
