# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

# Homebrew — macOS only (arm64: /opt/homebrew)
if [[ "$OSTYPE" == darwin* && -z "$HOMEBREW_PREFIX" ]]; then
  [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
# zinit
#   macOS  : installed via Homebrew
#   Linux  : standalone install at $ZINIT_HOME (auto-bootstrapped if absent)
# ---------------------------------------------------------------------------
if [[ -n "$HOMEBREW_PREFIX" && -f "$HOMEBREW_PREFIX/opt/zinit/zinit.zsh" ]]; then
  source "$HOMEBREW_PREFIX/opt/zinit/zinit.zsh"
else
  ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
  if [[ ! -f "$ZINIT_HOME/zinit.zsh" ]]; then
    print -P "%F{33}Bootstrapping zinit...%f"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  fi
  source "$ZINIT_HOME/zinit.zsh"
fi

# Plugins
zinit load  sunlei/zsh-ssh                  # smarter ssh host completions
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit snippet OMZP::git                     # git aliases from Oh-My-Zsh

# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------
if [[ -f ~/.fzf.zsh ]]; then
  source ~/.fzf.zsh                         # macOS (Homebrew/git install)
elif command -v fzf &>/dev/null; then
  _fzf_init="$(fzf --zsh 2>/dev/null)"
  if [[ -n "$_fzf_init" ]]; then
    eval "$_fzf_init"                       # fzf >= 0.48
  else
    # fzf apt (Ubuntu) — version trop ancienne pour --zsh
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] \
      && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] \
      && source /usr/share/doc/fzf/examples/completion.zsh
  fi
  unset _fzf_init
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

# Listing — eza si dispo, sinon ls standard
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --group-directories-first --git'
  alias lt='eza --tree --level=2'
fi

# Pager — bat si dispo
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'
fi

# Tree avec couleurs
if command -v tree &>/dev/null; then
  alias tree='tree -C'
fi

# Moniteur système — btop > htop > top
if command -v btop &>/dev/null; then
  alias top='btop'
elif command -v htop &>/dev/null; then
  alias top='htop'
fi

# Disk usage
if command -v ncdu &>/dev/null; then
  alias ncdu='ncdu --color dark -rr'   # -rr : pas de suppression accidentelle
fi
alias duh='du -sh -- * | sort -h'      # taille des éléments du répertoire courant

# JSON — jq avec couleurs
if command -v jq &>/dev/null; then
  alias jq='jq -C'
fi

# Réseau
alias ports='ss -tlnp'                 # ports en écoute (TCP)
alias myip='curl -s ifconfig.me'       # IP publique

# Python — Ubuntu n'expose pas "python", seulement "python3"
if command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
  alias python='python3'
fi
if command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
  alias pip='pip3'
fi

# ---------------------------------------------------------------------------
# Terminal detection — WezTerm over SSH
# TERM=wezterm is negotiated by WezTerm automatically; TERM_PROGRAM is set
# locally via set_environment_variables but not forwarded by SSH by default.
# ---------------------------------------------------------------------------
if [[ -n "$SSH_TTY" && "$TERM" == wezterm ]]; then
  [[ -z "$TERM_PROGRAM" ]] && export TERM_PROGRAM="WezTerm"
  [[ -z "$COLORTERM"    ]] && export COLORTERM="truecolor"
fi

# ---------------------------------------------------------------------------
# Prompt — starship
# ---------------------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# Machine-local overrides (~/.zshrc.local is gitignored, never committed)
# ---------------------------------------------------------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
