#!/bin/bash
# "sem upstream" used to stand for three situations whose repairs have nothing in
# common. pull.sh must tell them apart:
#   - the branch exists on a remote under the same name: set the upstream;
#   - the branch was never published and its work is already in a remote's
#     default branch: leave it, switch to the default branch;
#   - the branch was never published and the work is nowhere else: unpublished
#     work, said as such.
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

# A bare remote cloned at BASE/GRP/$1, on main, with nothing to pull.
new_repo() {
    local name="$1" seed="$WORK/seed-$1"
    git init -q -b main "$seed"
    commit "$seed" file base
    git clone -q --bare "$seed" "$WORK/remotes/$name.git"
    git clone -q "$WORK/remotes/$name.git" "$BASE/GRP/$name"
}

# Pushed under its own name, with no upstream configured: the repair is one command.
new_repo setup
git -C "$BASE/GRP/setup" switch -qc feat
commit "$BASE/GRP/setup" file "feat 1"
git -C "$BASE/GRP/setup" push -q origin feat

# Never published, nothing on it: HEAD is an ancestor of origin/main.
new_repo landed
git -C "$BASE/GRP/landed" switch -qc topic

# The same, but a tracked file is modified: the switch is not safe.
new_repo dirty
git -C "$BASE/GRP/dirty" switch -qc topic
printf 'edit\n' >> "$BASE/GRP/dirty/file"

# Never published, and the work reached the upstream, not the fork. The push goes
# to the upstream's URL, so the clone's local upstream/main stays older than the
# work: only a fetch of that remote shows it landed.
new_repo landedup
up="$WORK/remotes/landedup-upstream.git"
git clone -q --bare "$WORK/remotes/landedup.git" "$up"
git -C "$BASE/GRP/landedup" remote add upstream "$up"
git -C "$BASE/GRP/landedup" fetch -q upstream
git -C "$BASE/GRP/landedup" switch -qc topic
commit "$BASE/GRP/landedup" file "topic 1"
git -C "$BASE/GRP/landedup" push -q "$up" topic:main

# Never published, and the work exists nowhere else.
new_repo localonly
git -C "$BASE/GRP/localonly" switch -qc wip
commit "$BASE/GRP/localonly" file "wip 1"
commit "$BASE/GRP/localonly" file "wip 2"

# Never published, and the default branch got the same patches by cherry-pick (a
# rebase merge): the hashes differ, the patches do not, and main has since edited
# the same file. `mixed` is the same with
# one more commit that never reached main, so it must not count as landed.
for name in rebased mixed; do
    new_repo "$name"
    git -C "$BASE/GRP/$name" switch -qc topic
    commit "$BASE/GRP/$name" r "$name 1"
done
commit "$BASE/GRP/rebased" r "rebased 2"
commit "$BASE/GRP/mixed" r "mixed 2"
for name in rebased mixed; do
    forge="$WORK/forge-$name"
    git clone -q "$WORK/remotes/$name.git" "$forge"
    commit "$forge" other "later work on main"
    git -C "$forge" fetch -q "$BASE/GRP/$name" topic
    if [[ "$name" == rebased ]]; then
        git -C "$forge" cherry-pick FETCH_HEAD~1 FETCH_HEAD >/dev/null
    else
        git -C "$forge" cherry-pick FETCH_HEAD~1 >/dev/null
    fi
    # Weeks later main edits the same file, so merging the branch into it would no
    # longer be a no-op: it conflicts. Only the patches still tell.
    commit "$forge" r "main edits r later"
    git -C "$forge" push -q origin main
done

out="$(bash "$BASE/git/pull.sh" | sed 's/\x1b\[[0-9;]*m//g')"

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

expect "✗ sem upstream — existe origin/feat"
expect "→ git branch --set-upstream-to=origin/feat"
expect "✗ sem upstream, já na principal — o trabalho já está em origin/main"
expect "✗ sem upstream, já na principal — o trabalho já está em upstream/main"
expect "✗ sem upstream — o trabalho já está em origin/main, mas há alterações não commitadas em 1 arquivo(s) rastreado(s)"
expect "→ git status --short — guarde ou commite as alterações antes de trocar para main"
expect "✗ sem upstream, só local — branch nunca publicada: 2 commit(s) fora de origin/main"

expect "sem upstream: GRP/dirty GRP/setup"
expect "sem upstream, já na principal: GRP/landed→main GRP/landedup→main GRP/rebased→main"
expect "sem upstream, só local: GRP/localonly GRP/mixed"

# The unpublished commit that never reached main keeps `mixed` out of the landed group.
expect "✗ sem upstream, só local — branch nunca publicada: 2 commit(s) fora de origin/main"

# The switch is offered to the three clean landed clones and to nobody else.
switches="$(grep -cF -- '→ git switch main && git pull --ff-only' <<<"$out")"
[[ "$switches" == 3 ]] || { printf 'switch offered %s times, expected 3\n\n%s\n' "$switches" "$out" >&2; exit 1; }

# Only the fetch of a default branch is allowed to touch a repository: every
# clone is still on the branch it was on, and the modified file is still modified.
for pair in setup:feat landed:topic dirty:topic landedup:topic localonly:wip rebased:topic mixed:topic; do
    [[ "$(git -C "$BASE/GRP/${pair%%:*}" branch --show-current)" == "${pair##*:}" ]] \
        || { printf '%s left branch %s\n' "${pair%%:*}" "${pair##*:}" >&2; exit 1; }
done
git -C "$BASE/GRP/dirty" diff --quiet \
    && { printf 'dirty lost its change\n' >&2; exit 1; }

printf 'pull no upstream test: ok\n'
