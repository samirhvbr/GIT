#!/bin/bash
# clone_all.sh v1.6.0
set -euo pipefail

# --dry-run/-n é filtrado ANTES de tudo: o destino sai de "$2", então a flag não
# pode ocupar posição. Mostrar o plano antes de criar árvore de diretórios não é
# luxo — este script é o único que ESCREVE layout, e conferir depois é caro.
DRY_RUN=0
_args=()
for _a in ${@+"$@"}; do
    case "$_a" in
        --dry-run|-n) DRY_RUN=1 ;;
        *) _args+=("$_a") ;;
    esac
done
set -- ${_args[@]+"${_args[@]}"}

VERSION="1.6.0"

# ── Agrupamento automático por prefixo ───────────────────────────────────────
# 2+ repositórios que começam igual viram uma PASTA com esse início:
#   SHVIA-WEB, SHVIA-DESKTOP, ...  →  SHVIA/SHVIA-WEB, SHVIA/SHVIA-DESKTOP
#   GIT (sozinho)                  →  GIT
#
# A pasta guarda o NOME COMPLETO do repo, e não o sufixo (`SHVIA/WEB`). É decisão:
# nem todo grupo nasce de prefixo — `KIDS/` junta MARTHINA-CLASS e RAFAELA-MEMORIA,
# que não têm início comum. Encurtando só os que têm, o layout misturaria dois
# estilos e o nome da pasta deixaria de dizer qual é o repositório — justamente o
# que o git_status/pull/push mostram na tela.
#
# EXCEÇÕES: o que a inferência não pega (grupo temático) ou pega errado (prefixo
# coincidente). Formato "REPO|GRUPO"; GRUPO vazio força a raiz.
GRUPOS_MANUAIS=(
    # Temáticos — sem prefixo comum, a inferência nunca acertaria sozinha
    "MARTHINA-CLASS|KIDS"
    "RAFAELA-MEMORIA|KIDS"
    "KIDS-CAT|KIDS"
    # Terceiros e diversos: baldes, não projetos nossos
    "ai-memory|3"
    "ai-usagebar|3"
    "github-visualize|3"
    "claude-desktop-debian|3"
    "hermes-agent|3"
    "mtzSpider|3"
    "sinalrf|3"
    "Vitals|3"
    "FrankMD|3"
    "FRANK_KARAOKE|3"
    "matomo-blue3|3"
    "MiMo-Code|3"
    "odysseus|3"
    "hermes-achievements|3"
    "CSL-Redes|3"
    "speedtest|3"
    # Da org BLUE3-ISP mas sem o prefixo no nome — a inferência os deixaria na raiz
    "BRASILEIRAO_A_2026|BLUE3"
    "MEUIP|BLUE3"
    "CNPJ|"
    "ONLINE|"
    "EOP|"
    # Prefixo coincidente: AI-BENCHMARK é nosso, ai-memory/ai-usagebar são forks —
    # sem isto os três virariam um grupo "AI/" que não quer dizer nada.
    "AI-BENCHMARK|"
    "GITHUB-DESKTOP|"
)

# Devolve o caminho de destino (relativo ao DEST_DIR) para um repositório.
# Precisa de PREFIXOS_AGRUPADOS já calculado (ver o 1º passo, mais abaixo).
destino_de() {
    local nome="$1" par repo grupo pfx
    for par in ${GRUPOS_MANUAIS[@]+"${GRUPOS_MANUAIS[@]}"}; do
        repo="${par%%|*}"; grupo="${par#*|}"
        if [ "$repo" = "$nome" ]; then
            [ -z "$grupo" ] && { printf '%s' "$nome"; return; }
            printf '%s/%s' "$grupo" "$nome"; return
        fi
    done
    pfx="$(printf '%s' "${nome%%[-_]*}" | tr '[:lower:]' '[:upper:]')"
    if printf '%s\n' "$PREFIXOS_AGRUPADOS" | grep -qx "$pfx"; then
        printf '%s/%s' "$pfx" "$nome"
    else
        printf '%s' "$nome"
    fi
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
        --json nameWithOwner --jq '.[].nameWithOwner')"; then
        echo -e "${RED}✗ Falha ao consultar repositórios de ${_owner}.${NC} O dono existe? O gh está autenticado?"
        exit 1
    fi
    [ -n "$_lista" ] && repos_raw="$repos_raw$_lista
"
done
repos_raw="$(printf '%s' "$repos_raw" | grep . | sort -u || true)"
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

ok=(); skip=(); fail=()

while IFS= read -r repo; do
    [ -z "$repo" ] && continue
    nome="${repo##*/}"
    dest="$(destino_de "$nome")"
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