#!/bin/bash
# pull.sh v1.8.13
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
# Ex: ./git_pull.sh odysseus        → atualiza todos, menos odysseus
#     ./git_pull.sh odysseus blue3  → pula as duas pastas
#     ./git_pull.sh DRIVE           → pula TUDO sob DRIVE/ (subárvore inteira)
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

echo -e "${BOLD}pull.sh v${VERSION} — base: ${BASE} (${#REPOS[@]} repos)${NC}"
[ ${#SKIP[@]} -gt 0 ] && echo -e "${YELLOW}  pulando: ${SKIP[*]}${NC}"

# Names the reason a pull failed, from git's own message. A bare "✗" said that
# the repo failed, never WHY — and the causes that show up in practice each need
# a different repair: a branch with no upstream, a branch deleted on the remote
# (the local ref survives the fetch and hides it), and a diverged history are
# three different jobs wearing the same mark.
classify_fail() {
    case "$1" in
        *"no tracking information"*|*"no upstream"*)
            echo "sem upstream" ;;
        *"no such ref was fetched"*)
            echo "branch apagada no remoto" ;;
        *"Diverging branches"*|*"Not possible to fast-forward"*|*"divergent"*|*"non-fast-forward"*)
            echo "divergiu do remoto" ;;
        *"local changes"*|*"would be overwritten"*|*"unstaged changes"*|*"Please commit"*)
            echo "árvore suja" ;;
        *"Could not read from remote"*|*"unable to access"*|*"Repository not found"*|*"Permission denied"*|*"ould not resolve host"*|*"Connection"*|*"timed out"*)
            echo "remoto inacessível" ;;
        *"fix conflicts"*|*"CONFLICT"*)
            echo "conflito" ;;
        *)
            echo "outro" ;;
    esac
}

ok=(); fail=(); fail_reason=(); skipped=()

for repo in "${REPOS[@]}"; do
    echo -e "\n${CYAN}${BOLD}── $repo${NC}"

    if should_skip "$repo"; then
        echo -e "   ${YELLOW}↷ pulado (ignorado por argumento)${NC}"
        skipped+=("$repo"); continue
    fi

    if ! cd "$BASE/$repo" 2>/dev/null; then
        echo -e "${RED}  ✗ Diretório não encontrado${NC}"
        fail+=("$repo"); fail_reason+=("diretório não encontrado"); continue
    fi

    branch=$(git branch --show-current 2>/dev/null || echo "?")
    echo -e "   branch: ${YELLOW}$branch${NC}"

    # The output is captured instead of streamed because classify_fail reads it.
    # `set -e` stays suspended inside the `if` condition, so a failed pull does
    # not abort the sweep.
    if out=$(git pull --ff-only 2>&1); then
        printf '%s\n' "$out" | sed 's/^/   /'
        ok+=("$repo")
    else
        printf '%s\n' "$out" | sed 's/^/   /'
        motivo=$(classify_fail "$out")
        echo -e "   ${RED}✗ $motivo${NC}"
        fail+=("$repo"); fail_reason+=("$motivo")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}      -gt 0 ] && echo -e "${GREEN}  ✓ OK:     ${ok[*]}${NC}"
if [ ${#fail[@]} -gt 0 ]; then
    echo -e "${RED}  ✗ Falhou: ${fail[*]}${NC}"
    # Grouped by reason: the flat list answers "which", and what is actually
    # wanted is "which repair", which is not the same for the repos on it.
    for motivo in "sem upstream" "branch apagada no remoto" "divergiu do remoto" \
                  "árvore suja" "conflito" "remoto inacessível" \
                  "diretório não encontrado" "outro"; do
        linha=""; i=0
        while [ $i -lt ${#fail[@]} ]; do
            [ "${fail_reason[$i]}" = "$motivo" ] && linha="$linha ${fail[$i]}"
            i=$((i + 1))
        done
        [ -n "$linha" ] && echo -e "${RED}      ${motivo}:${NC}${linha}"
    done
fi
[ ${#skipped[@]} -gt 0 ] && echo -e "${YELLOW}  ↷ Pulado: ${skipped[*]}${NC}"
echo ""