#!/bin/bash
# push.sh v1.8.13
set -euo pipefail

VERSION="1.8.13"

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
# Ex: ./git_push.sh odysseus        → envia todos, menos odysseus
#     ./git_push.sh odysseus blue3  → pula as duas pastas
#     ./git_push.sh DRIVE           → pula TUDO sob DRIVE/ (subárvore inteira)
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

echo -e "${BOLD}push.sh v${VERSION} — base: ${BASE} (${#REPOS[@]} repos)${NC}"
[ ${#SKIP[@]} -gt 0 ] && echo -e "${YELLOW}  pulando: ${SKIP[*]}${NC}"

ok=(); warn=(); fail=(); noups=(); skipped=()

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
    echo -e "   branch: ${YELLOW}$branch${NC}"

    # Arquivos modificados/staged ainda não commitados
    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$dirty" -gt 0 ]; then
        echo -e "   ${RED}${BOLD}⚠  $dirty arquivo(s) com commit pendente!${NC}"
        warn+=("$repo")
    fi

    # Without an upstream there is no answer to "how many commits are left to
    # send" — and asking kills the sweep. `git log '@{u}..'` exits non-zero,
    # `pipefail` carries that through `wc`/`tr`, the assignment inherits it and
    # `set -e` ends the script right there: no summary, no reason on screen, and
    # every repository after this one in the listing never gets pushed.
    #
    # Reporting it is the other half. A branch with commits and nowhere to send
    # them is the case where a push matters MOST, and it was landing in the
    # green list as "up-to-date". git_status.sh has told this case apart since
    # 1.5.1; the push never did.
    if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
        locais=$(git rev-list --count HEAD 2>/dev/null || echo 0)
        echo -e "   ${RED}${BOLD}✗ sem upstream${NC}${RED} — $locais commit(s) sem para onde ir${NC}"
        echo -e "      ${YELLOW}conserto: git push -u origin ${branch:-<branch>}${NC}"
        noups+=("$repo"); continue
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
[ ${#ok[@]}      -gt 0 ] && echo -e "${GREEN}  ✓ OK:       ${ok[*]}${NC}"
[ ${#warn[@]}    -gt 0 ] && echo -e "${YELLOW}  ⚠ Commitar: ${warn[*]}${NC}"
[ ${#noups[@]}   -gt 0 ] && echo -e "${RED}  ✗ Sem upstream: ${noups[*]}${NC}"
[ ${#fail[@]}    -gt 0 ] && echo -e "${RED}  ✗ Falhou:   ${fail[*]}${NC}"
[ ${#skipped[@]} -gt 0 ] && echo -e "${YELLOW}  ↷ Pulado:   ${skipped[*]}${NC}"
echo ""