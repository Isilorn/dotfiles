# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

# Homebrew (macOS arm64 → /opt/homebrew, Linux → /home/linuxbrew/.linuxbrew)
if [[ -z "$HOMEBREW_PREFIX" ]]; then
  if [[ -d /opt/homebrew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
fi

# ---------------------------------------------------------------------------
# zinit
# ---------------------------------------------------------------------------
ZINIT_HOME="${ZINIT_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git}"

if [[ ! -d "$ZINIT_HOME" ]]; then
  if [[ -n "$HOMEBREW_PREFIX" && -d "$HOMEBREW_PREFIX/opt/zinit" ]]; then
    # Homebrew-installed zinit
    source "$HOMEBREW_PREFIX/opt/zinit/zinit.zsh"
  fi
else
  source "$ZINIT_HOME/zinit.zsh"
fi

# Plugins
zinit load sunlei/zsh-ssh                       # smarter ssh completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit snippet OMZP::git                         # git aliases from Oh-My-Zsh

# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh
elif command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)"
fi

export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border"
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ll='ls -lAh'
alias la='ls -A'

if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --group-directories-first --git'
  alias lt='eza --tree --level=2'
fi

if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

# ---------------------------------------------------------------------------
# Machine-local overrides (~/.zshrc.local is gitignored, never committed)
# ---------------------------------------------------------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
