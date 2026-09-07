#!/bin/bash

BLUE='\033[94m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
BOLDRED='\033[1;91m'
INVRED='\033[1;97;41m'
DIM='\033[2m'
RESET='\033[0m'
SEP=" │ "

# progress_bar <percent> <width> [couleur]
progress_bar() {
  local percent=$1
  local width=${2:-15}
  local col=${3:-$GREEN}
  [[ -z "$percent" || "$percent" == "null" ]] && return
  local shown=$percent
  (( shown > 100 )) && shown=100
  local filled=$((shown * width / 100))
  local empty=$((width - filled))
  local bar="" i
  for ((i=0; i<filled; i++)); do bar="${bar}${col}█${RESET}"; done
  for ((i=0; i<empty;  i++)); do bar="${bar}${DIM}░${RESET}"; done
  printf "%b %3d%%" "$bar" "$percent"
}

input=$(cat)

model=$(echo "$input"        | jq -r '.model.display_name // empty')
session_id=$(echo "$input"   | jq -r '.session_id // empty')
ctx_tokens=$(echo "$input"   | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input"     | jq -r '.context_window.context_window_size // empty')
five_hour=$(echo "$input"          | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_hour_reset=$(echo "$input"    | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day=$(echo "$input"          | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_day_reset=$(echo "$input"    | jq -r '.rate_limits.seven_day.resets_at // empty')
duration=$(echo "$input"     | jq -r '.cost.total_api_duration_ms // empty')
cost=$(echo "$input"         | jq -r '.cost.total_cost_usd // empty')
cwd=$(echo "$input"          | jq -r '.cwd // .workspace.current_dir // empty')

# display_name est déjà formaté ("Sonnet 4.6")
short_model="$model"

# Duration
duration_str=""
if [[ -n "$duration" && "$duration" != "null" ]]; then
  secs=$((duration / 1000))
  mins=$((secs / 60)); secs=$((secs % 60))
  [[ $mins -gt 0 ]] && duration_str="${mins}m ${secs}s" || duration_str="${secs}s"
fi

# ── Line 1 ──────────────────────────────────────────────
line1=""
[[ -n "$short_model" ]] && line1="${BLUE}[${short_model}]${RESET}"

if [[ -n "$cwd" ]]; then
  [[ -n "$line1" ]] && line1="${line1} "
  line1="${line1}📁 $(basename "$cwd")"
fi

if [[ -n "$cwd" && -d "$cwd/.git" ]]; then
  cd "$cwd" 2>/dev/null || true
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  uncommitted=$(( $(git diff --name-only 2>/dev/null | wc -l) \
                + $(git diff --cached --name-only 2>/dev/null | wc -l) \
                + $(git ls-files --others --exclude-standard 2>/dev/null | wc -l) ))
  unpushed=$(git log --oneline --not --remotes 2>/dev/null | wc -l)

  [[ -n "$branch" ]]       && line1="${line1}${SEP}🌿 ${branch}"
  [[ $uncommitted -gt 0 ]] && line1="${line1}${SEP}${RED}✎ ${uncommitted}${RESET}"
  [[ $unpushed    -gt 0 ]] && line1="${line1}${SEP}${YELLOW}⬆ ${unpushed}${RESET}"
fi

# Session reset : relatif court "2h15" / "45min"
session_reset_label() {
  local ts=$1
  [[ -z "$ts" || "$ts" == "null" ]] && return
  local diff=$(( ts - $(date +%s) ))
  [[ $diff -le 0 ]] && echo "soon" && return
  local h=$(( diff / 3600 )) m=$(( (diff % 3600) / 60 ))
  [[ $h -gt 0 ]] && printf "%dh%02d" "$h" "$m" || printf "%dmin" "$m"
}

# Weekly reset : date absolue "Fri. 8am"
weekly_reset_label() {
  local ts=$1
  [[ -z "$ts" || "$ts" == "null" ]] && return
  local day hour ampm
  day=$(date -d "@$ts" +%a 2>/dev/null || date -r "$ts" +%a)
  hour=$(date -d "@$ts" +%-H 2>/dev/null || date -r "$ts" +%H | sed 's/^0//')
  if [[ $hour -eq 0 ]]; then ampm="12am"
  elif [[ $hour -lt 12 ]]; then ampm="${hour}am"
  elif [[ $hour -eq 12 ]]; then ampm="12pm"
  else ampm="$((hour-12))pm"
  fi
  printf "%s. %s" "$day" "$ampm"
}

# ── Contexte : calibré sur la fenêtre d'AUTO-COMPACTAGE ─────────────────
# 🔑 `context_window.used_percentage` du payload est calculé sur la fenêtre du
# modèle (1 000 000). Or l'auto-compactage se déclenche sur `autoCompactWindow`
# (800 000 ici), et empiriquement vers 96 % de celle-ci (~770k). Afficher le
# pourcentage du modèle donne « 77 % » à l'instant précis où ça compacte.
# On recalibre donc sur la vraie borne : 100 % = le compactage est imminent.
ctx_str=""; ctx_alert=""
if [[ -n "$ctx_tokens" && "$ctx_tokens" != "null" ]]; then
  window=$(jq -r '.autoCompactWindow // empty' ~/.claude/settings.json 2>/dev/null)
  [[ -z "$window" || "$window" == "null" ]] && window="$ctx_size"
  [[ -z "$window" || "$window" == "null" || "$window" -le 0 ]] && window=1000000
  # borne réelle observée du déclenchement automatique
  trigger=$(( window * 96 / 100 ))
  pct=$(( ctx_tokens * 100 / trigger ))

  if   (( pct >= 90 )); then col="$BOLDRED"
  elif (( pct >= 80 )); then col="$RED"
  elif (( pct >= 60 )); then col="$YELLOW"
  else                       col="$GREEN"
  fi

  ctx_str="Ctx $(progress_bar "$pct" 15 "$col") ${DIM}$((ctx_tokens/1000))k/$((trigger/1000))k${RESET}"

  if   (( pct >= 90 )); then ctx_alert="${INVRED} 🚨 COMPACTAGE IMMINENT — ROUTINE MAINTENANT ${RESET}"
  elif (( pct >= 80 )); then ctx_alert="${BOLDRED}🚨 PRÉ-COMPACT${RESET}"
  elif (( pct >= 70 )); then ctx_alert="${YELLOW}⚠ préparer la routine${RESET}"
  fi

  # Cloche du terminal, une seule fois par franchissement de seuil.
  if [[ -n "$session_id" ]]; then
    state="${TMPDIR:-/tmp}/claude-ctx-alert-${session_id}"
    last=$(cat "$state" 2>/dev/null || echo 0)
    reached=0
    for s in 70 80 90; do (( pct >= s )) && reached=$s; done
    if (( reached > last )); then
      printf '\a' >&2
      echo "$reached" > "$state"
    elif (( reached < last )); then
      echo "$reached" > "$state"   # après compactage : on réarme
    fi
  fi
fi

# ── Line 2 ──────────────────────────────────────────────
cost_str=""
if [[ -n "$cost" && "$cost" != "null" ]]; then
  cost_str=$(printf '$%.2f' "$cost")
fi

parts2=()
[[ -n "$ctx_str" ]] && parts2+=("$ctx_str")
if [[ -n "$five_hour" ]]; then
  five_r=$(session_reset_label "$five_hour_reset")
  five_bar=$(progress_bar "$five_hour" 15)
  parts2+=("Session${five_r:+ ${DIM}(${five_r})${RESET}} ${five_bar}")
fi
if [[ -n "$seven_day" ]]; then
  seven_r=$(weekly_reset_label "$seven_day_reset")
  seven_bar=$(progress_bar "$seven_day" 15)
  parts2+=("Weekly${seven_r:+ ${DIM}(${seven_r})${RESET}} ${seven_bar}")
fi
[[ -n "$cost_str"     ]] && parts2+=("💰 ${cost_str}")
[[ -n "$duration_str" ]] && parts2+=("⏱ ${duration_str}")

line2=""
for part in "${parts2[@]}"; do
  [[ -n "$line2" ]] && line2="${line2}${SEP}"
  line2="${line2}${part}"
done

[[ -n "$ctx_alert" ]] && line2="${line2}${SEP}${ctx_alert}"

printf "%b\n%b\n" "$line1" "$line2"
