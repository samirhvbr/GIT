#!/bin/bash
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

# A bare remote whose default branch is $2, cloned at BASE/GRP/$1 and sitting
# on branch `feat` with $3 commits pushed to the remote.
new_repo() {
    local name="$1" def="$2" commits="$3" seed="$WORK/seed-$1" i
    git init -q -b "$def" "$seed"
    commit "$seed" file base
    git clone -q --bare "$seed" "$WORK/remotes/$name.git"
    git clone -q "$WORK/remotes/$name.git" "$BASE/GRP/$name"
    git -C "$BASE/GRP/$name" switch -qc feat
    for i in $(seq "$commits"); do commit "$BASE/GRP/$name" file "feat $i"; done
    git -C "$BASE/GRP/$name" push -q -u origin feat
}

# What the forge does: land (or not) the branch, move the default branch
# forward, and delete the branch.
forge() {
    local name="$1" def="$2" how="$3" dir="$WORK/forge-$1"
    git clone -q "$WORK/remotes/$name.git" "$dir"
    case "$how" in
        merge)  git -C "$dir" merge -q --no-ff --no-edit origin/feat ;;
        squash) git -C "$dir" merge -q --squash origin/feat >/dev/null
                git -C "$dir" commit -qm "squash feat" ;;
        none)   ;;
    esac
    commit "$dir" other "later work on $def"
    git -C "$dir" push -q origin "$def"
    git -C "$dir" push -q origin --delete feat
}

new_repo merged main 1;    forge merged main merge
new_repo squashed master 2; forge squashed master squash
new_repo unmerged main 1;  forge unmerged main none

# The squash case also drops the local origin/HEAD, so the default branch has
# to come from the remote itself.
git -C "$BASE/GRP/squashed" remote set-head origin -d

out="$(bash "$BASE/git/pull.sh" | sed 's/\x1b\[[0-9;]*m//g')"

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

expect "✗ branch apagada, já na principal — o trabalho já está em origin/main"
expect "✗ branch apagada, já na principal — o trabalho já está em origin/master"
expect "→ git switch master && git pull --ff-only"
expect "✗ branch apagada no remoto — 1 commit(s) fora de origin/main; confira antes de trocar de branch"
expect "branch apagada, já na principal: GRP/merged→main GRP/squashed→master"
expect "branch apagada no remoto: GRP/unmerged"

# The diagnosis only reads: every clone is still on the branch it was on.
for name in merged squashed unmerged; do
    [[ "$(git -C "$BASE/GRP/$name" branch --show-current)" == feat ]] \
        || { printf '%s left branch feat\n' "$name" >&2; exit 1; }
done

printf 'pull deleted branch test: ok\n'
