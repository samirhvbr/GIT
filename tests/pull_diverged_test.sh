#!/bin/bash
# "divergiu do remoto" used to stand for two situations that need opposite
# answers. pull.sh must tell them apart, and say what the real one is made of:
#   - every commit of the branch already has its patch in the upstream (a rebase
#     merge, a cherry-pick, a force-pushed rewrite): nothing is at risk, only the
#     history differs;
#   - some commits exist nowhere else: a real divergence, which needs a person.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Hermetic git: the developer's global config and hooks stay out of the run.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

BASE="$WORK/base"
mkdir -p "$BASE/git" "$WORK/remotes"
cp "$ROOT/pull.sh" "$BASE/git/pull.sh"

commit() {
    local dir="$1" file="$2" text="$3"
    printf '%s\n' "$text" >> "$dir/$file"
    git -C "$dir" add "$file"
    git -C "$dir" commit -qm "$text"
}

new_repo() {
    local name="$1" seed="$WORK/seed-$1"
    git init -q -b main "$seed"
    commit "$seed" file base
    git clone -q --bare "$seed" "$WORK/remotes/$name.git"
    git clone -q "$WORK/remotes/$name.git" "$BASE/GRP/$name"
}

# The remote gets the last $3 commits of the local branch by cherry-pick, after a
# commit of its own, and main then edits the same file the commits touch, so
# merging the branch into it conflicts and only the patches still tell. For the
# branch that IS main this is a force-push: the remote rewrote its history.
land() {
    local name="$1" local_ref="$2" count="$3" forge="$WORK/forge-$1"
    git clone -q "$WORK/remotes/$name.git" "$forge"
    git -C "$forge" fetch -q "$BASE/GRP/$name" "$local_ref"
    commit "$forge" other "remote work"
    git -C "$forge" cherry-pick "FETCH_HEAD~$((count - 1))^..FETCH_HEAD" >/dev/null
    commit "$forge" r "remote edits r later"
    git -C "$forge" push -q --force origin main
}

# A feature branch whose two commits were rebased into main, and which still
# tracks main by mistake: the repair is to leave it and switch.
new_repo rebased
git -C "$BASE/GRP/rebased" switch -qc topic
commit "$BASE/GRP/rebased" r "topic 1"
commit "$BASE/GRP/rebased" r "topic 2"
git -C "$BASE/GRP/rebased" branch -q --set-upstream-to=origin/main topic
land rebased topic 2

# The branch IS main, and the remote rewrote history with the same two patches.
new_repo samename
commit "$BASE/GRP/samename" r "main 1"
commit "$BASE/GRP/samename" r "main 2"
land samename main 2

# The same, with a tracked file modified: `git rebase` would refuse.
new_repo dirty
commit "$BASE/GRP/dirty" r "main 1"
commit "$BASE/GRP/dirty" r "main 2"
land dirty main 2
printf 'edit\n' >> "$BASE/GRP/dirty/file"

# A real divergence: two local commits that exist nowhere else, one new on the remote.
new_repo real
commit "$BASE/GRP/real" r "local 1"
commit "$BASE/GRP/real" r "local 2"
forge="$WORK/forge-real"
git clone -q "$WORK/remotes/real.git" "$forge"
commit "$forge" other "remote only"
git -C "$forge" push -q origin main

# An integration branch whose only commit of its own is a merge of a contribution
# that the upstream merged too and then reverted (Netflix-API in the 14/11/2026
# sweep). Merging the branch into main would change nothing, because main already
# "has" the contribution; but the work is NOT in main, the maintainer took it out.
# Calling that landed would hide the maintainer's decision.
new_repo reverted
git -C "$BASE/GRP/reverted" switch -qc qa
forge="$WORK/forge-reverted"
git clone -q "$WORK/remotes/reverted.git" "$forge"
git -C "$forge" switch -qc c1
commit "$forge" feature "contribution"
git -C "$forge" push -q origin c1
git -C "$forge" switch -q main
git -C "$forge" merge -q --no-ff --no-edit c1
git -C "$forge" revert -m 1 --no-edit HEAD >/dev/null
git -C "$forge" push -q origin main
git -C "$BASE/GRP/reverted" fetch -q origin c1
git -C "$BASE/GRP/reverted" merge -q --no-ff --no-edit origin/c1
git -C "$BASE/GRP/reverted" branch -q --set-upstream-to=origin/main qa

out="$(bash "$BASE/git/pull.sh" | sed 's/\x1b\[[0-9;]*m//g')"

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

expect "✗ divergiu, já no remoto — o trabalho já está em origin/main"
expect "→ git switch main && git pull --ff-only"
expect "✗ divergiu, já no remoto — os 2 commit(s) locais já estão em origin/main; só o histórico divergiu (4 no remoto)"
expect "→ git rebase — descarta só os commits locais que origin/main já tem"
expect "✗ divergiu do remoto — os 2 commit(s) locais já estão em origin/main, mas há alterações não commitadas em 1 arquivo(s) rastreado(s)"
expect "→ git status --short — guarde ou commite as alterações antes do rebase"
expect "✗ divergiu do remoto — 2 commit(s) local, 1 no remoto; 2 de 2 sem equivalente em origin/main (git cherry)"
expect "✗ divergiu do remoto — 1 commit(s) local, todos merges; 2 no remoto"

expect "divergiu, já no remoto: GRP/rebased→main GRP/samename"
expect "divergiu do remoto: GRP/dirty GRP/real GRP/reverted"

# The diagnosis only reads: no clone moved, and the modified file is still modified.
for pair in rebased:topic samename:main dirty:main real:main reverted:qa; do
    [[ "$(git -C "$BASE/GRP/${pair%%:*}" branch --show-current)" == "${pair##*:}" ]] \
        || { printf '%s left branch %s\n' "${pair%%:*}" "${pair##*:}" >&2; exit 1; }
done
[[ "$(git -C "$BASE/GRP/real" rev-list --count HEAD)" == 3 ]] \
    || { printf 'real lost a commit\n' >&2; exit 1; }
git -C "$BASE/GRP/dirty" diff --quiet \
    && { printf 'dirty lost its change\n' >&2; exit 1; }

printf 'pull diverged test: ok\n'
