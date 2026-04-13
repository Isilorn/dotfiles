#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
PACKAGES=(git zsh tmux starship)
[[ "$(uname -s)" == Darwin ]] && PACKAGES+=(wezterm)

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
DRY_RUN=false
ROLLBACK=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)  DRY_RUN=true ;;
    --rollback) ROLLBACK=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--rollback] [--no-packages] [--no-stow]"
      echo ""
      echo "  --dry-run    Show what would be done, without executing anything"
      echo "  --rollback   Remove symlinks and revert shell changes"
      echo "  --no-packages  Skip package installation"
      echo "  --no-stow      Skip symlinking dotfiles"
      exit 0 ;;
    --no-packages) NO_PACKAGES=true ;;
    --no-stow)     NO_STOW=true ;;
  esac
done

NO_PACKAGES=${NO_PACKAGES:-false}
NO_STOW=${NO_STOW:-false}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
success() { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
warn()    { printf '\033[1;33m  ⚠ %s\033[0m\n' "$*"; }
skip()    { printf '\033[2m  ↷ skip: %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

has() { command -v "$1" &>/dev/null; }

# Wraps any command: prints it in dry-run, executes it otherwise.
run() {
  if $DRY_RUN; then
    printf '  \033[2m[dry-run] %s\033[0m\n' "$*"
  else
    "$@"
  fi
}

# Like run() but prepends sudo.
srun() {
  if $DRY_RUN; then
    printf '  \033[2m[dry-run] sudo %s\033[0m\n' "$*"
  else
    sudo "$@"
  fi
}

# ---------------------------------------------------------------------------
# Rollback
# ---------------------------------------------------------------------------
rollback() {
  info "Rolling back dotfiles installation"

  # 1. Unstow all packages
  if has stow; then
    for pkg in "${PACKAGES[@]}"; do
      if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        run stow --dir="$DOTFILES_DIR" --target="$HOME" -D "$pkg" 2>/dev/null \
          && success "Unstowed $pkg" \
          || warn "$pkg was not stowed (skipping)"
      fi
    done
  else
    warn "stow not found — symlinks not removed"
  fi

  # 2. Remove fd/bat compatibility symlinks (Linux only)
  if [[ "$OS" == Linux ]]; then
    for link in fd bat; do
      local target="$HOME/.local/bin/$link"
      if [[ -L "$target" ]]; then
        run rm "$target" && success "Removed ~/.local/bin/$link"
      fi
    done
  fi

  # 3. Revert default shell to bash if it was changed to zsh
  local bash_path; bash_path="$(command -v bash || true)"
  if [[ -n "$bash_path" && "$SHELL" == "$(command -v zsh)" ]]; then
    warn "Default shell is zsh — reverting to bash"
    run chsh -s "$bash_path"
  fi

  # 4. Things we can't undo
  echo ""
  warn "Not removed (manual action required if desired):"
  warn "  - Installed packages (git, delta, starship, fzf, eza, bat…)"
  warn "  - zinit at \${XDG_DATA_HOME:-~/.local/share}/zinit"
  warn "  - ~/.gitconfig.local (may contain your identity — kept intentionally)"

  echo ""
  success "Rollback complete."
}

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
install_packages() {
  info "Installing packages"

  if [[ "$OS" == Darwin ]]; then
    has brew || die "Homebrew not found — install it first: https://brew.sh"
    run brew install --quiet \
      git git-delta starship stow zsh zinit fzf fd eza bat
    success "Homebrew packages installed"

  elif [[ "$OS" == Linux ]]; then
    has apt-get || die "apt not found — only Ubuntu/Debian supported on Linux"
    srun apt-get update -qq
    srun apt-get install -y --no-install-recommends \
      git git-delta starship stow zsh fzf fd-find eza bat curl
    success "apt packages installed"

    # fd and bat ship with different binary names on Ubuntu
    mkdir -p "$HOME/.local/bin"
    if [[ ! -e ~/.local/bin/fd ]] && has fdfind; then
      run ln -sf "$(command -v fdfind)" ~/.local/bin/fd
      success "Symlinked fdfind → ~/.local/bin/fd"
    fi
    if [[ ! -e ~/.local/bin/bat ]] && has batcat; then
      run ln -sf "$(command -v batcat)" ~/.local/bin/bat
      success "Symlinked batcat → ~/.local/bin/bat"
    fi
  else
    die "Unsupported OS: $OS"
  fi
}

# ---------------------------------------------------------------------------
# zinit (Linux only — macOS gets it via Homebrew)
# ---------------------------------------------------------------------------
install_zinit() {
  if [[ "$OS" == Linux ]]; then
    local zinit_home="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [[ ! -f "$zinit_home/zinit.zsh" ]]; then
      info "Installing zinit (standalone)"
      run git clone https://github.com/zdharma-continuum/zinit.git "$zinit_home"
      success "zinit installed"
    else
      skip "zinit already present"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Stow packages
# ---------------------------------------------------------------------------
stow_packages() {
  info "Stowing dotfiles"
  $DRY_RUN || has stow || die "stow not found — run package install first"

  for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
      run stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg"
      success "$pkg stowed"
    else
      warn "$pkg directory not found, skipping"
    fi
  done
}

# ---------------------------------------------------------------------------
# ~/.gitconfig.local scaffold
# ---------------------------------------------------------------------------
setup_gitconfig_local() {
  local local_cfg="$HOME/.gitconfig.local"
  if [[ ! -f "$local_cfg" ]]; then
    info "Creating ~/.gitconfig.local scaffold"
    if ! $DRY_RUN; then
      cat > "$local_cfg" <<'EOF'
# Machine-specific git identity — never committed to dotfiles
[user]
	name  = Your Name
	email = you@example.com
# Uncomment to enable commit signing:
# [user]
# 	signingkey = YOUR_KEY_ID
# [commit]
# 	gpgsign = true
EOF
    else
      printf '  \033[2m[dry-run] create ~/.gitconfig.local scaffold\033[0m\n'
    fi
    warn "Edit ~/.gitconfig.local to set your name and email"
  else
    skip "~/.gitconfig.local already exists"
  fi
}

# ---------------------------------------------------------------------------
# Default shell → zsh
# ---------------------------------------------------------------------------
set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" != "$zsh_path" ]]; then
    info "Setting default shell to zsh"
    if [[ "$OS" == Linux ]]; then
      grep -qxF "$zsh_path" /etc/shells \
        || { srun tee -a /etc/shells <<< "$zsh_path" >/dev/null; }
    fi
    run chsh -s "$zsh_path"
    success "Default shell set to zsh (restart your session)"
  else
    skip "zsh is already the default shell"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo ""
  if $DRY_RUN; then
    printf '\033[1m  Dotfiles installer — %s/%s  \033[33m[DRY RUN — nothing will be modified]\033[0m\n' "$OS" "$(uname -m)"
  else
    printf '\033[1m  Dotfiles installer — %s/%s\033[0m\n' "$OS" "$(uname -m)"
  fi
  echo ""

  if $ROLLBACK; then
    rollback
    exit 0
  fi

  $NO_PACKAGES || install_packages
  install_zinit
  $NO_STOW     || stow_packages
  setup_gitconfig_local
  set_default_shell

  echo ""
  success "Done. Open a new shell to apply changes."
}

main "$@"
