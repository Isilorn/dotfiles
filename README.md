# dotfiles

Personal dotfiles for **Mac (arm64)** and **Bluemoon (Ubuntu 24.04)**, managed with [GNU Stow](https://www.gnu.org/software/stow/).

Stack: `zsh` · `zinit` · `git` + `delta` · `tmux` · `starship` · `wezterm`

## Structure

| Package | Symlink target | Machines |
|---|---|---|
| `git/` | `~/.gitconfig` | all |
| `zsh/` | `~/.zshrc` | all |
| `tmux/` | `~/.tmux.conf` | all |
| `starship/` | `~/.config/starship.toml` | all |
| `wezterm/` | `~/.config/wezterm/wezterm.lua` | macOS only |

## Installation

### macOS (arm64)

1. Install [Homebrew](https://brew.sh) if not present:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Clone and run the install script:
   ```bash
   git clone https://github.com/Isilorn/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   ./install.sh
   ```

3. Fill in your local git identity:
   ```bash
   vim ~/.gitconfig.local
   ```

4. Open a new shell — zsh is now the default shell.

### Ubuntu / Bluemoon

```bash
git clone https://github.com/Isilorn/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
vim ~/.gitconfig.local
```

Open a new shell.

### Updating

To apply new configs on an already-configured machine:

```bash
cd ~/.dotfiles
git pull
./install.sh --no-packages   # restow only, no apt/brew reinstall
```

If new packages were added to `install.sh` since the last install, run without `--no-packages`:

```bash
./install.sh
```

### Script options

```bash
./install.sh --dry-run      # preview everything without modifying anything
./install.sh --rollback     # restore original files and remove symlinks
./install.sh --no-packages  # stow only, skip package installation
./install.sh --no-stow      # packages only, skip symlinking
```

### Automatic backup

If files already exist (`~/.zshrc`, `~/.gitconfig`, etc.), `install.sh` moves them to `~/.dotfiles-backup/<timestamp>/` before stowing. Multiple installs each create their own timestamped entry.

`--rollback` automatically restores from the most recent backup.

## Local files (never committed)

### `~/.gitconfig.local`

Created automatically by `install.sh` as an empty scaffold. Contains everything machine- or identity-specific — never committed.

```ini
[user]
    name  = Your Name
    email = your@email.com

# GPG commit signing (optional)
# [user]
#     signingkey = ABCDEF1234567890
# [commit]
#     gpgsign = true

# Machine-specific aliases (optional)
# [alias]
#     work = "!cd ~/work && code ."
```

`~/.gitconfig` includes this file at the end via `[include]`, allowing it to override any global setting.

### `~/.zshrc.local`

Sourced at the end of `.zshrc` if present. For anything that should not be shared across machines:

```zsh
# Example — environment variables, PATH additions, machine-specific aliases
export WORK_DIR=~/clients
export KUBECONFIG=~/.kube/config-prod
alias vpn='sudo openconnect vpn.example.com'
```

## Aliases

All aliases are conditional — they are only defined if the binary is present on the machine.

| Alias | Replaces / Command | Required package |
|---|---|---|
| `ls` / `ll` / `lt` | eza with options | `eza` |
| `cat` | `bat --style=plain --paging=never` | `bat` |
| `tree` | `tree -C` (colors) | `tree` |
| `top` | `btop` → `htop` → `top` (fallback) | `btop` or `htop` |
| `ncdu` | `ncdu --color dark -rr` | `ncdu` |
| `jq` | `jq -C` (colors) | `jq` |
| `duh` | `du -sh * \| sort -h` | — |
| `ports` | `ss -tlnp` | — |
| `myip` | `curl -s ifconfig.me` | `curl` |
| `python` | `python3` | if `python` absent |
| `pip` | `pip3` | if `pip` absent |

`btop` is not installed by `install.sh` — if present on the machine, the `top` alias will automatically use it.

## WezTerm and SSH

The WezTerm config (`wezterm/`) is only stowed on macOS. On remote machines, `.zshrc` automatically detects a WezTerm connection over SSH (via `$TERM=wezterm`) and sets `TERM_PROGRAM=WezTerm` and `COLORTERM=truecolor` without requiring any server-side configuration.
