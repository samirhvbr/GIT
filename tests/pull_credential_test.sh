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
mkdir -p "$BASE/git" "$BASE/GRP" "$WORK/bin"
cp "$ROOT/pull.sh" "$BASE/git/pull.sh"

# A transport that answers like an HTTPS remote whose credential helper gave
# nothing: git's own message, then a failure. Each clone keeps its real
# https://github.com/... URL in remote.origin.url and reaches this helper
# through url.<base>.insteadOf, so no network is touched.
cat > "$WORK/bin/git-remote-fakehttps" <<'HELPER'
#!/bin/bash
echo "fatal: could not read Username for 'https://github.com': terminal prompts disabled" >&2
exit 128
HELPER
chmod +x "$WORK/bin/git-remote-fakehttps"
export PATH="$WORK/bin:$PATH"

# A repository on `main` tracking origin/main, with $2 as the origin URL.
https_repo() {
    local dir="$BASE/GRP/$1"
    git init -q -b main "$dir"
    git -C "$dir" commit -q --allow-empty -m base
    git -C "$dir" remote add origin "$2"
    git -C "$dir" config branch.main.remote origin
    git -C "$dir" config branch.main.merge refs/heads/main
    git -C "$dir" config url.fakehttps://github.com/.insteadOf https://github.com/
}

https_repo a-private https://github.com/owner/private.git
# A credential embedded in the URL must not be printed back.
https_repo b-token https://x-access-token:SECRET123@github.com/owner/token

status=0
out="$(bash "$BASE/git/pull.sh" | sed 's/\x1b\[[0-9;]*m//g')" || status=$?

expect() {
    [[ "$out" == *"$1"* ]] || { printf 'missing from pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}
refuse() {
    [[ "$out" != *"$1"* ]] || { printf 'unexpected in pull.sh output: %s\n\n%s\n' "$1" "$out" >&2; exit 1; }
}

[ "$status" -eq 0 ] || { printf 'pull.sh exited %s\n\n%s\n' "$status" "$out" >&2; exit 1; }

expect "✗ credencial HTTPS falhou — https://github.com/owner/private.git pediu usuário e senha e nenhuma credencial serviu"
expect "→ git remote set-url origin git@github.com:owner/private.git"
expect "✗ credencial HTTPS falhou — https://github.com/owner/token pediu usuário e senha"
expect "→ git remote set-url origin git@github.com:owner/token.git"
expect "credencial HTTPS falhou: GRP/a-private GRP/b-token"
refuse "outro:"
refuse "SECRET123"

printf 'pull credential test: ok\n'
