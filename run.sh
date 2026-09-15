#!/bin/bash
# run.sh v1.8.10 — varredura das SKILLS da casa sobre todos os repos de ~/x
#
# Por que existe: o ciclo do COMMITTER recebe os repos por argumento, então a linha
# de cron acabava com uma lista fixa de caminhos — a skill só rodava onde o cron
# apontava, e cada repo novo exigia editar a crontab. Aqui a lista é DESCOBERTA a
# cada disparo, do mesmo jeito que o git_pull.sh descobre os repos para o pull.
#
# Quem participa continua sendo decisão do repo, não deste script (SPEC §1.1 do
# COMMITTER): varremos ~/x inteiro, mas só entra no ciclo quem tem o MARCADOR na
# raiz. Sem marcador, o repo não existe para a skill.
set -euo pipefail

VERSION="1.8.10"

# BASE = pasta-mãe deste script (~/x), igual ao git_pull.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$BASE/SKILLS"

COMMITTER_CYCLE="$SKILLS_DIR/skill-COMMITTER/skill/committer/committer_cycle.py"

# Balde de terceiros — mesmo default do git_clone_all.sh. NUNCA entra na varredura:
# repo de terceiro não recebe commit automático nosso, nem por marcador esquecido.
GRUPO_TERCEIROS="${GRUPO_TERCEIROS:-000}"

usage() {
    cat <<'EOF'
uso: ./run.sh [opções] [repos-a-pular...]

  --dry-run        repassa ao ciclo: faz tudo menos commit/push
  --quiet-min N    override da janela quieta (0 desliga; uso manual/teste)
  --list           só lista quem participa e sai
  -h, --help       esta ajuda

Pular repos funciona como no git_pull.sh: caminho (SHVIA/SHVIA-WEB), nome final
(SHVIA-WEB) ou pasta-ancestral (SHVIA pula o grupo inteiro).
EOF
}

PASSTHRU=(); SKIP=(); SO_LISTA=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   PASSTHRU+=("--dry-run"); shift ;;
        --quiet-min) PASSTHRU+=("--quiet-min" "${2:?--quiet-min exige um número}"); shift 2 ;;
        --list)      SO_LISTA=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        -*)          echo "opção desconhecida: $1" >&2; usage >&2; exit 2 ;;
        *)           SKIP+=("$1"); shift ;;
    esac
done

# Cor só em terminal: no cron a saída vai para o cron.log, e escape ANSI em arquivo
# de log é ruído que atrapalha justamente na hora de ler o que falhou.
if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
    CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

should_skip() {
    local repo="$1"
    local name="${repo##*/}"
    local arg
    for arg in ${SKIP[@]+"${SKIP[@]}"}; do
        arg="${arg%/}"
        if [ "$arg" = "$repo" ] || [ "$arg" = "$name" ] || [ "${repo#"$arg"/}" != "$repo" ]; then
            return 0
        fi
    done
    return 1
}

# ── descoberta (mesma do git_pull.sh: BASE/repo e BASE/grupo/repo) ──────────────
REPOS=()
while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    repo="${repo#"$BASE"/}"
    [ "${repo%%/*}" = "$GRUPO_TERCEIROS" ] && continue
    should_skip "$repo" && continue
    REPOS+=("$repo")
done < <(find "$BASE" -maxdepth 3 -type d -name .git -prune 2>/dev/null | sort)

COMMITTER_REPOS=(); AUDITOR_REPOS=()
for repo in ${REPOS[@]+"${REPOS[@]}"}; do
    [ -f "$BASE/$repo/.committer.yml" ]      && COMMITTER_REPOS+=("$BASE/$repo")
    [ -f "$BASE/$repo/.auditor/config.yml" ] && AUDITOR_REPOS+=("$BASE/$repo")
done

echo -e "${BOLD}run.sh v${VERSION} — base: ${BASE} (${#REPOS[@]} repos varridos, ${GRUPO_TERCEIROS}/ fora)${NC}"
[ ${#SKIP[@]} -gt 0 ] && echo -e "${YELLOW}  pulando: ${SKIP[*]}${NC}"

if [ $SO_LISTA -eq 1 ]; then
    echo -e "\n${CYAN}${BOLD}── committer (.committer.yml): ${#COMMITTER_REPOS[@]}${NC}"
    for r in ${COMMITTER_REPOS[@]+"${COMMITTER_REPOS[@]}"}; do echo "   ${r#"$BASE"/}"; done
    echo -e "\n${CYAN}${BOLD}── auditor (.auditor/config.yml): ${#AUDITOR_REPOS[@]}${NC}"
    for r in ${AUDITOR_REPOS[@]+"${AUDITOR_REPOS[@]}"}; do echo "   ${r#"$BASE"/}"; done
    exit 0
fi

rc=0

# ── COMMITTER ──────────────────────────────────────────────────────────────────
# Uma invocação com TODOS os repos: o ciclo já itera, e assim o state.json é
# escrito uma vez só (invocação por repo faz cada uma reler e sobrescrever o
# arquivo — o último a terminar apagaria o que os outros gravaram).
echo -e "\n${CYAN}${BOLD}── committer${NC}  (${#COMMITTER_REPOS[@]} repos com marcador)"
if [ ${#COMMITTER_REPOS[@]} -eq 0 ]; then
    echo -e "   ${YELLOW}↷ nenhum repo com .committer.yml${NC}"
elif [ ! -f "$COMMITTER_CYCLE" ]; then
    echo -e "   ${RED}✗ ciclo não encontrado: $COMMITTER_CYCLE${NC}"
    rc=1
else
    if python3 "$COMMITTER_CYCLE" ${PASSTHRU[@]+"${PASSTHRU[@]}"} "${COMMITTER_REPOS[@]}" 2>&1 | sed 's/^/   /'; then
        echo -e "   ${GREEN}✓ ciclo concluído${NC}"
    else
        echo -e "   ${RED}✗ ciclo falhou${NC}"
        rc=1
    fi
fi

# ── AUDITOR ────────────────────────────────────────────────────────────────────
# ⛔ O AUDITOR ainda NÃO tem executor headless (skill/auditor é invocada por uma
# sessão do Claude Code, via /auditor). Enquanto isso, aqui ele só REPORTA quem
# optou — assim a lista aparece no log e o dia que o executor existir só troca
# este bloco, sem mexer na crontab.
echo -e "\n${CYAN}${BOLD}── auditor${NC}  (${#AUDITOR_REPOS[@]} repos com .auditor/config.yml)"
if [ ${#AUDITOR_REPOS[@]} -eq 0 ]; then
    echo -e "   ${YELLOW}↷ nenhum repo com .auditor/config.yml${NC}"
else
    for r in "${AUDITOR_REPOS[@]}"; do echo "   ${r#"$BASE"/}"; done
    echo -e "   ${YELLOW}↷ sem executor headless — rode /auditor numa sessão (skill-AUDITOR SPEC F5)${NC}"
fi

exit $rc