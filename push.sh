#!/bin/bash
# push.sh v1.9.0
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

ok=(); warn=(); fail=(); noups=(); skipped=()

for repo in "${REPOS[@]}"; do
    echo -e "\n${CYAN}${BOLD}── $repo${NC}"

    if casa "$repo" "$EXCLUDE"; then
        echo -e "   ${YELLOW}↷ pulado (-d)${NC}"
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
    # green list as "up-to-date". status.sh has told this case apart since
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