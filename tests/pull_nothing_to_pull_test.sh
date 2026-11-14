#!/bin/bash
# pull.sh must not call a failure what is only "nothing to pull": a repository
# with no remote configured, and one on a detached HEAD (a checkout pinned to a
# tag on purpose). Both are listed apart from "Falhou", and neither is touched.
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

seed() {
    git init -q -b main "$1"
    printf 'base\n' > "$1/file"
    git -C "$1" add file
    git -C "$1" commit -qm base
}

# A repository that was never given a remote.
seed "$BASE/GRP/a-norem"

# A clone of a remote, pinned to a tag: HEAD is detached on purpose.
seed "$WORK/seed-pinned"
git clone -q --bare "$WORK/seed-pinned" "$WORK/remotes/pinned.git"
git clone -q "$WORK/remotes/pinned.git" "$BASE/GRP/b-pinned"
git -C "$BASE/GRP/b-pinned" tag v1
git -C "$BASE/GRP/b-pinned" checkout -q --detach v1

# A repository with a branch and a remote, which must still be pulled.
seed "$WORK/seed-plain"
git clone -q --bare "$WORK/seed-plain" "$WORK/remotes/plain.git"
git clone -q "$WORK/remotes/plain.git" "$BASE/GRP/c-plain"

status=0
out="$(bash "$BASE/git/pull.sh" | sed 's/\x1b\[[0-9;]*m//g')" || status=$?

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}
refuse() {
    [[ "$out" != *"$1"* ]] || { printf 'unexpected in pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

[ "$status" -eq 0 ] || { printf 'pull.sh exited %s\n\n%s\n' "$status" "$out" >&2; exit 1; }

expect "(3 de 3 repos)"
expect "↷ sem remote configurado — nada a puxar"
expect "branch: (HEAD solto em v1)"
expect "↷ HEAD solto — não há branch para puxar"
expect "↷ Sem o que puxar: GRP/a-norem(sem remote) GRP/b-pinned(HEAD solto)"
expect "✓ OK:     GRP/c-plain"
refuse "Falhou"
refuse "not currently on a branch"
refuse "no tracking information"

# Nothing was touched: the pinned clone is still detached on the tag.
[[ -z "$(git -C "$BASE/GRP/b-pinned" branch --show-current)" ]] \
    || { printf 'b-pinned was moved onto a branch\n' >&2; exit 1; }
[[ "$(git -C "$BASE/GRP/b-pinned" rev-parse HEAD)" == "$(git -C "$BASE/GRP/b-pinned" rev-parse v1)" ]] \
    || { printf 'b-pinned left its tag\n' >&2; exit 1; }

printf 'pull nothing-to-pull test: ok\n'
