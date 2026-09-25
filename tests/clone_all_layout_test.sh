#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$(mktemp -d)"
CONFLICT="$(mktemp -d)"
trap 'rm -rf "$DEST" "$CONFLICT"' EXIT

gh() {
    case "$1 ${2:-}" in
        "auth status") return 0 ;;
        "repo list")
            printf '%s\n' \
                $'samirhvbr/EOP\tfalse' \
                $'samirhvbr/GIT\tfalse' \
                $'samirhvbr/MIGRANDO-ZIMBRA-CARBONIO\tfalse' \
                $'samirhvbr/skill-ALPHA\tfalse' \
                $'samirhvbr/skill-BETA\tfalse'
            ;;
        "repo clone")
            mkdir -p "${!#}/.git"
            ;;
        *)
            printf 'unexpected gh invocation: %s\n' "$*" >&2
            return 1
            ;;
    esac
}
export -f gh

# The legacy path must be planned, then migrated, without cloning over it.
mkdir -p "$DEST/SKILL/skill-ALPHA/.git"
dry_run="$(bash "$ROOT/clone_all.sh" samirhvbr "$DEST" --dry-run)"
[[ "$dry_run" == *"SKILL/skill-ALPHA → skills/skill-alpha"* ]]
[[ -d "$DEST/SKILL/skill-ALPHA/.git" ]]
[[ ! -e "$DEST/skills/skill-alpha" ]]

bash "$ROOT/clone_all.sh" samirhvbr "$DEST" >/dev/null

for expected in \
    "$DEST/EOP/.git" \
    "$DEST/MIGRANDO-ZIMBRA-CARBONIO/.git" \
    "$DEST/git/.git" \
    "$DEST/skills/skill-alpha/.git" \
    "$DEST/skills/skill-beta/.git"; do
    [[ -d "$expected" ]] || { printf 'missing expected clone: %s\n' "$expected" >&2; exit 1; }
done

[[ ! -e "$DEST/SKILL" ]] || { printf 'legacy SKILL directory remains\n' >&2; exit 1; }

# A canonical directory that already exists is a collision, not permission to
# overwrite or delete the legacy clone.
mkdir -p "$CONFLICT/SKILL/skill-ALPHA/.git" "$CONFLICT/skills/skill-alpha/.git"
conflict_output="$(bash "$ROOT/clone_all.sh" samirhvbr "$CONFLICT")"
[[ "$conflict_output" == *"Legacy path exists, but canonical destination also exists"* ]]
[[ -d "$CONFLICT/SKILL/skill-ALPHA/.git" ]]
[[ -d "$CONFLICT/skills/skill-alpha/.git" ]]
printf 'clone_all layout test: ok\n'
