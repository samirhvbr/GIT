#!/bin/bash
# push.sh must finish the sweep whatever one repository does, push only the
# repository each folder holds, and never suggest recreating a branch the remote
# deleted. Before 1.9.8 a failing `git status` ended the sweep with exit 128 and
# no summary, an empty `.git` was taken for a repository, and a branch whose
# upstream was deleted got `git push -u origin <branch>` as its repair.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
cleanup() { chmod -R u+rwX "$WORK" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

# Hermetic git: the developer's global config and hooks stay out of the run.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

BASE="$WORK/base"
mkdir -p "$BASE/git" "$WORK/remotes"
cp "$ROOT/push.sh" "$BASE/git/push.sh"

commit() {
    printf '%s\n' "$3" >> "$1/$2"
    git -C "$1" add "$2"
    git -C "$1" commit -qm "$3"
}

# A clone of its own bare remote, with one commit ready to push.
ready() {
    local dest="$1" key="${1//\//_}"
    git init -q -b main "$WORK/seed-$key"
    commit "$WORK/seed-$key" file base
    git clone -q --bare "$WORK/seed-$key" "$WORK/remotes/$key.git"
    mkdir -p "$(dirname "$BASE/$dest")"
    git clone -q "$WORK/remotes/$key.git" "$BASE/$dest"
    commit "$BASE/$dest" file "to push"
}

ready aaa
ready GRP/inside
ready mmm
ready zzz
mkdir "$BASE/GRP/.git"                      # an empty .git: not a repository
chmod 000 "$BASE/mmm/.git/index"            # git status fails here

# A branch that tracked origin/feature, deleted on the remote and pruned locally.
ready gone
git -C "$BASE/gone" switch -qc feature
commit "$BASE/gone" file "feature work"
git -C "$BASE/gone" push -q -u origin feature
git -C "$WORK/remotes/gone.git" branch -D feature >/dev/null
git -C "$BASE/gone" fetch -q --prune

# No remote at all.
git init -q -b main "$BASE/norem"
commit "$BASE/norem" file base

status=0
out="$(bash "$BASE/git/push.sh" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')" || status=$?
chmod 600 "$BASE/mmm/.git/index"

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from push.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}
refuse() {
    [[ "$out" != *"$1"* ]] || { printf 'unexpected in push.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

[ "$status" -eq 0 ] || { printf 'push.sh exited %s\n\n%s\n' "$status" "$out" >&2; exit 1; }
expect "(6 de 6 repos)"
expect "⚠ GRP/.git ignorado: diretório sem HEAD, não é repositório"
expect "✗ o git não consegue ler este repositório"
expect "✗ upstream apagado no remoto — feature acompanhava origin/feature, que não existe mais"
expect "→ não recrie com git push -u: rode o pull.sh, que diz se o trabalho já está na principal"
expect "↷ sem remote configurado — nada a enviar"
expect "✓ OK:       GRP/inside aaa zzz"
expect "✗ Upstream apagado: gone"
expect "✗ Falhou:   mmm"
expect "↷ Sem o que enviar: norem(sem remote)"
refuse "git push -u origin feature"

# The sweep went past the unreadable repository, and the deleted branch stayed deleted.
for key in aaa GRP_inside zzz; do
    dest="${key/_//}"
    [[ "$(git -C "$WORK/remotes/$key.git" rev-parse main)" == "$(git -C "$BASE/$dest" rev-parse main)" ]] \
        || { printf '%s was not pushed\n' "$dest" >&2; exit 1; }
done
[[ -z "$(git -C "$WORK/remotes/gone.git" branch --list feature)" ]] \
    || { printf 'the deleted branch was recreated on the remote\n' >&2; exit 1; }

printf 'push sweep test: ok\n'
