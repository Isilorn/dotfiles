#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
success() { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
warn()    { printf '\033[1;33m  ⚠ %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

has() { command -v "$1" &>/dev/null; }

# ---------------------------------------------------------------------------
# Package installation
# ---------------------------------------------------------------------------
install_packages() {
  info "Installing packages"

  if [[ "$OS" == Darwin ]]; then
    has brew || die "Homebrew not found — install it first: https://brew.sh"
    brew install --quiet \
      git \
      git-delta \
      starship \
      stow \
      zsh \
      zinit \
      fzf \
      fd \
      eza \
      bat
    success "Homebrew packages installed"

  elif [[ "$OS" == Linux ]]; then
    has apt-get || die "apt not found — only Ubuntu/Debian supported on Linux"
    sudo apt-get update -qq
    sudo apt-get install -y --no-install-recommends \
      git \
      git-delta \
      starship \
      stow \
      zsh \
      fzf \
      fd-find \
      eza \
      bat \
      curl
    success "apt packages installed"

    # fd and bat ship with different binary names on Ubuntu
    [[ ! -e ~/.local/bin/fd  ]] && { mkdir -p ~/.local/bin; ln -sf "$(command -v fdfind)" ~/.local/bin/fd; }
    [[ ! -e ~/.local/bin/bat ]] && { mkdir -p ~/.local/bin; ln -sf "$(command -v batcat)" ~/.local/bin/bat; }
  else
    die "Unsupported OS: $OS"
  fi
}

# ---------------------------------------------------------------------------
# zinit (Linux only — macOS gets it via Homebrew above)
# ---------------------------------------------------------------------------
install_zinit() {
  if [[ "$OS" == Linux ]]; then
    ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
    if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
      info "Installing zinit (standalone)"
      git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
      success "zinit installed at $ZINIT_HOME"
    else
      success "zinit already present"
    fi
  fi
}

# ---------------------------------------------------------------------------
# Stow packages
# ---------------------------------------------------------------------------
stow_packages() {
  info "Stowing dotfiles"
  has stow || die "stow not found — run package install first"

  local packages=(git zsh tmux starship)
  for pkg in "${packages[@]}"; do
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
      stow --dir="$DOTFILES_DIR" --target="$HOME" --restow "$pkg"
      success "$pkg stowed"
    else
      warn "$pkg directory not found, skipping"
    fi
  done
}

# ---------------------------------------------------------------------------
# ~/.gitconfig.local scaffold (machine-specific identity)
# ---------------------------------------------------------------------------
setup_gitconfig_local() {
  local local_cfg="$HOME/.gitconfig.local"
  if [[ ! -f "$local_cfg" ]]; then
    info "Creating ~/.gitconfig.local scaffold"
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
    warn "Edit ~/.gitconfig.local to set your name and email"
  else
    success "~/.gitconfig.local already exists"
  fi
}

# ---------------------------------------------------------------------------
# Default shell → zsh
# ---------------------------------------------------------------------------
set_default_shell() {
  local zsh_path
  zsh_path="$(command -v zsh)"
  if [[ "$SHELL" != "$zsh_path" ]]; then
    info "Setting default shell to zsh ($zsh_path)"
    if [[ "$OS" == Linux ]]; then
      # Add to /etc/shells if not present
      grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$zsh_path"
    success "Default shell set to zsh (restart your session)"
  else
    success "zsh is already the default shell"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  local skip_packages=false
  local skip_stow=false

  for arg in "$@"; do
    case "$arg" in
      --no-packages) skip_packages=true ;;
      --no-stow)     skip_stow=true ;;
      --help|-h)
        echo "Usage: $0 [--no-packages] [--no-stow]"
        echo "  --no-packages  Skip package installation"
        echo "  --no-stow      Skip symlinking dotfiles"
        exit 0 ;;
    esac
  done

  echo ""
  printf '\033[1m  Dotfiles installer — %s/%s\033[0m\n' "$OS" "$(uname -m)"
  echo ""

  $skip_packages || install_packages
  install_zinit
  $skip_stow     || stow_packages
  setup_gitconfig_local
  set_default_shell

  echo ""
  success "Done. Open a new shell to apply changes."
}

main "$@"
