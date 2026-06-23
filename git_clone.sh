#!/bin/bash
# clone.sh v1.3.0
set -euo pipefail

VERSION="1.3.0"

# BASE = pasta-mãe deste script (mesma lógica do pull/push): os
# repositórios são clonados para ~/x/, um nível acima de git/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# Clone via GitHub CLI (gh): funciona igual no Windows e no Linux e usa a auth
# do gh (sem pedir usuário/senha e sem precisar configurar chave SSH por máquina).
# O protocolo (ssh/https) segue a config do gh: `gh config get git_protocol`.
# Formato: "OWNER/REPO|PASTA_DESTINO"  (destino relativo a BASE). 17 repositórios.
REPOS=(
    "samirhvbr/AREA81|AREA81"
    "samirhvbr/BLUE3_F1|BLUE3/F1"
    "samirhvbr/BLUE3_INTRANET|BLUE3/INTRANET"
    "samirhvbr/MEUIP|BLUE3/MEUIP"
    "samirhvbr/BLUE3-INTRANET-MOBILE|BLUE3/MOBILE"
    "samirhvbr/BLUE3_SITE_FRONT|BLUE3/SITE"
    "samirhvbr/BLUE3_WORLD_CUP_2026|BLUE3/WCUP"
    "samirhvbr/GIT|git"
    "samirhvbr/GITHUB_DESKTOP|GITHUB_DESKTOP"
    "samirhvbr/SHVIA|IA"
    "samirhvbr/MARTHINA_CLASS|KIDS/MARTHINA"
    "samirhvbr/RAFAELA_MEMORIA|KIDS/RAFAELA_JOGO_MEMORIA"
    "samirhvbr/BLUE3_DEBIAN_CUSTOM_ISO|LINUX/B3_CUSTOM_ISO"
    "samirhvbr/LINUX|LINUX/KERNEL"
    "samirhvbr/LINUX-START|LINUX/START"
    "samirhvbr/SHVTERM|SHVTERM/GUI"
    "samirhvbr/SHVTERM-WEB|SHVTERM/SITE"
)

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}clone.sh v${VERSION} — base: ${BASE}${NC}"

# Pré-requisito: gh instalado e autenticado (mesma exigência no Windows e no Linux).
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}✗ gh (GitHub CLI) não encontrado.${NC} Instale em https://cli.github.com e rode 'gh auth login'."
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}✗ gh não autenticado.${NC} Rode: gh auth login"
    exit 1
fi

ok=(); skip=(); fail=()

for entry in "${REPOS[@]}"; do
    repo="${entry%%|*}"
    dest="${entry##*|}"
    target="$BASE/$dest"

    echo -e "\n${CYAN}${BOLD}── $dest${NC}"
    echo -e "   ${repo}"

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
    if gh repo clone "$repo" "$target" 2>&1 | sed 's/^/   /'; then
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
