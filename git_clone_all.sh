#!/bin/bash
# clone_all.sh v1.1.0
set -euo pipefail

VERSION="1.1.0"

# BASE = pasta-mãe deste script (mesma lógica do clone/pull/push): os
# repositórios são clonados para ~/x/, um nível acima de git/.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# Destino: 2º argumento (pasta onde clonar todos os repos), senão BASE
# (comportamento antigo — um nível acima de GIT/).
# Ex: ./git_clone_all.sh samirhvbr ~/x/samirhvbr
DEST_DIR="${2:-$BASE}"
# Expande ~ mesmo se vier entre aspas (sem aspas, o shell já expande sozinho).
case "$DEST_DIR" in
    "~")   DEST_DIR="$HOME" ;;
    "~/"*) DEST_DIR="$HOME/${DEST_DIR#\~/}" ;;
esac

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# Pré-requisito: gh instalado e autenticado (igual ao git_clone.sh).
if ! command -v gh >/dev/null 2>&1; then
    echo -e "${RED}✗ gh (GitHub CLI) não encontrado.${NC} Instale em https://cli.github.com e rode 'gh auth login'."
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    echo -e "${RED}✗ gh não autenticado.${NC} Rode: gh auth login"
    exit 1
fi

# Dono a clonar: 1º argumento, ou o usuário autenticado no gh (zero manutenção —
# descobre a conta sozinho).
#   ./git_clone_all.sh                          (usuário do gh  → BASE)
#   ./git_clone_all.sh outro-usuario            (outro dono     → BASE)
#   ./git_clone_all.sh outro-usuario ~/x/pasta  (outro dono     → pasta escolhida)
OWNER="${1:-$(gh api user --jq .login 2>/dev/null)}"
if [ -z "$OWNER" ]; then
    echo -e "${RED}✗ Não foi possível descobrir o usuário do gh.${NC} Passe explícito: ./git_clone_all.sh <usuario>"
    exit 1
fi

echo -e "${BOLD}clone_all.sh v${VERSION} — dono: ${OWNER} → destino: ${DEST_DIR}${NC}"
mkdir -p "$DEST_DIR"

# Lista TODOS os repositórios do dono (até 1000) direto da API do GitHub — assim
# não precisa manter lista fixa como o git_clone.sh. Ajuste os filtros abaixo se
# quiser incluir/excluir forks ou arquivados:
#   --no-archived   (padrão aqui: pula os arquivados)
#   --fork / --source  para restringir a forks ou só repos originais
echo -e "${CYAN}Consultando repositórios de ${OWNER}...${NC}"
# Captura antes de iterar para distinguir erro (usuário inexistente / gh caído)
# de "sem repositórios" — process-substitution engoliria o erro silenciosamente.
if ! repos_raw="$(gh repo list "$OWNER" --no-archived --limit 1000 \
    --json nameWithOwner --jq '.[].nameWithOwner' | sort)"; then
    echo -e "${RED}✗ Falha ao consultar repositórios de ${OWNER}.${NC} O usuário existe? O gh está autenticado?"
    exit 1
fi
if [ -z "$repos_raw" ]; then
    echo -e "${YELLOW}Nenhum repositório encontrado para ${OWNER}.${NC}"
    exit 0
fi
# bash 3.2 (padrão do macOS) não tem `mapfile`; iteramos com while-read, que é
# portátil e — por ser aqui-string e não pipe — não roda em subshell, então os
# contadores abaixo persistem.
total=$(grep -c . <<< "$repos_raw")
echo -e "${BOLD}${total} repositórios encontrados.${NC}"

ok=(); skip=(); fail=()

while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    # Clone plano: a pasta usa só o nome do repo (owner/REPO → REPO), como já é o
    # layout real de ~/x/ (BLUE3-F1, BLUE3-INTRANET, KIDS-MARA-1, ...).
    dest="${repo##*/}"
    target="$DEST_DIR/$dest"

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
done <<< "$repos_raw"

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}   -gt 0 ] && echo -e "${GREEN}  ✓ Clonado:   ${ok[*]}${NC}"
[ ${#skip[@]} -gt 0 ] && echo -e "${YELLOW}  ⊙ Já existia: ${skip[*]}${NC}"
[ ${#fail[@]} -gt 0 ] && echo -e "${RED}  ✗ Falhou:    ${fail[*]}${NC}"
echo ""
