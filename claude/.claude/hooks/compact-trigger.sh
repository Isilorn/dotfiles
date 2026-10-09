# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# compact-trigger.sh — the ONE place that computes where auto-compaction fires.
# Sourced (not executed) by statusline-command.sh and hooks/context-alert.sh, so
# the gauge and the alert can never disagree on the threshold.
#
#   compact_trigger <model_id> <context_window_size>   → prints a token count
#
# 🔑 The trigger is `window − 33k`, NOT `window × 0.96`.
#    Measured on Claude Code 2.1.295 with `claude -p --autocompact <w> "/context"`:
#    the « Autocompact buffer » is a FIXED 33k at 100k, 200k, 500k, 800k and 1M.
#    `× 0.96` only matched at 800k, by coincidence (768k vs 767k); at 100k it is
#    29k too late, so the gauge never warns. A real run at --autocompact 100k
#    compacted at preTokens 66 903 and 67 353 (last usage below: 59–65k).
#
# Window resolution, highest precedence first (Claude Code docs, settings-reference
# #modelsettings and model-config#set-the-auto-compact-window):
#   1. env CLAUDE_CODE_AUTO_COMPACT_WINDOW (plain token count)
#   2. modelSettings.<canonical model>.autoCompactWindow — where `/autocompact`
#      writes since v2.1.288. Reading only the top-level key would leave every
#      alert AFTER the compaction once someone runs `/autocompact 500k`.
#   3. top-level autoCompactWindow
#   4. the model's own window. "auto" also means the model's window.
# Then capped to the model's window, as Claude Code does.
#
# ⚠️ Blind spots, by construction: the `--autocompact` launch flag is invisible
#    here, and only the user settings file is read (project or managed settings
#    that set a window are missed).
# ─────────────────────────────────────────────────────────────────────────────

COMPACT_RESERVE=33000

compact_trigger() {
  local id=${1:-} size=${2:-} canon window t
  [[ "$size" =~ ^[0-9]+$ ]] && (( size > 0 )) || size=1000000

  # canonical name: drop a "[1m]" suffix, then a "-YYYYMMDD" date suffix
  canon=${id%%\[*}
  [[ "$canon" =~ ^(.*)-[0-9]{8}$ ]] && canon=${BASH_REMATCH[1]}

  window=${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-}
  if [[ -z "$window" ]]; then
    window=$(command jq -r --arg m "$canon" \
      '(.modelSettings[$m].autoCompactWindow // .autoCompactWindow // empty) | tostring' \
      "$HOME/.claude/settings.json" 2>/dev/null)
  fi
  [[ "$window" =~ ^[0-9]+$ ]] && (( window > 0 )) || window=$size   # "auto", empty, junk
  (( window > size )) && window=$size

  t=$(( window - COMPACT_RESERVE ))
  (( t > 0 )) || t=$window
  printf '%s\n' "$t"
}
