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
mkdir -p "$BASE/git" "$WORK/remotes" "$WORK/bin" "$WORK/gh"
cp "$ROOT/pull.sh" "$BASE/git/pull.sh"

# A fake `gh` ahead of any real one: `gh pr list -R owner/repo ...` prints the
# lines "NUMBER HEAD_OID" kept in $WORK/gh/owner__repo, one per merged pull
# request, or fails like gh does for a repository it cannot see.
cat > "$WORK/bin/gh" <<'GH'
#!/bin/bash
slug=""
while [ $# -gt 0 ]; do
    [ "$1" = "-R" ] && slug="$2"
    shift
done
f="$GH_FAKE_DIR/${slug//\//__}"
[ -f "$f" ] || exit 1
cat "$f"
GH
chmod +x "$WORK/bin/gh"
export GH_FAKE_DIR="$WORK/gh" PATH="$WORK/bin:$PATH"

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

# A contribution: the branch is pushed to the fork (origin), the pull request is
# squash-merged in the upstream, and the fork's branch is deleted. The clone
# fetched the upstream once, when it was set up, so its local upstream/main is
# older than the squash: only a fetch of that remote can show the work landed.
# $2 is "squash" (the pull request merged) or "none" (it never did).
new_contrib() {
    local name="$1" how="$2" up="$WORK/remotes/$1-upstream.git" fork="$WORK/remotes/$1.git"
    local seed="$WORK/seed-$1" dir="$WORK/forge-$1" i
    git init -q -b main "$seed"
    commit "$seed" file base
    git clone -q --bare "$seed" "$up"
    git clone -q --bare "$up" "$fork"
    git clone -q "$fork" "$BASE/GRP/$name"
    git -C "$BASE/GRP/$name" remote add upstream "$up"
    git -C "$BASE/GRP/$name" fetch -q upstream
    git -C "$BASE/GRP/$name" switch -qc feat
    for i in 1 2; do commit "$BASE/GRP/$name" file "feat $i"; done
    git -C "$BASE/GRP/$name" push -q -u origin feat
    git clone -q "$up" "$dir"
    if [[ "$how" == squash || "$how" == squash-rewrite ]]; then
        git -C "$dir" fetch -q "$fork" feat
        git -C "$dir" merge -q --squash FETCH_HEAD >/dev/null
        git -C "$dir" commit -qm "squash feat"
    fi
    [[ "$how" == squash-rewrite ]] && { printf 'rewritten upstream\n' > "$dir/file"; git -C "$dir" commit -qam "rewrite file"; }
    commit "$dir" other "later work upstream"
    git -C "$dir" push -q origin main
    git -C "$fork" branch -D feat >/dev/null
    # The remotes read as GitHub URLs (that is what `gh` is asked about) and are
    # served by the local bare repositories.
    git -C "$BASE/GRP/$name" config "url.$fork.insteadOf" "https://github.com/me/$name.git"
    git -C "$BASE/GRP/$name" config "url.$up.insteadOf" "https://github.com/up/$name.git"
    git -C "$BASE/GRP/$name" remote set-url origin "https://github.com/me/$name.git"
    git -C "$BASE/GRP/$name" remote set-url upstream "https://github.com/up/$name.git"
}

new_repo merged main 1;    forge merged main merge
new_repo squashed master 2; forge squashed master squash
new_repo unmerged main 1;  forge unmerged main none

new_contrib contrib squash
new_contrib contribopen none
new_contrib prmerged squash-rewrite
new_contrib prextra squash-rewrite

printf '7 %s\n' "$(git -C "$BASE/GRP/prmerged" rev-parse HEAD)" > "$WORK/gh/up__prmerged"
printf '8 %s\n' "$(git -C "$BASE/GRP/prextra" rev-parse HEAD~1)" > "$WORK/gh/up__prextra"

# Deleted after its plain commits were cherry-picked upstream, but the branch also
# holds a merge that added a file of its own. Not landed: that file is nowhere else.
new_repo mergecontent main 1
git -C "$BASE/GRP/mergecontent" switch -qc side
commit "$BASE/GRP/mergecontent" s "side 1"
git -C "$BASE/GRP/mergecontent" switch -q feat
git -C "$BASE/GRP/mergecontent" merge -q --no-ff --no-commit side
printf 'only in the merge\n' > "$BASE/GRP/mergecontent/evil.txt"
git -C "$BASE/GRP/mergecontent" add evil.txt
git -C "$BASE/GRP/mergecontent" commit -qm "merge side, plus a file of its own"
git -C "$BASE/GRP/mergecontent" push -q origin feat
forge="$WORK/forge-mergecontent"
git clone -q "$WORK/remotes/mergecontent.git" "$forge"
git -C "$forge" fetch -q origin feat
git -C "$forge" cherry-pick FETCH_HEAD^1~0 >/dev/null 2>&1 || true
git -C "$forge" cherry-pick FETCH_HEAD^2 >/dev/null
commit "$forge" s "later edit of s"
git -C "$forge" push -q origin main
git -C "$forge" push -q origin --delete feat

# Landed like `merged`, but the working tree is not clean. Modified tracked
# files (staged or not) make the switch unsafe; an untracked file does not.
new_repo staged main 1;    forge staged main merge
new_repo unstaged main 1;  forge unstaged main merge
new_repo untracked main 1; forge untracked main merge
printf 'edit\n' >> "$BASE/GRP/staged/file"
git -C "$BASE/GRP/staged" add file
printf 'edit\n' >> "$BASE/GRP/unstaged/file"
printf 'scratch\n' > "$BASE/GRP/untracked/scratch"

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
expect "branch apagada, já na principal: GRP/contrib→main GRP/merged→main GRP/prmerged→main GRP/squashed→master GRP/untracked→main"
expect "branch apagada, árvore suja: GRP/staged GRP/unstaged"
expect "✗ branch apagada, já na principal — o trabalho já está em upstream/main"
expect "✗ branch apagada no remoto — 2 commit(s) fora de origin/main; confira antes de trocar de branch"
expect "branch apagada no remoto: GRP/contribopen GRP/mergecontent GRP/prextra GRP/unmerged"
expect "o trabalho já está em upstream/main — PR #7 mesclado com este mesmo commit"
expect "✗ branch apagada, árvore suja — o trabalho já está em origin/main, mas há alterações não commitadas em 1 arquivo(s) rastreado(s)"
expect "→ git status --short — guarde ou commite as alterações antes de trocar para main"

# The switch command is offered to the four clean landed clones on main and to
# nobody else: contrib, merged, prmerged and untracked (squashed is on master).
switches="$(grep -cF -- '→ git switch main && git pull --ff-only' <<<"$out")"
[[ "$switches" == 4 ]] || { printf 'switch offered %s times, expected 4\n\n%s\n' "$switches" "$out" >&2; exit 1; }

# The diagnosis only reads: every clone is still on the branch it was on.
for name in contrib contribopen prmerged prextra mergecontent merged squashed unmerged staged unstaged untracked; do
    [[ "$(git -C "$BASE/GRP/$name" branch --show-current)" == feat ]] \
        || { printf '%s left branch feat\n' "$name" >&2; exit 1; }
done
git -C "$BASE/GRP/staged" diff --cached --quiet \
    && { printf 'staged lost its staged change\n' >&2; exit 1; }
git -C "$BASE/GRP/unstaged" diff --quiet \
    && { printf 'unstaged lost its change\n' >&2; exit 1; }

printf 'pull deleted branch test: ok\n'
