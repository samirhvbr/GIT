#!/bin/bash
# pull.sh v1.9.0
set -euo pipefail

VERSION="1.9.0"

# BASE = pasta-mãe deste script. Os scripts ficam em ~/x/git/ e os
# projetos um nível acima (em ~/x/), então subimos de git/ para a base.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# ── Quais repositórios entram: -d exclui, -i restringe ───────────────────────
# A flag vale para todas as palavras seguintes até aparecer outra, então
# `-d 000 001` e `-d 000 -d 001` dizem a mesma coisa — não é preciso decorar
# qual das duas o script aceita. Palavra solta, sem flag nenhuma, continua
# sendo exclusão: é como o script sempre funcionou, e o que já está na crontab
# e no dedo de quem usa segue valendo sem edição.
#
# As listas são strings (uma entrada por linha) e não arrays: o bash do macOS é
# 3.2, e lá `${#arr[@]}` sobre array vazio com `set -u` é "unbound variable".
NOME="$(basename "${BASH_SOURCE[0]}")"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

usage() {
    cat <<EOF
uso: ./$NOME [-d DIR...] [-i DIR...] [DIR...]

  -d, --exclude DIR   deixa DIR de fora (e tudo que estiver sob ele)
  -i, --only DIR      roda SÓ em DIR (e no que estiver sob ele)
  -h, --help          esta ajuda

A flag vale para todas as palavras seguintes até aparecer outra, então
'-d 000 001' e '-d 000 -d 001' são a mesma coisa. Palavra solta, sem flag
nenhuma, é exclusão — o comportamento antigo do script.

DIR casa pelo caminho (BLUE3/CNPJ), pelo nome final (CNPJ) ou pela pasta-mãe
(BLUE3 alcança tudo que estiver sob BLUE3/).

  ./$NOME -d 000                    todos, menos o balde de terceiros
  ./$NOME -d 000 -d B3DEV           todos, menos os dois
  ./$NOME -i BLUE3                  só os de BLUE3/
  ./$NOME -i BLUE3 -d BLUE3/CNPJ    só BLUE3/, menos o CNPJ
EOF
}

EXCLUDE=""; ONLY=""; modo="d"
while [ $# -gt 0 ]; do
    case "$1" in
        -d|--exclude)        modo="d" ;;
        -i|--only|--include) modo="i" ;;
        -h|--help)           usage; exit 0 ;;
        -*)  echo "opção desconhecida: $1" >&2; echo >&2; usage >&2; exit 2 ;;
        *)   alvo="${1#./}"; alvo="${alvo%/}"   # tolera "./BLUE3/" e "BLUE3/"
             if [ "$modo" = "i" ]; then
                 ONLY="$ONLY$alvo
"
             else
                 EXCLUDE="$EXCLUDE$alvo
"
             fi ;;
    esac
    shift
done

# Casa o caminho exato (BLUE3/CNPJ), o nome final (CNPJ) ou uma pasta-mãe
# (BLUE3 alcança BLUE3/CNPJ, BLUE3/MEUIP, ...). Mesma regra dos dois lados: o
# que o -d entende por "esse aí", o -i entende igual.
casa_um() {
    local repo="$1" arg="$2" name="${1##*/}"
    [ "$arg" = "$repo" ] || [ "$arg" = "$name" ] || [ "${repo#"$arg"/}" != "$repo" ]
}

casa() {
    local repo="$1" lista="$2" arg
    [ -n "$lista" ] || return 1
    # Here-string e não pipe: assim o `return` sai da função, e não de um subshell.
    while IFS= read -r arg; do
        [ -n "$arg" ] || continue
        casa_um "$repo" "$arg" && return 0
    done <<< "$lista"
    return 1
}

# Auto-descobre todos os repositórios git sob a base, até 2 níveis
# (BASE/repo e BASE/grupo/repo). Sempre reflete as pastas atuais.
ACHADOS=()
while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    ACHADOS+=("${repo#"$BASE"/}")
done < <(find "$BASE" -maxdepth 3 -type d -name .git -prune 2>/dev/null | sort)

if [ ${#ACHADOS[@]} -eq 0 ]; then
    echo "Nenhum repositório git encontrado em $BASE" >&2
    exit 1
fi

# O -i corta aqui, antes do laço, e o -d corta lá dentro. Não é simetria
# perdida: `-i BLUE3` numa base de 114 repositórios imprimiria uma centena de
# linhas de "pulado" antes da primeira linha útil, enquanto o -d nomeia repos um
# a um e quem digitou quer ver a exclusão confirmada na tela.
REPOS=(); fora=0
for repo in "${ACHADOS[@]}"; do
    if [ -n "$ONLY" ] && ! casa "$repo" "$ONLY"; then
        fora=$((fora + 1)); continue
    fi
    REPOS+=("$repo")
done

# Argumento que não alcança repositório nenhum é quase sempre erro de digitação,
# e os dois modos erram em silêncio, em direções opostas: um -d escrito errado
# mexe justamente no que era para ficar de fora, e um -i escrito errado zera a
# varredura inteira sem dizer por quê.
avisa_orfaos() {
    local lista="$1" rotulo="$2" arg repo achou
    [ -n "$lista" ] || return 0
    while IFS= read -r arg; do
        [ -n "$arg" ] || continue
        achou=0
        for repo in ${ACHADOS[@]+"${ACHADOS[@]}"}; do
            casa_um "$repo" "$arg" && { achou=1; break; }
        done
        [ "$achou" -eq 0 ] && echo -e "${YELLOW}  ⚠ $rotulo '$arg' não casa com nenhum repositório sob $BASE${NC}"
    done <<< "$lista"
    return 0
}

echo -e "${BOLD}$NOME v${VERSION} — base: ${BASE} (${#REPOS[@]} de ${#ACHADOS[@]} repos)${NC}"
[ -n "$ONLY" ]    && echo -e "${CYAN}  -i só:   $(printf '%s' "$ONLY" | tr '\n' ' ')${NC}(${fora} fora)"
[ -n "$EXCLUDE" ] && echo -e "${YELLOW}  -d fora: $(printf '%s' "$EXCLUDE" | tr '\n' ' ')${NC}"
avisa_orfaos "$ONLY" "-i"
avisa_orfaos "$EXCLUDE" "-d"

if [ ${#REPOS[@]} -eq 0 ]; then
    echo -e "${RED}Nenhum repositório sobrou depois do -i/-d — nada a fazer.${NC}" >&2
    exit 1
fi

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

    if casa "$repo" "$EXCLUDE"; then
        echo -e "   ${YELLOW}↷ pulado (-d)${NC}"
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