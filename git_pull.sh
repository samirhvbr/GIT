#!/bin/bash
# pull.sh v1.2.0
set -euo pipefail

VERSION="1.2.0"

# BASE = pasta-mãe deste script. Os scripts ficam em ~/x/git/ e os
# projetos um nível acima (em ~/x/), então subimos de git/ para a base.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# Auto-descobre todos os repositórios git sob a base, até 2 níveis
# (BASE/repo e BASE/grupo/repo). Sempre reflete as pastas atuais.
REPOS=()
while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    REPOS+=("${repo#"$BASE"/}")
done < <(find "$BASE" -maxdepth 3 -type d -name .git -prune 2>/dev/null | sort)

if [ ${#REPOS[@]} -eq 0 ]; then
    echo "Nenhum repositório git encontrado em $BASE" >&2
    exit 1
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}pull.sh v${VERSION} — base: ${BASE} (${#REPOS[@]} repos)${NC}"

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
