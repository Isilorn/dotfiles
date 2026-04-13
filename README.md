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

### macOS (arm64)

1. Installer [Homebrew](https://brew.sh) si absent :
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Cloner et lancer le script :
   ```bash
   git clone https://github.com/Isilorn/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ./install.sh
   ```

3. Renseigner l'identité git locale :
   ```bash
   vim ~/.gitconfig.local
   ```

4. Ouvrir un nouveau shell — zsh est maintenant le shell par défaut.

### Ubuntu / Bluemoon

```bash
git clone https://github.com/Isilorn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
vim ~/.gitconfig.local
```

Ouvrir un nouveau shell.

### Mise à jour

Pour appliquer de nouvelles configs sur une machine déjà installée :

```bash
cd ~/.dotfiles
git pull
./install.sh --no-packages   # restow uniquement, pas de réinstallation apt/brew
```

Si de nouveaux packages ont été ajoutés à `install.sh` depuis la dernière installation, lancer sans `--no-packages` :

```bash
./install.sh
```

### Options du script

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

### `~/.gitconfig.local`

Créé automatiquement par `install.sh` avec un scaffold vide. Contient tout ce qui est spécifique à la machine ou à l'identité — jamais commité.

```ini
[user]
    name  = Isilorn
    email = 7522688+Isilorn@users.noreply.github.com

# Signature GPG des commits (optionnel)
# [user]
#     signingkey = ABCDEF1234567890
# [commit]
#     gpgsign = true

# Alias propres à cette machine (optionnel)
# [alias]
#     work = "!cd ~/work && code ."
```

`~/.gitconfig` inclut ce fichier en fin de configuration via `[include]`, ce qui lui permet d'écraser n'importe quel réglage global.

### `~/.zshrc.local`

Sourcé en fin de `.zshrc` s'il existe. Pour tout ce qui ne doit pas être partagé entre machines :

```zsh
# Exemple — variables d'environnement, PATH, alias spécifiques
export WORK_DIR=~/clients
export KUBECONFIG=~/.kube/config-prod
alias vpn='sudo openconnect vpn.example.com'
```

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
