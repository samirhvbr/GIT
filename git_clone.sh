#!/bin/bash
# clone.sh v1.0.0
set -euo pipefail

VERSION="1.0.0"
BASE=~/x

# Formato: "URL_DO_REPO|PASTA_DESTINO"  (destino relativo a BASE)
REPOS=(
    "git@github.com:samirhvbr/SHVTERM-WEB.git|SHVTERM/SITE"
    "git@github.com:samirhvbr/SHVTERM.git|SHVTERM/GUI"
    # TODO: adicione os demais (mesmos destinos do push.sh):
    # "git@github.com:ORG/REPO.git|BLUE3/F1"
    # "git@github.com:ORG/REPO.git|BLUE3/INTRANET"
    # "git@github.com:ORG/REPO.git|BLUE3/MOBILE"
    # "git@github.com:ORG/REPO.git|BLUE3/MEUIP"
    # "git@github.com:ORG/REPO.git|BLUE3/SITE"
    # "git@github.com:ORG/REPO.git|BLUE3/WCUP"
    # "git@github.com:ORG/REPO.git|IA"
    # "git@github.com:ORG/REPO.git|AREA81"
)

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}clone.sh v${VERSION} — base: ${BASE}${NC}"

ok=(); skip=(); fail=()

for entry in "${REPOS[@]}"; do
    url="${entry%%|*}"
    dest="${entry##*|}"
    target="$BASE/$dest"

    echo -e "\n${CYAN}${BOLD}── $dest${NC}"
    echo -e "   ${url}"

    # Já clonado: pula
    if [ -d "$target/.git" ]; then
        echo -e "   ${YELLOW}Já existe — pulando${NC}"
        skip+=("$dest"); continue
    fi

    # Pasta existe e não está vazia (sem .git): não mexe
    if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
        echo -e "   ${RED}✗ Pasta existe e não está vazia${NC}"
        fail+=("$dest"); continue
    fi

    mkdir -p "$(dirname "$target")"
    if git clone "$url" "$target" 2>&1 | sed 's/^/   /'; then
        ok+=("$dest")
    else
        fail+=("$dest")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}   -gt 0 ] && echo -e "${GREEN}  ✓ Clonado:   ${ok[*]}${NC}"
[ ${#skip[@]} -gt 0 ] && echo -e "${YELLOW}  ⊙ Já existia: ${skip[*]}${NC}"
[ ${#fail[@]} -gt 0 ] && echo -e "${RED}  ✗ Falhou:    ${fail[*]}${NC}"
echo ""
