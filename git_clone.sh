#!/bin/bash
# clone.sh v1.2.0
set -euo pipefail

VERSION="1.2.0"

# BASE = pasta-mãe deste script (mesma lógica do pull/push): os
# repositórios são clonados para ~/x/, um nível acima de git/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# Formato: "URL_DO_REPO|PASTA_DESTINO"  (destino relativo a BASE).
# Lista espelha a estrutura atual (origin de cada repo). 16 repositórios.
REPOS=(
    "git@github.com:samirhvbr/AREA81.git|AREA81"
    "git@github.com:samirhvbr/BLUE3_F1.git|BLUE3/F1"
    "git@github.com:samirhvbr/BLUE3_INTRANET.git|BLUE3/INTRANET"
    "git@github.com:samirhvbr/MEUIP.git|BLUE3/MEUIP"
    "git@github.com:samirhvbr/BLUE3-INTRANET-MOBILE.git|BLUE3/MOBILE"
    "git@github.com:samirhvbr/BLUE3_SITE_FRONT.git|BLUE3/SITE"
    "git@github.com:samirhvbr/BLUE3_WORLD_CUP_2026.git|BLUE3/WCUP"
    "git@github.com:samirhvbr/GIT.git|git"
    "git@github.com:samirhvbr/SHVIA.git|IA"
    "git@github.com:samirhvbr/MARTHINA_CLASS.git|KIDS/MARTHINA"
    "git@github.com:samirhvbr/RAFAELA_MEMORIA.git|KIDS/RAFAELA_JOGO_MEMORIA"
    "git@github.com:samirhvbr/BLUE3_DEBIAN_CUSTOM_ISO.git|LINUX/B3_CUSTOM_ISO"
    "git@github.com:samirhvbr/LINUX.git|LINUX/KERNEL"
    "git@github.com:samirhvbr/LINUX-START.git|LINUX/START"
    "git@github.com:samirhvbr/SHVTERM.git|SHVTERM/GUI"
    "git@github.com:samirhvbr/SHVTERM-WEB.git|SHVTERM/SITE"
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
