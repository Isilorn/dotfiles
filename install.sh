#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
PACKAGES=(git zsh tmux starship claude)
[[ "$OS" == Darwin ]] && PACKAGES+=(wezterm)

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y-%m-%dT%H:%M:%S)"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
DRY_RUN=false
ROLLBACK=false
NO_PACKAGES=false
NO_STOW=false
VERIFY=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=true ;;
    --rollback)    ROLLBACK=true ;;
    --no-packages) NO_PACKAGES=true ;;
    --no-stow)     NO_STOW=true ;;
    --verify)      VERIFY=true ;;
    --help|-h)
      echo "Usage: $0 [--dry-run] [--rollback] [--no-packages] [--no-stow] [--verify]"
      echo ""
      echo "  --dry-run      Show what would be done, without modifying anything"
      echo "  --rollback     Remove symlinks, restore backed-up files, revert shell"
      echo "  --no-packages  Skip package installation"
      echo "  --no-stow      Skip symlinking dotfiles"
      echo "  --verify       Check the deployment for drift, change nothing"
      exit 0 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()    { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
success() { printf '\033[1;32m  ✔ %s\033[0m\n' "$*"; }
warn()    { printf '\033[1;33m  ⚠ %s\033[0m\n' "$*"; }
skip()    { printf '\033[2m  ↷ skip: %s\033[0m\n' "$*"; }
die()     { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

has() { command -v "$1" &>/dev/null; }

run() {
  if $DRY_RUN; then
    printf '  \033[2m[dry-run] %s\033[0m\n' "$*"
  else
    "$@"
  fi
}

srun() {
  if $DRY_RUN; then
    printf '  \033[2m[dry-run] sudo %s\033[0m\n' "$*"
  else
    sudo "$@"
  fi
}

# ---------------------------------------------------------------------------
# Backup — save existing files before stowing
#
# For each file in the package, compute its target path under $HOME.
# If it is a real file (not a stow symlink), move it to $BACKUP_DIR
# before stow replaces it with a symlink.
# ---------------------------------------------------------------------------
backup_package() {
  local pkg="$1"
  local pkg_dir="$DOTFILES_DIR/$pkg"
  local backed_up=0

  while IFS= read -r -d '' src; do
    local rel="${src#"$pkg_dir"/}"
    local target="$HOME/$rel"

    if [[ -e "$target" && ! -L "$target" ]]; then
      # Skip files that already live inside the dotfiles repo (reached via a
      # directory symlink created by stow on a previous run).
      local real_target
      real_target="$(realpath "$target" 2>/dev/null || echo "$target")"
      if [[ "$real_target" == "$DOTFILES_DIR"/* ]]; then
        continue
      fi
      local dest="$BACKUP_DIR/$rel"
      if $DRY_RUN; then
        printf '  \033[2m[dry-run] backup %s → %s\033[0m\n' "$target" "$dest"
      else
        mkdir -p "$(dirname "$dest")"
        mv "$target" "$dest"
        success "Backed up ~/$rel → $BACKUP_DIR/$rel"
      fi
      (( backed_up++ )) || true
    fi
  done < <(find "$pkg_dir" -type f -print0)

  return 0
}

# ---------------------------------------------------------------------------
# Restore — restore from the most recent backup
# ---------------------------------------------------------------------------
restore_backup() {
  local backup_root="$HOME/.dotfiles-backup"

  if [[ ! -d "$backup_root" ]] || [[ -z "$(ls -A "$backup_root" 2>/dev/null)" ]]; then
    warn "No backup found in ~/.dotfiles-backup/"
    return
  fi

  # Take the most recent backup
  local latest
  latest="$(ls -t "$backup_root" | head -1)"
  local backup_dir="$backup_root/$latest"

  info "Restauration depuis $backup_dir"

  while IFS= read -r -d '' file; do
    local rel="${file#"$backup_dir"/}"
    local target="$HOME/$rel"

    # Remove the stow symlink if present
    [[ -L "$target" ]] && run rm "$target"

    if $DRY_RUN; then
      printf '  \033[2m[dry-run] restore %s → %s\033[0m\n' "$file" "$target"
    else
      mkdir -p "$(dirname "$target")"
      mv "$file" "$target"
      success "Restored ~/$rel"
    fi
  done < <(find "$backup_dir" -type f -print0)

  # Remove the backup directory if now empty
  if ! $DRY_RUN; then
    find "$backup_dir" -type d -empty -delete 2>/dev/null || true
    success "Backup $latest consumed"
  fi
}

# ---------------------------------------------------------------------------
# Rollback
# ---------------------------------------------------------------------------
rollback() {
  info "Rollback dotfiles"

  # 1. Restaure les fichiers originaux depuis le backup
  restore_backup

  # 2. Unstow les packages restants (symlinks sans backup correspondant)
  if has stow; then
    for pkg in "${PACKAGES[@]}"; do
      if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
        if $DRY_RUN; then
          printf '  \033[2m[dry-run] stow -D %s\033[0m\n' "$pkg"
        else
          stow --dir="$DOTFILES_DIR" --target="$HOME" -D "$pkg" 2>/dev/null \
            && success "Unstowed $pkg" \
            || skip "$pkg was not stowed"
        fi
      fi
    done
  else
    warn "stow not found — symlinks not removed"
  fi

  # 3. Remove fd/bat compatibility symlinks (Linux)
  if [[ "$OS" == Linux ]]; then
    for link in fd bat; do
      local t="$HOME/.local/bin/$link"
      [[ -L "$t" ]] && run rm "$t" && success "Removed ~/.local/bin/$link"
    done
  fi

  # 4. Restore bash as default shell if we had switched to zsh
  local bash_path; bash_path="$(command -v bash || true)"
  if [[ -n "$bash_path" && "$SHELL" == "$(command -v zsh 2>/dev/null)" ]]; then
    warn "Current shell is zsh — reverting to bash"
    run chsh -s "$bash_path"
  fi

  echo ""
  warn "Not restored (manual action if needed):"
  warn "  - Installed packages (git, delta, starship, fzf, eza, bat…)"
  warn "  - zinit (~/.local/share/zinit)"
  warn "  - ~/.gitconfig.local (kept intentionally)"
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
      git git-delta starship stow zsh zinit fzf fd eza bat zoxide
    run brew install --quiet --cask wezterm
    success "Homebrew packages installed"

  elif [[ "$OS" == Linux ]]; then
    has apt-get || die "apt not found — only Ubuntu/Debian supported on Linux"
    srun apt-get update -qq
    # starship is not in apt repos — installed separately below
    srun apt-get install -y --no-install-recommends \
      git git-delta stow zsh fzf fd-find eza bat curl zoxide
    success "apt packages installed"

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
# starship (Linux only — macOS gets it via Homebrew)
# Not in apt repos — installed via the official script
# ---------------------------------------------------------------------------
install_starship() {
  if [[ "$OS" == Linux ]]; then
    if has starship; then
      skip "starship already installed ($(starship --version))"
    else
      info "Installing starship (official script)"
      run sh -c "$(curl -sS https://starship.rs/install.sh)" -- --yes
      success "starship installed"
    fi
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
# Stow packages — backup first, then stow
# ---------------------------------------------------------------------------
stow_packages() {
  info "Stowing dotfiles"
  $DRY_RUN || has stow || die "stow not found — run package install first"

  for pkg in "${PACKAGES[@]}"; do
    if [[ -d "$DOTFILES_DIR/$pkg" ]]; then
      backup_package "$pkg"
      run stow --dir="$DOTFILES_DIR" --target="$HOME" --no-folding --restow "$pkg"
      success "$pkg stowed"
    else
      warn "$pkg directory not found, skipping"
    fi
  done

  if [[ -d "$BACKUP_DIR" ]]; then
    info "Original files backed up to: $BACKUP_DIR"
  fi
}

# ---------------------------------------------------------------------------
# ~/.gitconfig.local scaffold — created once, never overwritten
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
    warn "Fill in ~/.gitconfig.local with your name and email"
  else
    skip "~/.gitconfig.local already exists"
  fi
}

# ---------------------------------------------------------------------------
# Set default shell to zsh
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
    success "Default shell set to zsh (open a new session to apply)"
  else
    skip "zsh is already the default shell"
  fi
}

# ---------------------------------------------------------------------------
# zinit plugins — pre-download on first login
# Starts a hidden interactive zsh shell to trigger zinit
# ---------------------------------------------------------------------------
install_zinit_plugins() {
  info "Pre-installing zinit plugins"
  if $DRY_RUN; then
    printf '  \033[2m[dry-run] zsh -i -c exit\033[0m\n'
  else
    zsh -i -c exit 2>/dev/null || true
    success "Zinit plugins installed"
  fi
}

# ---------------------------------------------------------------------------
# Verify — is the deployment still intact? (read-only)
#
# Catches the two drifts that went unnoticed for months:
#   1. a stowed file that became a real file — edited in place, cut off from git
#   2. a deployment lagging behind the published source
# Plus the stow folding hazard: a directory that became a symlink, so anything
# written into it later lands inside the repo.
#
# Changes nothing (the git fetch only updates remote-tracking refs).
# Exits non-zero when something needs attention, so it can be scripted.
# ---------------------------------------------------------------------------
verify_deployment() {
  info "Verifying deployment — $DOTFILES_DIR"
  local issues=0 checked=0 pkg src rel target real d

  for pkg in "${PACKAGES[@]}"; do
    [[ -d "$DOTFILES_DIR/$pkg" ]] || continue

    # Directories that stow may have folded into a symlink
    while IFS= read -r -d '' d; do
      rel="${d#"$DOTFILES_DIR/$pkg"/}"
      target="$HOME/$rel"
      if [[ -L "$target" ]]; then
        warn "~/$rel is a DIRECTORY symlink (stow folding) — files written there land in the repo"
        (( issues++ )) || true
      fi
    done < <(find "$DOTFILES_DIR/$pkg" -mindepth 1 -type d -print0)

    # Every packaged file must be a symlink back to this repo
    while IFS= read -r -d '' src; do
      rel="${src#"$DOTFILES_DIR/$pkg"/}"
      target="$HOME/$rel"
      (( checked++ )) || true

      if [[ -L "$target" ]]; then
        real="$(realpath "$target" 2>/dev/null || echo '')"
        [[ "$real" == "$src" ]] && continue
        if [[ "$real" == "$DOTFILES_DIR"/* ]]; then
          warn "~/$rel links into the repo, but not to $pkg/$rel"
        else
          warn "~/$rel is a symlink pointing outside the repo → $real"
        fi
        (( issues++ )) || true
      elif [[ -e "$target" ]]; then
        if diff -q "$target" "$src" &>/dev/null; then
          warn "~/$rel is a REAL FILE, not a link (same content — re-stow to fix)"
        else
          printf '\033[1;31m  ✘ ~/%s is a REAL FILE and has DIVERGED from the repo\033[0m\n' "$rel"
          printf '\033[2m      save it before re-stowing:  diff %s %s\033[0m\n' "$src" "$target"
        fi
        (( issues++ )) || true
      else
        warn "~/$rel is not deployed (missing)"
        (( issues++ )) || true
      fi
    done < <(find "$DOTFILES_DIR/$pkg" -type f -print0)
  done

  # Is this deployment up to date with the published source?
  if git -C "$DOTFILES_DIR" rev-parse --git-dir &>/dev/null; then
    local upstream behind ahead dirty
    git -C "$DOTFILES_DIR" fetch --quiet 2>/dev/null \
      || warn "could not fetch (offline?) — freshness below may be stale"
    upstream="$(git -C "$DOTFILES_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
    if [[ -n "$upstream" ]]; then
      behind="$(git -C "$DOTFILES_DIR" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
      ahead="$(git -C "$DOTFILES_DIR" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
      if (( behind > 0 )); then
        warn "deployment is $behind commit(s) behind $upstream — run: git -C \"$DOTFILES_DIR\" pull && \"$DOTFILES_DIR/install.sh\""
        (( issues++ )) || true
      fi
      if (( ahead > 0 )); then
        warn "$ahead commit(s) here are not pushed — if this clone is the deployment, that work only exists here"
        (( issues++ )) || true
      fi
      (( behind == 0 && ahead == 0 )) && success "in sync with $upstream" || true
    fi
    dirty="$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null || true)"
    if [[ -n "$dirty" ]]; then
      warn "uncommitted changes in this clone — if it is the deployment, port them to the source before they are lost:"
      printf '%s\n' "$dirty" | sed 's/^/      /'
      (( issues++ )) || true
    fi
  fi

  echo ""
  if (( issues == 0 )); then
    success "$checked file(s) checked — deployment intact."
  else
    printf '\033[1;31m  ✘ %s issue(s) across %s file(s) checked.\033[0m\n' "$issues" "$checked"
    printf '\033[2m    Save anything that diverged, then re-run: %s\033[0m\n' "$DOTFILES_DIR/install.sh"
  fi
  return $(( issues > 0 ))
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

  if $VERIFY; then
    local rc=0
    verify_deployment || rc=$?   # || keeps set -e from cutting us off
    exit $rc
  fi

  if $ROLLBACK; then
    rollback
    exit 0
  fi

  $NO_PACKAGES || install_packages
  $NO_PACKAGES || install_starship
  install_zinit
  $NO_STOW     || stow_packages
  setup_gitconfig_local
  set_default_shell
  install_zinit_plugins

  echo ""
  success "Done. Open a new shell to apply changes."
}

main "$@"
