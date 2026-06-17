#!/bin/bash
# push.sh v1.1.0
set -euo pipefail

VERSION="1.1.0"
BASE=~/x
REPOS=(
    BLUE3/F1
    BLUE3/INTRANET
    BLUE3/MOBILE
    BLUE3/MEUIP
    BLUE3/SITE
    BLUE3/WCUP
    SHVTERM/GUI
    SHVTERM/SITE
    IA
    AREA81
)

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}push.sh v${VERSION} — base: ${BASE}${NC}"

ok=(); warn=(); fail=()

for repo in "${REPOS[@]}"; do
    echo -e "\n${CYAN}${BOLD}── $repo${NC}"
    if ! cd "$BASE/$repo" 2>/dev/null; then
        echo -e "${RED}  ✗ Diretório não encontrado${NC}"
        fail+=("$repo"); continue
    fi

    branch=$(git branch --show-current 2>/dev/null || echo "?")
    echo -e "   branch: ${YELLOW}$branch${NC}"

    # Arquivos modificados/staged ainda não commitados
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" -gt 0 ]; then
        echo -e "   ${RED}${BOLD}⚠  $dirty arquivo(s) com commit pendente!${NC}"
        warn+=("$repo")
    fi

    # Commits prontos para push
    pending=$(git log '@{u}..' --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pending" -eq 0 ]; then
        echo -e "   ${YELLOW}Nada a enviar (up-to-date)${NC}"
        ok+=("$repo"); continue
    fi

    echo -e "   ${pending} commit(s) a enviar"
    if git push 2>&1 | sed 's/^/   /'; then
        ok+=("$repo")
    else
        fail+=("$repo")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}   -gt 0 ] && echo -e "${GREEN}  ✓ OK:       ${ok[*]}${NC}"
[ ${#warn[@]} -gt 0 ] && echo -e "${YELLOW}  ⚠ Commitar: ${warn[*]}${NC}"
[ ${#fail[@]} -gt 0 ] && echo -e "${RED}  ✗ Falhou:   ${fail[*]}${NC}"
echo ""
