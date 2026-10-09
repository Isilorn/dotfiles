#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# stow-guard.sh — PreToolUse hook. Refuses agent writes to files this repo
# deploys, so that changes go to the SOURCE and the user redeploys.
#
# Why: on 2026-09-27 an agent working in another project ran `sed -i` on
# ~/.claude/settings.json. GNU sed -i without --follow-symlinks replaces a
# symlink with a regular file: the stowed link broke, the file drifted out of
# version control, and nothing noticed for 12 days. A written rule can be
# ignored; a refused tool call cannot. The rule that explains what to do
# instead is rules/claude-config.md, shipped alongside.
#
# Refused (exit 2, reason on stderr — the agent reads it):
#   - Edit / Write / MultiEdit on a deployed path: $HOME/<dotfile of a package>,
#     or a path inside the deployment clone when a separate source clone exists
#     (where the deployment clone is the only clone, it is where one works);
#   - Bash running an IN-PLACE editor (sed -i, perl -i) on such a path. Other
#     writers (cp, mv, >, tee) are deliberately not matched: the narrowest
#     heuristic was chosen, to avoid refusing commands that merely mention a path.
# Everything else is allowed: reads, the source clone, other files.
#
# Fails OPEN: any internal problem exits 0 (Claude Code also treats a missing
# script or a timeout as "allow"). Only a confirmed match exits 2.
# Escape hatch for the user, at launch only:  DOTFILES_GUARD=off claude
# (a variable set inside an agent's Bash command does not reach this process).
# Known blind spots: relative paths after a `cd` in the same command; paths fed
# through xargs or a script. Bench: tests/stow-guard-bench.sh.
# ─────────────────────────────────────────────────────────────────────────────
set -u
[ "${DOTFILES_GUARD:-on}" = off ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

input=$(cat) || exit 0
tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null) || exit 0
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$cwd" ] || cwd=$PWD

# The clone this script was stowed from = the deployment clone.
self=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null) || exit 0
DEPLOY=${self%/claude/.claude/hooks/*}
[ "$DEPLOY" != "$self" ] && [ -d "$DEPLOY/.git" ] || exit 0

SOURCE=${DOTFILES_SOURCE:-$HOME/Github/dotfiles}
has_source() {   # a distinct clone of the same remote exists
  [ -d "$SOURCE/.git" ] || return 1
  [ "$(cd "$SOURCE" && pwd -P)" != "$(cd "$DEPLOY" && pwd -P)" ] || return 1
  local a b
  a=$(git -C "$SOURCE" remote get-url origin 2>/dev/null)
  b=$(git -C "$DEPLOY" remote get-url origin 2>/dev/null)
  [ -n "$a" ] && [ "$a" = "$b" ]
}

# Absolute, ~-expanded, lexically normalised path (symlinks NOT resolved).
abspath() {
  local p=$1
  # shellcheck disable=SC2088  # literal "~" is matched on purpose, then expanded
  case $p in
    "~")                p=$HOME ;;
    "~/"*)              p=$HOME/${p#"~/"} ;;
    '$HOME'|'${HOME}')  p=$HOME ;;
    '$HOME/'*)          p=$HOME/${p#'$HOME/'} ;;
    '${HOME}/'*)        p=$HOME/${p#'${HOME}/'} ;;
  esac
  case $p in /*) ;; *) p=$cwd/$p ;; esac
  while :; do
    case $p in
      *//*)  p=${p%%//*}/${p#*//} ;;
      */./*) p=${p%%/./*}/${p#*/./} ;;
      *) break ;;
    esac
  done
  printf '%s' "$p"
}

HIT=""   # source-side path of the last match, for the message
is_deployed() {
  local p=$1 d f rel
  for d in "$DEPLOY"/*/; do
    d=${d%/}
    while IFS= read -r f; do
      rel=${f#"$d"/}
      case $rel in .*) ;; *) continue ;; esac      # stow targets are dotfiles
      if [ "$p" = "$HOME/$rel" ]; then HIT=${d##*/}/$rel; return 0; fi
    done < <(find "$d" -type f -not -path '*/.git/*' 2>/dev/null)
  done
  case $p in
    "$DEPLOY"/*) has_source && { HIT=${p#"$DEPLOY"/}; return 0; } ;;
  esac
  return 1
}

deny() {
  {
    printf 'Blocked by stow-guard: %s is deployed by the dotfiles repo.\n' "$1"
    printf 'Do not edit deployed files: the change would drift out of version control.\n'
    if has_source; then
      printf 'Source to change instead: %s/%s\n' "$SOURCE" "$HIT"
    fi
    printf 'If this is not the dotfiles project: describe the change (file, exact diff, reason) and hand it to the dotfiles session or to the user. See ~/.claude/rules/claude-config.md.\n'
  } >&2
  exit 2
}

# Does a short/long option request in-place editing, for this editor?
inplace_opt() {
  local ed=$1 t=$2 stop
  case $t in
    --in-place*) [ "$ed" != perl ]; return ;;
    --*|-) return 1 ;;
    -*) ;;
    *) return 1 ;;
  esac
  t=${t#-}
  case $ed in
    perl) stop='MmIeExlCdDF0123456789' ;;   # options taking an argument end the cluster
    *)    stop='efl' ;;
  esac
  t=${t%%["$stop"]*}
  case $t in *i*) return 0 ;; esac
  return 1
}

case $tool in
  Edit|Write|MultiEdit)
    f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    [ -n "$f" ] || exit 0
    is_deployed "$(abspath "$f")" && deny "$f"
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    case $cmd in *sed*|*perl*) ;; *) exit 0 ;; esac          # cheap exit
    while IFS= read -r seg; do
      ed="" inplace=0 paths=""
      set -f                     # split words without globbing them…
      for w in $seg; do
        w=${w#[\"\']}; w=${w%[\"\']}
        if [ -z "$ed" ]; then
          case ${w##*/} in sed|gsed) ed='sed' ;; perl) ed='perl' ;; esac
          continue
        fi
        if inplace_opt "$ed" "$w"; then inplace=1; continue; fi
        case $w in -*) continue ;; esac
        paths="$paths$w
"
      done
      set +f                     # …but is_deployed needs globbing to list packages
      [ "$inplace" = 1 ] || continue
      while IFS= read -r w; do
        [ -n "$w" ] || continue
        is_deployed "$(abspath "$w")" && deny "$w"
      done <<EOF
$paths
EOF
    done < <(printf '%s\n' "$cmd" | tr ';&|' '\n\n\n')
    ;;
esac
exit 0
