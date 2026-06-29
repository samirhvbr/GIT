#!/bin/bash
# git_status.sh v1.0.0
# ------------------------------------------------------------------
# Verificador de status (SOMENTE LEITURA) dos repositórios sob ~/x/.
#
# Varre os repositórios sob ~/x/ (mesma auto-descoberta do pull/push) e
# roda "git status" em cada um para mostrar o que está pendente de
# commit, além de commits locais a enviar / atrás do remoto. NÃO altera
# nada: não faz add, commit, pull nem push.
set -euo pipefail

VERSION="1.0.0"

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

# Repositórios a PULAR: passados como argumentos na linha de comando.
# Ex: ./git_status.sh odysseus        → checa todos, menos odysseus
#     ./git_status.sh odysseus blue3  → pula as duas pastas
#     ./git_status.sh DRIVE           → pula TUDO sob DRIVE/ (subárvore inteira)
# Casa o caminho exato (grupo/odysseus), o nome final (odysseus)
# ou uma pasta-ancestral (DRIVE pula DRIVE/ANDROID, DRIVE/IOS, ...).
SKIP=("$@")
should_skip() {
    local repo="$1"
    local name="${repo##*/}"
    local arg
    for arg in ${SKIP[@]+"${SKIP[@]}"}; do
        arg="${arg%/}"   # tolera barra final: "DRIVE/" vira "DRIVE"
        if [ "$arg" = "$repo" ] || [ "$arg" = "$name" ] || [ "${repo#"$arg"/}" != "$repo" ]; then
            return 0
        fi
    done
    return 1
}

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}git_status.sh v${VERSION} — base: ${BASE} (${#REPOS[@]} repos)${NC}"
[ ${#SKIP[@]} -gt 0 ] && echo -e "${YELLOW}  pulando: ${SKIP[*]}${NC}"

clean=(); dirty=(); skipped=(); fail=()

for repo in "${REPOS[@]}"; do
    echo -e "\n${CYAN}${BOLD}── $repo${NC}"

    if should_skip "$repo"; then
        echo -e "   ${YELLOW}↷ pulado (ignorado por argumento)${NC}"
        skipped+=("$repo"); continue
    fi

    if ! cd "$BASE/$repo" 2>/dev/null; then
        echo -e "${RED}  ✗ Diretório não encontrado${NC}"
        fail+=("$repo"); continue
    fi

    branch=$(git branch --show-current 2>/dev/null || echo "?")
    echo -e "   branch: ${YELLOW}${branch:-(detached)}${NC}"

    # Commits locais ainda não enviados / atrás do remoto (se houver upstream).
    if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null); then
        ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
        behind=$(git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
        [ "$ahead"  -gt 0 ] && echo -e "   ${YELLOW}↑ $ahead commit(s) local(is) a enviar${NC}"
        [ "$behind" -gt 0 ] && echo -e "   ${YELLOW}↓ $behind commit(s) atrás de $upstream${NC}"
    else
        echo -e "   ${YELLOW}sem upstream configurado${NC}"
    fi

    # Arquivos modificados/staged/untracked ainda não commitados.
    # (respeita .gitignore — arquivos ignorados não aparecem aqui)
    status=$(git status --porcelain 2>/dev/null || true)
    if [ -n "$status" ]; then
        count=$(printf '%s\n' "$status" | wc -l | tr -d ' ')
        echo -e "   ${RED}${BOLD}⚠  $count arquivo(s) pendente(s) de commit:${NC}"
        printf '%s\n' "$status" | sed 's/^/      /'
        dirty+=("$repo")
    else
        echo -e "   ${GREEN}✓ limpo (nada pendente de commit)${NC}"
        clean+=("$repo")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#dirty[@]}   -gt 0 ] && echo -e "${RED}  ⚠ Pendente: ${dirty[*]}${NC}"
[ ${#clean[@]}   -gt 0 ] && echo -e "${GREEN}  ✓ Limpo:    ${clean[*]}${NC}"
[ ${#fail[@]}    -gt 0 ] && echo -e "${RED}  ✗ Falhou:   ${fail[*]}${NC}"
[ ${#skipped[@]} -gt 0 ] && echo -e "${YELLOW}  ↷ Pulado:   ${skipped[*]}${NC}"
echo ""
