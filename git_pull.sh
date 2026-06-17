#!/bin/bash
# pull.sh v1.1.0
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

echo -e "${BOLD}pull.sh v${VERSION} — base: ${BASE}${NC}"

ok=(); fail=()

for repo in "${REPOS[@]}"; do
    echo -e "\n${CYAN}${BOLD}── $repo${NC}"
    if ! cd "$BASE/$repo" 2>/dev/null; then
        echo -e "${RED}  ✗ Diretório não encontrado${NC}"
        fail+=("$repo"); continue
    fi

    branch=$(git branch --show-current 2>/dev/null || echo "?")
    echo -e "   branch: ${YELLOW}$branch${NC}"

    if git pull --ff-only 2>&1 | sed 's/^/   /'; then
        ok+=("$repo")
    else
        fail+=("$repo")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}   -gt 0 ] && echo -e "${GREEN}  ✓ OK:     ${ok[*]}${NC}"
[ ${#fail[@]} -gt 0 ] && echo -e "${RED}  ✗ Falhou: ${fail[*]}${NC}"
echo ""
