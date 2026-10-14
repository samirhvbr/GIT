#!/bin/bash
# pull.sh must count a `.git` directory as a repository only when it holds a
# HEAD. SHVIA/.git was an empty directory: the sweep listed the group folder as
# a repo and failed it with "not a git repository".
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Hermetic git: the developer's global config and hooks stay out of the run.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

BASE="$WORK/base"
mkdir -p "$BASE/git"
cp "$ROOT/pull.sh" "$BASE/git/pull.sh"

# A clone of a bare remote that has nothing new to pull.
new_repo() {
    local dest="$1" seed="$WORK/seed-${1//\//_}"
    git init -q -b main "$seed"
    printf 'base\n' > "$seed/file"
    git -C "$seed" add file
    git -C "$seed" commit -qm base
    git clone -q --bare "$seed" "$WORK/remote-${1//\//_}.git"
    mkdir -p "$(dirname "$BASE/$dest")"
    git clone -q "$WORK/remote-${1//\//_}.git" "$BASE/$dest"
}

# Both layouts at once: a loose repository (BASE/solo) and a repository inside
# a group (BASE/GRP/inside). Finding only one of them is the silent regression.
new_repo solo
new_repo GRP/inside

# The group folder has an empty .git, and so does a folder with nothing below it.
mkdir "$BASE/GRP/.git" "$BASE/stray" "$BASE/stray/.git"

status=0
out="$(bash "$BASE/git/pull.sh" | sed 's/\x1b\[[0-9;]*m//g')" || status=$?

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}
refuse() {
    [[ "$out" != *"$1"* ]] || { printf 'unexpected in pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

[ "$status" -eq 0 ] || { printf 'pull.sh exited %s\n\n%s\n' "$status" "$out" >&2; exit 1; }

expect "(2 de 2 repos)"
expect "⚠ GRP/.git ignorado: diretório sem HEAD, não é repositório"
expect "⚠ stray/.git ignorado: diretório sem HEAD, não é repositório"
expect "✓ OK:     GRP/inside solo"
refuse "Falhou"
refuse "not a git repository"

printf 'pull discovery test: ok\n'
