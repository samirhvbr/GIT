#!/bin/bash
# clone_all.sh v1.8.12
set -euo pipefail

# --dry-run/-n é filtrado ANTES de tudo: o destino sai de "$2", então a flag não
# pode ocupar posição. Mostrar o plano antes de criar árvore de diretórios não é
# luxo — este script é o único que ESCREVE layout, e conferir depois é caro.
DRY_RUN=0
APRENDER=0
_args=()
for _a in ${@+"$@"}; do
    case "$_a" in
        --dry-run|-n) DRY_RUN=1 ;;
        --aprender)   APRENDER=1 ;;
        *) _args+=("$_a") ;;
    esac
done
set -- ${_args[@]+"${_args[@]}"}

VERSION="1.8.12"

# ── Como o destino de cada repositório é decidido ─────────────────────────────
# A meta é NÃO precisar de manutenção manual quando a lista de repositórios muda.
# Repositório novo cai numa regra sozinho; só o que nenhuma regra alcança entra no
# arquivo de exceções — e mesmo esse é GERADO (--aprender), não escrito à mão.
#
# Ordem de decisão:
#   1. exceção no repos-grupos.map            (gerada por --aprender)
#   2. dono de fora dos donos consultados     → GRUPO_TERCEIROS
#   3. fork                                   → GRUPO_TERCEIROS
#   4. 2+ repos com o mesmo início            → PREFIXO/
#   5. resto                                  → raiz
#
# As regras 2 e 3 não são chute: dos 13 repositórios no 000/ desta máquina, 7 são
# forks marcados na API e 6 são clones de contas de terceiros. "Terceiro" é um dado
# que o GitHub já responde — não precisava de lista.
#
# O balde chama 000/ (era 3/ até 29/07/2026, quando as pastas foram reorganizadas).
# O nome é DEFAULT daqui: máquina nova clonada com o valor velho nasceria com um
# 3/ que nenhuma outra máquina tem — e o run.sh, que pula o balde para nunca
# commitar em repo de terceiro, deixaria de reconhecê-lo.
#
# A pasta guarda o NOME COMPLETO do repo, e não o sufixo (`SHVIA/WEB`). É decisão:
# nem todo grupo nasce de prefixo — `KIDS/` junta MARTHINA-CLASS e RAFAELA-MEMORIA,
# que não têm início comum. Encurtando só os que têm, o layout misturaria dois
# estilos e o nome da pasta deixaria de dizer qual é o repositório — justamente o
# que o git_status/pull/push mostram na tela.
GRUPO_TERCEIROS="${GRUPO_TERCEIROS:-000}"
MAPA="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repos-grupos.map"

# Preenchidos antes do laço: nomes de repos que são fork, prefixos com 2+ repos, e
# as exceções lidas do mapa. Strings com uma entrada por linha — o bash do macOS é
# 3.2 e não tem array associativo.
FORKS=""
PREFIXOS_AGRUPADOS=""
EXCECOES=""

carregar_excecoes() {
    [ -f "$MAPA" ] || return 0
    # Formato: "REPO<TAB ou espaços>GRUPO"; GRUPO vazio ou "-" força a raiz.
    EXCECOES="$(grep -vE '^[[:space:]]*(#|$)' "$MAPA" || true)"
}

# Devolve o caminho de destino (relativo ao DEST_DIR) para "owner/nome".
destino_de() {
    local full="$1" owner nome grupo pfx
    owner="${full%%/*}"; nome="${full##*/}"

    # 1. exceção explícita
    grupo="$(printf '%s\n' "$EXCECOES" | awk -v n="$nome" '$1==n {print $2; exit}')"
    if [ -n "$grupo" ]; then
        [ "$grupo" = "-" ] && { printf '%s' "$nome"; return; }
        printf '%s/%s' "$grupo" "$nome"; return
    fi

    # 2. dono de fora / 3. fork → balde de terceiros
    if ! printf '%s\n' "$DONOS_LISTA" | grep -qxF "$owner" \
       || printf '%s\n' "$FORKS" | grep -qxF "$nome"; then
        printf '%s/%s' "$GRUPO_TERCEIROS" "$nome"; return
    fi

    # 4. prefixo compartilhado
    pfx="$(printf '%s' "${nome%%[-_]*}" | tr '[:lower:]' '[:upper:]')"
    if printf '%s\n' "$PREFIXOS_AGRUPADOS" | grep -qx "$pfx"; then
        printf '%s/%s' "$pfx" "$nome"; return
    fi

    # 5. raiz
    printf '%s' "$nome"
}

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
#   ./git_clone_all.sh                            (usuário do gh   → BASE)
#   ./git_clone_all.sh outro-usuario              (outro dono      → BASE)
#   ./git_clone_all.sh outro-usuario ~/x/pasta    (outro dono      → pasta escolhida)
#   ./git_clone_all.sh samirhvbr,BLUE3-ISP        (VÁRIOS donos    → BASE)
#   ./git_clone_all.sh samirhvbr,BLUE3-ISP -n     (só mostra o plano, não clona)
#   ./git_clone_all.sh samirhvbr,BLUE3-ISP --aprender  (regrava o repos-grupos.map
#                                                       a partir do layout do disco)
# Aceita VÁRIOS donos separados por vírgula. Não é luxo: o layout real abrange mais
# de uma conta — os BLUE3-* pertencem à org BLUE3-ISP, não ao usuário pessoal, e um
# "clona tudo do dono" com um dono só reproduz o disco pela metade, em silêncio.
#   ./git_clone_all.sh samirhvbr,BLUE3-ISP
OWNERS="${1:-$(gh api user --jq .login 2>/dev/null)}"
if [ -z "$OWNERS" ]; then
    echo -e "${RED}✗ Não foi possível descobrir o usuário do gh.${NC} Passe explícito: ./git_clone_all.sh <usuario>[,<outro>]"
    exit 1
fi

echo -e "${BOLD}clone_all.sh v${VERSION} — dono(s): ${OWNERS} → destino: ${DEST_DIR}${NC}"
[ "$DRY_RUN" -eq 1 ] && echo -e "${YELLOW}(--dry-run: só mostra o plano, não clona nada)${NC}"
[ "$DRY_RUN" -eq 0 ] && mkdir -p "$DEST_DIR"

# Lista TODOS os repositórios do dono (até 1000) direto da API do GitHub — assim
# não precisa manter lista fixa como o git_clone.sh. Ajuste os filtros abaixo se
# quiser incluir/excluir forks ou arquivados:
#   --no-archived   (padrão aqui: pula os arquivados)
#   --fork / --source  para restringir a forks ou só repos originais
# Captura antes de iterar para distinguir erro (usuário inexistente / gh caído)
# de "sem repositórios" — process-substitution engoliria o erro silenciosamente.
repos_raw=""
for _owner in $(printf '%s' "$OWNERS" | tr ',' ' '); do
    echo -e "${CYAN}Consultando repositórios de ${_owner}...${NC}"
    if ! _lista="$(gh repo list "$_owner" --no-archived --limit 1000 \
        --json nameWithOwner,isFork --jq '.[] | "\(.nameWithOwner)\t\(.isFork)"')"; then
        echo -e "${RED}✗ Falha ao consultar repositórios de ${_owner}.${NC} O dono existe? O gh está autenticado?"
        exit 1
    fi
    [ -n "$_lista" ] && repos_raw="$repos_raw$_lista
"
done
# Separa a coluna do fork: a lista de repos fica só com owner/nome, e FORKS guarda
# os nomes marcados. É o dado que dispensa manter lista de "o que é de terceiro".
FORKS="$(printf '%s' "$repos_raw" | awk -F'\t' '$2=="true"{sub(/.*\//,"",$1); print $1}' | sort -u || true)"
repos_raw="$(printf '%s' "$repos_raw" | cut -f1 | grep . | sort -u || true)"
DONOS_LISTA="$(printf '%s' "$OWNERS" | tr ',' '\n' | grep . || true)"
carregar_excecoes
if [ -z "$repos_raw" ]; then
    echo -e "${YELLOW}Nenhum repositório encontrado para ${OWNERS}.${NC}"
    exit 0
fi

# ── 1º passo: quais prefixos têm 2+ repositórios ─────────────────────────────
# Precisa varrer TUDO antes de decidir o destino de qualquer um: se olhássemos um
# por vez, o primeiro SHVIA-* iria para a raiz (ainda não haveria com quem agrupar)
# e o segundo para SHVIA/ — layout partido conforme a ordem da listagem.
#
# `uniq -c` em vez de array associativo: o bash do macOS é 3.2 e não tem `declare -A`.
PREFIXOS_AGRUPADOS="$(printf '%s\n' "$repos_raw" \
    | sed -E 's|^.*/||; s|[-_].*$||' \
    | tr '[:lower:]' '[:upper:]' \
    | sort | uniq -c | awk '$1 > 1 { print $2 }')"
# bash 3.2 (padrão do macOS) não tem `mapfile`; iteramos com while-read, que é
# portátil e — por ser aqui-string e não pipe — não roda em subshell, então os
# contadores abaixo persistem.
total=$(grep -c . <<< "$repos_raw")
echo -e "${BOLD}${total} repositórios encontrados.${NC}"

# ── --aprender: grava o mapa a partir do DISCO ───────────────────────────────
# O mapa deixa de ser escrito à mão e passa a ser gerado: varre o layout atual e
# registra SÓ os repositórios em que as regras discordam de onde a pasta está.
# Assim ele fica mínimo (só o genuinamente semântico, tipo KIDS/) e se auto-limpa —
# se uma regra passa a acertar sozinha, a linha some na próxima geração.
if [ "$APRENDER" -eq 1 ]; then
    echo -e "${CYAN}Lendo o layout de ${DEST_DIR}...${NC}"
    novo_mapa=""; aprendidas=0
    while IFS= read -r repo; do
        [ -z "$repo" ] && continue
        nome="${repo##*/}"
        # Onde a pasta REALMENTE está (1 ou 2 níveis).
        atual=""
        if [ -d "$DEST_DIR/$nome/.git" ]; then
            atual="$nome"
        else
            for g in "$DEST_DIR"/*/; do
                [ -d "$g$nome/.git" ] || continue
                g="${g%/}"; atual="${g##*/}/$nome"; break
            done
        fi
        [ -z "$atual" ] && continue          # não clonado aqui: nada a aprender
        esperado="$(destino_de "$repo")"
        [ "$atual" = "$esperado" ] && continue
        grupo="${atual%/*}"
        [ "$grupo" = "$atual" ] && grupo="-"  # está na raiz e a regra queria agrupar
        novo_mapa="$novo_mapa$(printf '%-32s %s' "$nome" "$grupo")
"
        aprendidas=$((aprendidas + 1))
        echo -e "   ${YELLOW}$nome${NC} → $grupo   (regra dizia: $esperado)"
    done <<< "$repos_raw"

    {
        echo "# repos-grupos.map — exceções ao agrupamento automático."
        echo "#"
        echo "# GERADO por: ./git_clone_all.sh <donos> --aprender"
        echo "# Não edite à mão sem necessidade: rode o --aprender depois de reorganizar"
        echo "# as pastas e ele grava o que as regras não acertam sozinhas."
        echo "#"
        echo "# Formato: <REPO> <GRUPO>    ('-' = forçar raiz)"
        echo "# Regras que dispensam entrada aqui: dono de fora e fork vão para ${GRUPO_TERCEIROS}/;"
        echo "# 2+ repos com o mesmo início viram PREFIXO/."
        echo ""
        printf '%s' "$novo_mapa"
    } > "$MAPA"
    echo -e "\n${GREEN}✓ ${aprendidas} exceção(ões) gravada(s) em ${MAPA}${NC}"
    exit 0
fi

ok=(); skip=(); fail=()

while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    nome="${repo##*/}"
    dest="$(destino_de "$repo")"
    target="$DEST_DIR/$dest"

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ -d "$target/.git" ]; then
            echo -e "   ${YELLOW}já está${NC}  $dest"
        else
            echo -e "   ${GREEN}clonaria${NC} $dest"
        fi
        ok+=("$dest"); continue
    fi

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