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
#   Load order matters for the completion stack:
#   - compdef-defining plugins (zsh-ssh) before compinit
#   - compinit before fzf-tab
#   - fzf-tab before the widget-wrapping plugins (autosuggestions, highlighting)
#   - zsh-syntax-highlighting strictly last
zinit load  sunlei/zsh-ssh                  # smarter ssh host completions
zinit snippet OMZP::git                     # git aliases from Oh-My-Zsh

autoload -Uz compinit && compinit           # init completion system (after compdefs above)

zinit light Aloxaf/fzf-tab                  # fzf-driven fuzzy UI for the Tab menu
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting   # MUST stay last

# ---------------------------------------------------------------------------
# Completion — the Tab menu (distinct from the grey history autosuggestion)
# ---------------------------------------------------------------------------
zstyle ':completion:*' matcher-list '' \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'                                           # exact → case-insensitive → partial → substring
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}    # colorise like ls
zstyle ':completion:*' group-name ''                     # group candidates by type
zstyle ':completion:*:descriptions' format '%F{yellow}%d%f'  # also enables fzf-tab group support
zstyle ':completion:*' menu no                           # disable zsh's menu → fzf-tab captures it
zstyle ':completion:*' use-cache on                      # cache slow completions
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# fzf-tab tuning
zstyle ':fzf-tab:*' switch-group '<' '>'                 # cycle candidate groups with < and >
zstyle ':completion:*:git-checkout:*' sort false         # keep git ref order, don't sort
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
  'eza -1 --color=always --group-directories-first "$realpath" 2>/dev/null || ls -1 "$realpath"'
[[ -n "$TMUX" ]] && zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup  # centered tmux popup in tmux
zstyle ':fzf-tab:*' popup-min-size 90 20                 # roomier popup (closer to the ssh-host fzf)

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

# Listing — keep `ls` as real ls (POSIX flags), add eza shortcuts on the side
if command -v eza &>/dev/null; then
  EZA_BASE='eza --group-directories-first --git'
  alias ll="$EZA_BASE -lah"                          # long, all, human
  alias lt="$EZA_BASE --tree --level=2"              # tree (2 levels)
  alias lltr="$EZA_BASE -lah --sort=oldest"          # ls -ltr equivalent (newest at bottom)
  alias llt="$EZA_BASE -lah --sort=newest"           # newest first
  alias lls="$EZA_BASE -lah --sort=size --reverse"   # largest first
  alias lla="$EZA_BASE -lah@ --extended"             # long + xattrs / extended attrs
  unset EZA_BASE
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
# _set_titles sends OSC 0 (\e]0;...\a) → the pane title (#T).
# tmux mirrors the pane title into the window name (#W) via
# automatic-rename-format "#{pane_title}", then forwards #W to WezTerm.
# This lets a long-running program's own OSC title (e.g. Claude's session
# name) flow all the way to #W and the WezTerm tab while it runs.
# ---------------------------------------------------------------------------
autoload -Uz add-zsh-hook

_set_titles() {
  printf '\e]0;%s\a' "$1"
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

# Wrapper claude — disable Claude's auto-generated "topic title" for fresh
# sessions (so the preexec title "claude ~/path" stays), but keep it enabled
# on resume/continue so a named session shows its name. The resume/continue
# flag is detected at any position; all args are passed through unchanged.
# Env is set per-invocation only (does not leak into the shell).
claude() {
  local keep_title=0 a
  for a in "$@"; do
    case $a in
      --resume|--resume=*|-r|--continue|--continue=*|-c) keep_title=1 ;;
    esac
  done
  if (( keep_title )); then
    command claude "$@"
  else
    CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1 command claude "$@"
  fi
}

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
# Tab key — always open the completion menu (fzf-tab). The grey history
# suggestion is accepted with the Right arrow, not Tab. Bound here, last, so it
# wins over fzf-tab's and fzf's own ^I bindings; falls back to fzf-completion
# then plain completion if fzf-tab is unavailable.
# ---------------------------------------------------------------------------
_tab_complete() {
  if (( $+widgets[fzf-tab-complete] )); then
    zle fzf-tab-complete                     # fuzzy fzf menu
  elif (( $+widgets[fzf-completion] )); then
    zle fzf-completion
  else
    zle expand-or-complete
  fi
}
zle -N _tab_complete
bindkey '^I' _tab_complete                    # ^I = Tab

# ---------------------------------------------------------------------------
# Prompt — starship
# ---------------------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# Machine-local overrides (~/.zshrc.local is gitignored, never committed)
# ---------------------------------------------------------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
