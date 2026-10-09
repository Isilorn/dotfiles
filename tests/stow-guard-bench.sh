#!/usr/bin/env bash
# Bench for claude/.claude/hooks/stow-guard.sh — replays its decisions in a
# throwaway HOME, so nothing real is touched. Requires git, stow, jq.
#   tests/stow-guard-bench.sh        → one line per case, exit 1 on any mismatch
#
# The hook fails OPEN by design (and Claude Code treats a missing or broken
# hook as "allow"), so a guard that silently stopped refusing would look fine.
# This bench is what proves it still refuses.
set -u
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
H=$T/home; mkdir -p "$H/.claude" "$H/Sas/proj" "$H/work/proj"
git clone -q "$REPO" "$H/Github/dotfiles"
git clone -q "$REPO" "$H/.dotfiles"
stow --dir="$H/.dotfiles" --target="$H" --no-folding claude zsh
ln -s "$H/Sas/proj" "$H/work/proj/Sas"                 # a project sas, as on the fleet
HOOK=$H/.claude/hooks/stow-guard.sh

fail=0
check() {   # check <allow|deny> <label> <json> [env…]
  local want=$1 label=$2 json=$3 got rc; shift 3
  printf '%s' "$json" | env HOME="$H" "$@" bash "$HOOK" >/dev/null 2>&1; rc=$?
  case $rc in 0) got=allow ;; 2) got=deny ;; *) got="exit$rc" ;; esac
  if [ "$got" = "$want" ]; then printf '  ok    %-5s %s\n' "$got" "$label"
  else printf '  FAIL  %-5s %s (expected %s)\n' "$got" "$label" "$want"; fail=1; fi
}
edit() { jq -nc --arg t "$1" --arg f "$2" --arg c "${3:-$H}" '{tool_name:$t,cwd:$c,tool_input:{file_path:$f}}'; }
bash_() { jq -nc --arg c "$1" --arg d "${2:-$H}" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}'; }

echo "== Edit / Write =="
check deny  "Edit ~/.claude/settings.json (deployed)"        "$(edit Edit "$H/.claude/settings.json")"
check deny  "Write ~/.zshrc (deployed)"                       "$(edit Write "$H/.zshrc")"
# shellcheck disable=SC2088  # the hook must receive the literal "~"
check deny  "Edit with a literal ~ path"                      "$(edit Edit '~/.claude/settings.json')"
check deny  "Edit relative path from cwd ~/.claude"           "$(edit Edit settings.json "$H/.claude")"
check deny  "Edit inside the deployment clone (source exists)" "$(edit Edit "$H/.dotfiles/claude/.claude/settings.json")"
check allow "Edit in the SOURCE clone"                        "$(edit Edit "$H/Github/dotfiles/claude/.claude/settings.json")"
check allow "Edit an unrelated file"                          "$(edit Edit "$H/work/proj/notes.md")"
check allow "Edit a file in a project sas (symlink)"          "$(edit Write "$H/work/proj/Sas/out.txt")"
check allow "Edit a file in ~/Sas"                            "$(edit Write "$H/Sas/proj/out.txt")"
echo "== Bash: in-place editors =="
check deny  "sed -i on ~/.claude/settings.json"               "$(bash_ "sed -i 's/a/b/' ~/.claude/settings.json")"
check deny  "sed -Ei on \$HOME/.zshrc"                         "$(bash_ 'sed -Ei "s/a/b/" $HOME/.zshrc')"
check deny  "sed --in-place=.bak"                             "$(bash_ "sed --in-place=.bak -e s/a/b/ $H/.zshrc")"
check deny  "/usr/bin/sed -i after a cd &&"                   "$(bash_ "cd /tmp && /usr/bin/sed -i s/a/b/ $H/.zshrc")"
check deny  "perl -pi -e on ~/.zshrc"                         "$(bash_ "perl -pi -e 's/a/b/' ~/.zshrc")"
check deny  "perl -i.bak -pe"                                 "$(bash_ "perl -i.bak -pe 's/a/b/' ~/.zshrc")"
check deny  "sed -i in the deployment clone"                  "$(bash_ "sed -i s/a/b/ $H/.dotfiles/zsh/.zshrc")"
check allow "sed -i in the SOURCE clone"                      "$(bash_ "sed -i s/a/b/ $H/Github/dotfiles/zsh/.zshrc")"
check allow "sed -i on a sas file"                            "$(bash_ "sed -i s/a/b/ $H/work/proj/Sas/out.txt")"
check allow "sed WITHOUT -i reading ~/.zshrc"                 "$(bash_ "sed -n 1p ~/.zshrc")"
check allow "perl -Mstrict (an i that is not -i) on ~/.zshrc" "$(bash_ "perl -Mstrict -ne 'print' ~/.zshrc")"
check allow "cat / jq on settings.json (reads)"               "$(bash_ "jq . ~/.claude/settings.json > /tmp/x; cat ~/.zshrc")"
check allow "cp onto ~/.zshrc (not an in-place editor, by choice)" "$(bash_ "cp /tmp/x ~/.zshrc")"
echo "== The dotfiles session's own work =="
check allow "redeploy: git pull + install.sh in the deployment clone" "$(bash_ "cd $H/.dotfiles && git pull -q && ./install.sh --no-packages")"
check allow "discard ported changes: git checkout in the clone"       "$(bash_ "git -C $H/.dotfiles checkout -- zsh/.zshrc")"
check allow "memory under ~/.claude/projects (not deployed)"          "$(edit Write "$H/.claude/projects/p/memory/m.md")"
check allow "KNOWN GAP: python rewriting a deployed file"             "$(bash_ "python3 -c \"open('$H/.zshrc','w')\"")"
echo "== Escape hatch, fail-open, single-clone machine =="
check allow "DOTFILES_GUARD=off at launch"                    "$(edit Edit "$H/.claude/settings.json")" DOTFILES_GUARD=off
check allow "malformed input → fail open"                     'not json'
check allow "unknown tool"                                    '{"tool_name":"Read","tool_input":{"file_path":"~/.zshrc"}}'
rm -rf "$H/Github/dotfiles"                                   # now the deployment clone is the only clone
check allow "single clone: edit inside it is allowed"         "$(edit Edit "$H/.dotfiles/claude/.claude/settings.json")"
check deny  "single clone: ~/.claude/settings.json still refused" "$(edit Edit "$H/.claude/settings.json")"

[ "$fail" = 0 ] && echo "ALL OK" || echo "FAILURES"
exit "$fail"
