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
    # fzf apt (Ubuntu) — too old for --zsh flag
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

# Listing — eza if available, fallback to standard ls
if command -v eza &>/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -lah --group-directories-first --git'
  alias lt='eza --tree --level=2'
fi

# Pager — bat if available
if command -v bat &>/dev/null; then
  alias cat='bat --style=plain --paging=never'
fi

# Tree with colors
if command -v tree &>/dev/null; then
  alias tree='tree -C'
fi

# System monitor — btop > htop > top
if command -v btop &>/dev/null; then
  alias top='btop'
elif command -v htop &>/dev/null; then
  alias top='htop'
fi

# Disk usage — sizes of items in current directory
if command -v ncdu &>/dev/null; then
  alias ncdu='ncdu --color dark -rr'   # -rr: no accidental deletion
fi
alias duh='du -sh -- * | sort -h'

# JSON — jq with colors
if command -v jq &>/dev/null; then
  alias jq='jq -C'
fi

# Network
if command -v ss &>/dev/null; then
  alias ports='ss -tlnp'
else
  alias ports='lsof -iTCP -sTCP:LISTEN -n -P'
fi
alias myip='curl -s ifconfig.me'       # public IP

# Python — Ubuntu exposes python3 but not python
if command -v python3 &>/dev/null && ! command -v python &>/dev/null; then
  alias python='python3'
fi
if command -v pip3 &>/dev/null && ! command -v pip &>/dev/null; then
  alias pip='pip3'
fi

# ---------------------------------------------------------------------------
# Unified title — Tmux + WezTerm
#   precmd  → "ssh user@host: path"  (at prompt)
#   preexec → "command path"         (while running)
#
# _set_titles sends:
#   \ek...\e\\ → renames the tmux window (#W)
#   \e]0;...\a → OSC 0 for WezTerm (title bar / tab)
# tmux then propagates #W to WezTerm via set-titles-string "#W"
# ---------------------------------------------------------------------------
autoload -Uz add-zsh-hook

_set_titles() {
  local title="$1"
  [[ -n "$TMUX" ]] && printf '\ek%s\e\\' "$title"
  printf '\e]0;%s\a' "$title"
}

_title_precmd() {
  local prefix="${SSH_TTY:+ssh }"
  _set_titles "${prefix}${USER}@${HOST%%.*}: ${PWD/#$HOME/~}"
}

_title_preexec() {
  local cmd=("${(z)1}")
  _set_titles "${cmd[1]} ${PWD/#$HOME/~}"
}

add-zsh-hook precmd  _title_precmd
add-zsh-hook preexec _title_preexec

# ---------------------------------------------------------------------------
# Terminal detection — WezTerm over SSH
# TERM=wezterm is negotiated by WezTerm automatically; TERM_PROGRAM is set
# locally via set_environment_variables but is not forwarded by SSH by default.
# ---------------------------------------------------------------------------
if [[ -n "$SSH_TTY" && "$TERM" == wezterm ]]; then
  [[ -z "$TERM_PROGRAM" ]] && export TERM_PROGRAM="WezTerm"
  [[ -z "$COLORTERM"    ]] && export COLORTERM="truecolor"
fi

# ---------------------------------------------------------------------------
# Auto-attach tmux — ask on login if a session is available
# ---------------------------------------------------------------------------
if [[ -z "$TMUX" ]] && command -v tmux &>/dev/null; then
  sessions="$(tmux list-sessions 2>/dev/null)"
  if [[ -n "$sessions" ]]; then
    echo "$sessions"
    read -q "?Attach to tmux session? [y/n] " && tmux attach
    echo
  fi
  unset sessions
fi

# ---------------------------------------------------------------------------
# Prompt — starship
# ---------------------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# Machine-local overrides (~/.zshrc.local is gitignored, never committed)
# ---------------------------------------------------------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
