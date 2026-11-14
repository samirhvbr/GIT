#!/bin/bash
# status.sh must count a `.git` directory as a repository only when it holds a
# HEAD, as pull.sh and push.sh do. Before 1.9.8 an empty GRP/.git was listed as a
# repository and reported clean: git had walked up to whatever sat above it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

BASE="$WORK/base"
mkdir -p "$BASE/git"
cp "$ROOT/status.sh" "$BASE/git/status.sh"
for dest in solo GRP/inside; do
    git init -q -b main "$BASE/$dest"
    printf 'base\n' > "$BASE/$dest/file"
    git -C "$BASE/$dest" add file
    git -C "$BASE/$dest" commit -qm base
done
printf 'edit\n' >> "$BASE/GRP/inside/file"
mkdir "$BASE/GRP/.git"

out="$(bash "$BASE/git/status.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"
expect() { [[ "$out" == *"$1"* ]] || { printf 'missing from status.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }; }
refuse() { [[ "$out" != *"$1"* ]] || { printf 'unexpected in status.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }; }

expect "(2 de 2 repos)"
expect "⚠ GRP/.git ignorado: diretório sem HEAD, não é repositório"
expect "GRP/inside"
refuse $'── GRP\n'

printf 'status discovery test: ok\n'
