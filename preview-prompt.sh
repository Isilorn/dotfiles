#!/usr/bin/env bash
BOLD="\033[1m"; CYAN="\033[36m"; BLUE="\033[34m"; PURPLE="\033[35m"
YELLOW="\033[33m"; RED="\033[31m"; GREEN="\033[32m"; DIM="\033[2m"; R="\033[0m"

r() {
  local label="$1"; shift
  printf "${DIM}── %s ${R}\n" "$label"
  printf "$@"
  printf "\n${GREEN}${BOLD}❯${R}\n\n"
}

r "Normal session"           "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}~/etc/nginx${R} "
r "Clean git repo"           "${BOLD}${CYAN}gtillit@macbook${R} ${BOLD}${BLUE}~/projects/dotfiles${R} ${BOLD}${PURPLE}\ue0a0 main${R} "
r "Git repo with changes"    "${BOLD}${CYAN}gtillit@macbook${R} ${BOLD}${BLUE}~/projects/dotfiles${R} ${BOLD}${PURPLE}\ue0a0 main${R} ${BOLD}${YELLOW}[!3 ?1 +2]${R} "
r "Sudo cached"              "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}/etc/nginx${R} ${BOLD}${RED}\uf023 ${R} "
r "Background jobs"          "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}~${R} ${BOLD}${YELLOW}\uf013 2${R} "
r "Long command"             "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}~${R} ${YELLOW}45s${R} "
r "Read-only directory"      "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}/etc/nginx \uf023 ${R} "
r "Root"                     "${BOLD}${RED}root@bluemoon${R} ${BOLD}${BLUE}/etc${R} "

printf "${DIM}── Failed command ${R}\n"
printf "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}~${R} ${BOLD}${RED}✗ 127${R} \n${RED}${BOLD}❯${R}\n\n"

r "Everything at once"       "${BOLD}${CYAN}gtillit@bluemoon${R} ${BOLD}${BLUE}~/projects/api${R} ${BOLD}${PURPLE}\ue0a0 main${R} ${BOLD}${YELLOW}[⇡1 !2 ?3]${R} ${BOLD}${RED}\uf023 ${R} ${BOLD}${YELLOW}\uf013 2${R} ${YELLOW}1m32s${R} "
