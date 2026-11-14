#!/bin/bash
# pull.sh v1.9.8
set -euo pipefail

VERSION="1.9.8"

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
#
# A `.git` directory counts only when it holds a HEAD. An empty one is not a
# repository: SHVIA/.git was exactly that (no HEAD, no objects), so the sweep
# listed the group folder as a repo and failed it with "not a git repository".
# Such a folder is reported and skipped; the repositories below it are still found.
ACHADOS=(); VAZIOS=""
while IFS= read -r gitdir; do
    repo="${gitdir%/.git}"
    if [ ! -e "$gitdir/HEAD" ]; then
        VAZIOS="$VAZIOS${repo#"$BASE"/}
"
        continue
    fi
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
while IFS= read -r vazio; do
    if [ -n "$vazio" ]; then
        echo -e "${YELLOW}  ⚠ $vazio/.git ignorado: diretório sem HEAD, não é repositório${NC}"
    fi
done <<< "$VAZIOS"

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

# Every network call the diagnosis adds runs without a prompt. Those calls reach
# remotes the sweep's own `git pull` never touched — a fork deleted on GitHub that
# answers HTTPS with a credential prompt, an SSH host that asks about its key or
# never answers — and a sweep that waits on a terminal nobody is watching never
# ends. A `core.sshCommand` or `GIT_SSH_COMMAND` the person set is left alone.
diag_net() {
    if [ -z "${GIT_SSH_COMMAND:-}" ] && [ -z "$(git config --get core.sshCommand 2>/dev/null)" ]; then
        GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=10' "$@"
    else
        GIT_TERMINAL_PROMPT=0 "$@"
    fi
}

# The remote's default branch, from the local origin/HEAD, then from the
# remote itself, then by the two names in use. Empty when none of them answers.
default_branch() {
    local remote="$1" ref
    if ref=$(git symbolic-ref --quiet --short "refs/remotes/$remote/HEAD" 2>/dev/null); then
        echo "${ref#"$remote"/}"; return 0
    fi
    ref=$(diag_net git ls-remote --symref "$remote" HEAD 2>/dev/null \
          | awk '$1 == "ref:" { sub("^refs/heads/", "", $2); print $2; exit }')
    if [ -n "$ref" ]; then echo "$ref"; return 0; fi
    for ref in main master; do
        if git rev-parse --verify --quiet "refs/remotes/$remote/$ref" >/dev/null; then
            echo "$ref"; return 0
        fi
    done
    return 0
}

# How many non-merge commits of HEAD that $1 lacks were applied in $1 and then
# reverted there: the reverse of their patch is itself a commit of $1. `git cherry`
# marks such a commit as present, because the forward patch is there too, while
# the work is gone. Read-only; prints a number.
reverted_upstream() {
    local up c rev n=0
    up=$(git log -p --no-merges "$1" --not HEAD 2>/dev/null | git patch-id --stable 2>/dev/null | cut -d' ' -f1)
    if [ -n "$up" ]; then
        for c in $(git rev-list --no-merges HEAD --not "$1" 2>/dev/null); do
            rev=$(git diff "$c" "$c~1" 2>/dev/null | git patch-id --stable 2>/dev/null | cut -d' ' -f1)
            if [ -n "$rev" ] && grep -qxF "$rev" <<<"$up"; then n=$((n + 1)); fi
        done
    fi
    echo "$n"
}

# True only when the work of HEAD is in $1 as patches, with nothing that a patch
# comparison cannot see. Every commit of HEAD that $1 lacks must be a non-merge
# commit with a patch-equivalent in $1 (`git cherry`), there must be at least one,
# and none of them may have been reverted in $1 afterwards.
#
# Merges are refused outright. A merge can carry content of its own — a conflict
# resolution, a file added while merging — and `git cherry` does not judge merge
# commits; `git rebase` drops them. The 1.9.7 version accepted a branch whose
# plain commits matched and printed `git rebase` as the repair, and in the
# 14/11/2026 review following that hint deleted a file the merge had added. A
# patch applied and then reverted upstream was the other hole: the work is not
# there, and the rebase would drop the local commit too.
patches_in() {
    local ahead nm out
    ahead=$(git rev-list --count HEAD --not "$1" 2>/dev/null) || return 1
    nm=$(git rev-list --no-merges --count HEAD --not "$1" 2>/dev/null) || return 1
    [ "$ahead" -gt 0 ] && [ "$ahead" -eq "$nm" ] || return 1
    out=$(git cherry "$1" HEAD 2>/dev/null) || return 1
    [ -n "$out" ] || return 1
    ! grep -q '^+' <<<"$out" || return 1
    [ "$(reverted_upstream "$1")" -eq 0 ]
}

# Is the work of HEAD already in $1, a remote-tracking ref? It is when HEAD is an
# ancestor of it; or when merging HEAD into it would not change its tree, which
# is what a squash merge leaves behind the day after; or when every commit of HEAD
# has its patch there (patches_in), which is what a rebase merge leaves behind
# and keeps leaving as the branch moves on. Read-only.
landed_in() {
    local ref="$1" ahead tree
    ahead=$(git rev-list --count HEAD --not "$ref" 2>/dev/null) || return 1
    [ "$ahead" -eq 0 ] && return 0
    if tree=$(git merge-tree --write-tree "$ref" HEAD 2>/dev/null) \
       && [ "$tree" = "$(git rev-parse "$ref^{tree}")" ]; then
        return 0
    fi
    patches_in "$ref"
}

# Looks for the work of HEAD in the default branch of the tracking remote ($2)
# first and then in every other remote. A contribution does not land in the fork
# its branch was pushed to: the pull request is merged in the upstream, usually
# by squash, and the fork's branch is deleted afterwards. Comparing only with the
# tracking remote called nine such clones "N commit(s) fora de origin/main" in the
# 14/11/2026 sweep, when the pull request had merged with the very commit at HEAD.
#
# A local upstream/main is only as new as the last fetch from that remote, which
# for a contribution clone is the day it was set up, so the default branch of each
# remote is fetched here before the comparison. Only that one branch, never a
# prune. The remote in $3 is skipped: the pull that failed has just fetched it.
#
# Sets lrem/ldef and returns 0 when some remote holds the work. Either way
# prem/pdef/pahead describe the tracking remote, for the "N commit(s) fora de"
# message of the caller; pahead stays empty when that cannot be measured.
find_landing() {
    local branch="$1" first="$2" fresh="$3" rem def
    lrem=""; ldef=""; prem="$first"; pdef=""; pahead=""
    for rem in $first $(git remote 2>/dev/null | grep -vxF "$first" || true); do
        [ -n "$rem" ] || continue
        def=$(default_branch "$rem")
        [ "$rem" = "$first" ] && pdef="$def"
        [ -n "$def" ] && [ "$def" != "$branch" ] || continue
        if [ "$rem" != "$fresh" ]; then
            # Explicit destination AND an empty --refmap: without the latter git also
            # applies the remote's configured refspec, and a mirror-style one
            # (+refs/*:refs/*) would force-move the local branch of the same name.
            diag_net git fetch --quiet --no-tags --refmap= "$rem" \
                "+refs/heads/$def:refs/remotes/$rem/$def" >/dev/null 2>&1 || true
        fi
        git rev-parse --verify --quiet "refs/remotes/$rem/$def" >/dev/null || continue
        if [ "$rem" = "$first" ]; then
            pahead=$(git rev-list --count HEAD --not "$rem/$def" 2>/dev/null || true)
        fi
        if landed_in "$rem/$def"; then lrem="$rem"; ldef="$def"; return 0; fi
    done
    return 1
}

# The last resort for a branch deleted on the remote, when git alone cannot tell
# but the forge can. A pull request merged by squash, or rebased after the default
# branch had moved on, leaves no commit at HEAD in the history and no tree that
# still compares equal, and in that state a clone that pulls weeks later looks
# unmerged: zapfast, projectfw and repodocs did, in the 14/11/2026 sweep. The pull
# request itself still records the head commit it was merged with. When `gh` is
# installed and logged in, every GitHub remote is asked for merged pull requests
# from this branch, and the work counts as landed only when one of them was merged
# with exactly the commit at HEAD: a branch with commits made after the merge does
# not. Sets lrem/ldef/lpr. Silent, and a plain "no", when `gh` is missing or no
# remote is on GitHub.
landed_by_pr() {
    local branch="$1" head rem url slug def num oid
    command -v gh >/dev/null 2>&1 || return 1
    head=$(git rev-parse HEAD 2>/dev/null) || return 1
    lrem=""; ldef=""; lpr=""
    for rem in $(git remote 2>/dev/null); do
        url=$(git config --get "remote.$rem.url" 2>/dev/null) || continue
        case "$url" in
            git@github.com:*)       slug="${url#git@github.com:}" ;;
            ssh://git@github.com/*) slug="${url#ssh://git@github.com/}" ;;
            https://github.com/*)   slug="${url#https://github.com/}" ;;
            *) continue ;;
        esac
        slug="${slug%.git}"; slug="${slug%/}"
        def=$(default_branch "$rem")
        [ -n "$def" ] || continue
        while read -r num oid; do
            if [ -n "$oid" ] && [ "$oid" = "$head" ]; then
                lrem="$rem"; ldef="$def"; lpr="$num"; return 0
            fi
        done < <(GH_PROMPT_DISABLED=1 gh pr list -R "$slug" --state merged --head "$branch" --limit 10 \
                     --json number,headRefOid --jq '.[] | [.number, .headRefOid] | @tsv' 2>/dev/null || true)
    done
    return 1
}

# The work of HEAD is already in $1/$2, and the repair is a `git switch`. Whether
# that is safe depends on the working tree, not on the commits: with modified
# tracked files (staged or not) the switch either refuses or carries them onto the
# default branch. So a landed branch whose tracked files are modified gets the
# reason in $4 and no switch command; a clean one gets the reason in $3. Untracked
# files are not counted; they only matter if they collide, and the switch says so.
# Read-only; sets `motivo`, `detalhe`, `dica`, `alvo`.
mark_landed() {
    local rem="$1" def="$2" sujos
    sujos=$(git status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
    if [ "${sujos:-0}" -gt 0 ]; then
        motivo="$4"
        detalhe="o trabalho já está em $rem/$def, mas há alterações não commitadas em $sujos arquivo(s) rastreado(s)"
        dica="git status --short — guarde ou commite as alterações antes de trocar para $def"
    else
        motivo="$3"
        detalhe="o trabalho já está em $rem/$def"
        dica="git switch $def && git pull --ff-only"
        alvo="→$def"
    fi
}

# A branch deleted on the remote is usually a branch whose pull request merged and
# was cleaned up: nothing is at risk, and the repair is to leave it. The other
# case, a branch deleted with commits no default branch ever received, needs a
# person. Both used to wear the same "branch apagada" label, so the summary could
# not say which repair each repo needed. When the work is nowhere, the commits are
# counted against the tracking remote and nothing is claimed. Read-only apart from
# the fetch in find_landing and the question to the forge in landed_by_pr; sets
# `motivo`, `detalhe`, `dica`, `alvo`.
diagnose_deleted_branch() {
    local branch="$1" remote
    motivo="branch apagada no remoto"; detalhe=""; dica=""; alvo=""
    remote=$(git config "branch.$branch.remote" 2>/dev/null || echo origin)
    if find_landing "$branch" "$remote" "$remote"; then
        mark_landed "$lrem" "$ldef" "branch apagada, já na principal" "branch apagada, árvore suja"
    elif landed_by_pr "$branch"; then
        mark_landed "$lrem" "$ldef" "branch apagada, já na principal" "branch apagada, árvore suja"
        detalhe="$detalhe — PR #$lpr mesclado com este mesmo commit"
    elif [ -n "$pahead" ] && [ -n "$pdef" ]; then
        detalhe="$pahead commit(s) fora de $prem/$pdef; confira antes de trocar de branch"
    fi
    return 0
}

# A branch with no upstream has nothing to pull, and "sem upstream" used to stand
# for three situations whose repairs have nothing in common. The branch exists on
# a remote under its own name: the repair is `git branch --set-upstream-to`. The
# branch was never published and its work is already in some remote's default
# branch: the repair is to leave it, as with a deleted one. Or the branch was
# never published and the work is nowhere else, which is not a pull failure at
# all but the one thing the list should keep in sight.
#
# The same-name lookup reads local refs only. The pull that failed did not fetch
# (git refuses before it gets that far), so those refs may be old, and a hint to
# set an upstream is cheap to be wrong about; the landing check does fetch, in
# find_landing, because a claim that the work is safe must not rest on old refs.
# Sets `motivo`, `detalhe`, `dica`, `alvo`.
diagnose_no_upstream() {
    local branch="$1" rem first
    motivo="sem upstream"; detalhe=""; dica=""; alvo=""
    for rem in $(git remote 2>/dev/null); do
        if git rev-parse --verify --quiet "refs/remotes/$rem/$branch" >/dev/null; then
            detalhe="existe $rem/$branch"
            dica="git branch --set-upstream-to=$rem/$branch"
            return 0
        fi
    done
    first=$(git remote 2>/dev/null | grep -xF origin || git remote 2>/dev/null | head -n 1)
    if find_landing "$branch" "$first" ""; then
        mark_landed "$lrem" "$ldef" "sem upstream, já na principal" "sem upstream"
    else
        motivo="sem upstream, só local"
        if [ -n "$pahead" ] && [ -n "$pdef" ]; then
            detalhe="branch nunca publicada: $pahead commit(s) fora de $prem/$pdef"
        fi
    fi
    return 0
}

# "divergiu do remoto" stood for two situations that need opposite answers. Every
# non-merge commit of the branch may already have its patch in the upstream (a
# rebase merge, a cherry-pick, a force-pushed rewrite): nothing is at risk and only
# the history differs, which is what b3dev_janelinha_project was in the 14/11/2026
# sweep, five commits all present in origin/master on a branch that tracked master
# by mistake. Or some commits exist nowhere else, which is a real divergence and
# needs a person; there the message gives the numbers the bare label did not.
#
# Only the patches count here, not the tree comparison that landed_in also makes.
# Merging HEAD into the upstream changes nothing when the upstream merged the same
# work and then reverted it, and that is not "already there": Netflix-API's QA
# branch merged three contributions that the maintainer took out again, and a
# label saying the work had landed would have hidden that decision. Merge commits
# are not judged by `git cherry`, so they are counted and named, never claimed.
#
# Landed on a branch with a name of its own, the repair is to leave it and switch
# to the branch it tracks. Landed on the branch that IS the upstream (a stale copy
# of a history the remote rewrote), `git rebase` drops exactly the commits the
# upstream already has; with modified tracked files it would refuse, so those get
# the base reason and the status hint. Read-only; sets `motivo`, `detalhe`, `dica`,
# `alvo`.
diagnose_diverged() {
    local branch="$1" up rem ubr ahead behind nm novos sujos merges rv
    motivo="divergiu do remoto"; detalhe=""; dica=""; alvo=""
    up=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || return 0
    read -r ahead behind < <(git rev-list --left-right --count "HEAD...$up" 2>/dev/null) || return 0
    nm=$(git rev-list --no-merges --count HEAD --not "$up" 2>/dev/null || echo 0)
    rem="${up%%/*}"; ubr="${up#*/}"
    if patches_in "$up"; then
        if [ "$ubr" != "$branch" ]; then
            mark_landed "$rem" "$ubr" "divergiu, já no remoto" "divergiu do remoto"
        else
            sujos=$(git status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
            if [ "${sujos:-0}" -gt 0 ]; then
                detalhe="os $nm commit(s) locais já estão em $up, mas há alterações não commitadas em $sujos arquivo(s) rastreado(s)"
                dica="git status --short — guarde ou commite as alterações antes do rebase"
            else
                motivo="divergiu, já no remoto"
                detalhe="os $nm commit(s) locais já estão em $up; só o histórico divergiu ($behind no remoto)"
                dica="git rebase — descarta só os commits locais que $up já tem"
            fi
        fi
    elif [ "$nm" -eq 0 ]; then
        detalhe="$ahead commit(s) local, todos merges; $behind no remoto"
    else
        novos=$(git cherry "$up" HEAD 2>/dev/null | grep -c '^+' || true)
        merges=$((ahead - nm)); rv=$(reverted_upstream "$up")
        detalhe="$ahead commit(s) local, $behind no remoto; $novos de $nm sem equivalente em $up (git cherry)"
        if [ "${rv:-0}" -gt 0 ]; then detalhe="$detalhe; $rv aplicado(s) e depois revertido(s) no remoto"; fi
        if [ "$merges" -gt 0 ]; then detalhe="$detalhe — mais $merges merge(s), que o git cherry não compara"; fi
    fi
    return 0
}

# An operation git stopped halfway, by name: rebase, merge, cherry-pick, revert,
# bisect, or `am` (which shares rebase-apply). Prints nothing when there is none.
operation_in_progress() {
    local item marker label p
    for item in "rebase-merge:rebase" "rebase-apply:rebase ou am" "MERGE_HEAD:merge" \
                "CHERRY_PICK_HEAD:cherry-pick" "REVERT_HEAD:revert" "BISECT_LOG:bisect"; do
        marker=${item%%:*}; label=${item#*:}
        p=$(git rev-parse --git-path "$marker" 2>/dev/null) || continue
        if [ -e "$p" ]; then printf '%s\n' "$label"; return 0; fi
    done
    return 0
}

ok=(); fail=(); fail_reason=(); fail_alvo=(); skipped=(); parados=()

for repo in "${REPOS[@]}"; do
    echo -e "\n${CYAN}${BOLD}── $repo${NC}"

    if casa "$repo" "$EXCLUDE"; then
        echo -e "   ${YELLOW}↷ pulado (-d)${NC}"
        skipped+=("$repo"); continue
    fi

    if ! cd "$BASE/$repo" 2>/dev/null; then
        echo -e "${RED}  ✗ Diretório não encontrado${NC}"
        fail+=("$repo"); fail_reason+=("diretório não encontrado"); fail_alvo+=(""); continue
    fi

    branch=$(git branch --show-current 2>/dev/null || echo "?")

    # Two repositories have nothing to pull, and neither is a failure: one with
    # no remote configured (there is nowhere to pull from), and one on a detached
    # HEAD (there is no branch to advance). A checkout pinned to a tag on purpose,
    # like strix-build, used to land in "outro" with git's own "You are not
    # currently on a branch", and a repository with no remote in "sem upstream".
    # They are listed apart, so the failure list keeps only what a person has to
    # repair. A "?" branch means git itself failed here; that stays a failure.
    # An operation stopped halfway is the opposite of "nothing to pull": it is
    # unfinished work, often with conflicts resolved only in the index. 1.9.7 filed
    # a rebase stopped by a conflict (HEAD detached) under "Sem o que puxar", next to
    # a tag pinned on purpose; it is a failure, by name, before any other check.
    op=$(operation_in_progress)
    if [ -n "$op" ]; then
        echo -e "   branch: ${YELLOW}${branch:-(HEAD solto)}${NC}"
        echo -e "   ${RED}✗ operação em andamento — $op parado no meio; termine ou aborte antes de puxar${NC}"
        fail+=("$repo"); fail_reason+=("operação em andamento"); fail_alvo+=(""); continue
    fi

    if [ "$branch" != "?" ] && [ -z "$(git remote 2>/dev/null)" ]; then
        echo -e "   branch: ${YELLOW}$branch${NC}"
        echo -e "   ${YELLOW}↷ sem remote configurado — nada a puxar${NC}"
        parados+=("$repo(sem remote)"); continue
    fi
    if [ -z "$branch" ]; then
        solto=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "?")
        echo -e "   branch: ${YELLOW}(HEAD solto em $solto)${NC}"
        # Pinned on purpose only when some branch, remote-tracking ref or tag holds
        # the commit; commits only HEAD reaches go to the reflog on the next switch.
        orfaos=$(git rev-list --count HEAD --not --branches --remotes --tags 2>/dev/null || echo "?")
        if [ "$orfaos" = 0 ]; then
            echo -e "   ${YELLOW}↷ HEAD solto — não há branch para puxar${NC}"
            parados+=("$repo(HEAD solto)"); continue
        fi
        echo -e "   ${RED}✗ HEAD solto, commits fora de refs — $orfaos commit(s) só alcançável(is) pelo HEAD; crie uma branch antes de trocar${NC}"
        echo -e "   ${GREEN}→ git switch -c <nome>${NC}"
        fail+=("$repo"); fail_reason+=("HEAD solto, commits fora de refs"); fail_alvo+=(""); continue
    fi
    echo -e "   branch: ${YELLOW}$branch${NC}"

    # The output is captured instead of streamed because classify_fail reads it.
    # `set -e` stays suspended inside the `if` condition, so a failed pull does
    # not abort the sweep.
    if out=$(git pull --ff-only 2>&1); then
        printf '%s\n' "$out" | sed 's/^/   /'
        ok+=("$repo")
    else
        printf '%s\n' "$out" | sed 's/^/   /'
        motivo=$(classify_fail "$out"); detalhe=""; dica=""; alvo=""
        if [ "$motivo" = "branch apagada no remoto" ]; then
            diagnose_deleted_branch "$branch"
        elif [ "$motivo" = "sem upstream" ]; then
            diagnose_no_upstream "$branch"
        elif [ "$motivo" = "divergiu do remoto" ]; then
            diagnose_diverged "$branch"
        fi
        echo -e "   ${RED}✗ $motivo${detalhe:+ — $detalhe}${NC}"
        if [ -n "$dica" ]; then echo -e "   ${GREEN}→ $dica${NC}"; fi
        fail+=("$repo"); fail_reason+=("$motivo"); fail_alvo+=("$alvo")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}      -gt 0 ] && echo -e "${GREEN}  ✓ OK:     ${ok[*]}${NC}"
if [ ${#fail[@]} -gt 0 ]; then
    echo -e "${RED}  ✗ Falhou: ${fail[*]}${NC}"
    # Grouped by reason: the flat list answers "which", and what is actually
    # wanted is "which repair", which is not the same for the repos on it.
    for motivo in "sem upstream" "sem upstream, já na principal" \
                  "sem upstream, só local" "branch apagada, já na principal" \
                  "branch apagada, árvore suja" \
                  "branch apagada no remoto" "divergiu, já no remoto" \
                  "divergiu do remoto" \
                  "árvore suja" "conflito" "remoto inacessível" \
                  "operação em andamento" "HEAD solto, commits fora de refs" \
                  "diretório não encontrado" "outro"; do
        linha=""; i=0
        while [ $i -lt ${#fail[@]} ]; do
            [ "${fail_reason[$i]}" = "$motivo" ] && linha="$linha ${fail[$i]}${fail_alvo[$i]}"
            i=$((i + 1))
        done
        [ -n "$linha" ] && echo -e "${RED}      ${motivo}:${NC}${linha}"
    done
fi
[ ${#skipped[@]} -gt 0 ] && echo -e "${YELLOW}  ↷ Pulado: ${skipped[*]}${NC}"
[ ${#parados[@]} -gt 0 ] && echo -e "${YELLOW}  ↷ Sem o que puxar: ${parados[*]}${NC}"
echo ""
