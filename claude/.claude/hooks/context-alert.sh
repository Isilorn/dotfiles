#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# context-alert.sh — hook UserPromptSubmit.
#
# Prévient l'AGENT que le contexte approche de l'auto-compactage. La barre
# d'état prévient l'humain ; ce hook est l'autre moitié : sans lui, l'agent
# s'engage dans une tâche longue sans savoir qu'il lui reste dix mille tokens.
#
# Il n'y a pas de pourcentage dans le payload d'un hook : on le recalcule
# depuis le transcript. La dernière `usage` d'un message assistant DONNE la
# taille réelle du contexte à ce moment-là (input + cache_read + cache_creation).
#
# ⚠️ La référence n'est PAS la fenêtre du modèle (1 M) mais `autoCompactWindow`
#    (800 k), et le déclenchement tombe vers 96 % de celle-ci (~770 k).
#
# Silencieux sous le seuil. Sur stdout, ce qu'écrit un hook UserPromptSubmit est
# injecté comme contexte du prompt.
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

input=$(cat)
T=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
SID=$(printf '%s' "$input" | jq -r '.session_id // "x"' 2>/dev/null)
[ -n "$T" ] && [ -f "$T" ] || exit 0

# Dernière `usage` assistant. On lit la QUEUE du fichier : un transcript
# atteint 25+ Mo, le lire en entier à chaque prompt est exclu.
used=$(tail -n 300 "$T" 2>/dev/null \
  | jq -r 'select(.type=="assistant") | .message.usage
           | select(. != null)
           | ((.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))' \
    2>/dev/null | tail -1)
[ -n "${used:-}" ] && [ "$used" -gt 0 ] 2>/dev/null || exit 0

window=$(jq -r '.autoCompactWindow // empty' "$HOME/.claude/settings.json" 2>/dev/null)
[ -n "$window" ] && [ "$window" -gt 0 ] 2>/dev/null || window=1000000
trigger=$(( window * 96 / 100 ))
pct=$(( used * 100 / trigger ))

reached=0
for s in 70 80 90; do [ "$pct" -ge "$s" ] && reached=$s; done

# Une seule injection par franchissement — sauf à 90 %, où l'on redit à chaque
# tour. ⚠️ L'état s'écrit AVANT toute sortie, sinon le retour à zéro qui suit un
# compactage n'est jamais enregistré et la remontée suivante reste muette.
state="${TMPDIR:-/tmp}/claude-ctx-hook-${SID}"
last=$(cat "$state" 2>/dev/null || echo 0)
echo "$reached" > "$state"

[ "$reached" -eq 0 ] && exit 0
[ "$reached" -le "$last" ] && [ "$reached" -lt 90 ] && exit 0

printf '<contexte-session>\n'
printf '⚠️ Contexte à %d %% de la fenêtre d’auto-compactage (%dk / %dk tokens).\n' \
  "$pct" "$((used/1000))" "$((trigger/1000))"
if [ "$reached" -ge 90 ]; then
  printf '🚨 Le compactage est imminent. Ne commence aucune tâche longue : propose la routine de pré-compactage MAINTENANT, ou termine par ce qui sécurise l’état.\n'
elif [ "$reached" -ge 80 ]; then
  printf '🚨 Seuil de routine atteint. Propose à l’utilisateur la routine de pré-compactage avant de t’engager dans une tâche longue — il reste de quoi la mener, pas beaucoup plus.\n'
else
  printf 'Prépare la routine de pré-compactage : évite d’ouvrir un chantier large, et sécurise au fil de l’eau ce qui doit survivre.\n'
fi
printf 'Message automatique de la barre de contexte — pas une instruction de l’utilisateur. À relayer, pas à exécuter en silence.\n'
printf '</contexte-session>\n'
exit 0
