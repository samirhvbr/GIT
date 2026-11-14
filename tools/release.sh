#!/usr/bin/env bash
# repodocs:tool — generated from samirhvbr/repodocs and regenerated in place.
# A copy without this line is the repository's own and is never overwritten.
# release.sh — every version in version.md gets a git tag named after it and a
# published GitHub Release.
#
# WHY THIS EXISTS: GitHub never infers a version from a commit subject. A repo
# whose history is full of `2.110.161 - …` still shows "No releases published",
# and `git diff 2.110.160..2.110.161` is impossible because neither name exists
# as a ref. The tag is what pins a version number to the exact code it named.
#
# The version is THE FIRST SEMVER IN version.md — not the whole file. Two shapes
# live in this fleet and both must read the same:
#     1.76.108                            (bare, e.g. EOP, SHVIA-WEB, repodocs)
#     # Versão — X\n**Versão atual:** `0.17.1`   (markdown, e.g. the BLUE3-ISP repos)
# That is the rule those repos already document and that config/app.php already
# implements with preg_match('/\d+\.\d+\.\d+/').
#
# Tags carry NO `v` prefix: the tag is byte-for-byte what version.md says.
#
# Idempotent and resumable by construction — anything that already exists is
# skipped, so re-running is free and an interrupted run just continues.
#
#   ./tools/release.sh --dry-run              # print the table, create nothing
#   ./tools/release.sh                        # tag+release the current version
#   ./tools/release.sh --backfill --dry-run   # the whole history, as a table
#   ./tools/release.sh --backfill             # the whole history, for real
#
# Norm: docs/versioning.md · docs/decisions.md ADR-011
set -uo pipefail

MODE=current
DRY=0
REPO=""
SLEEP=0.35          # throttle: ~2.8 req/s, well under GitHub's ceiling
RATE_FLOOR=200      # stop and report rather than exhausting the budget
REF=""             # --ref: which history to walk (default: origin's default branch). Use
                    # origin/master where the local checkout is behind and a
                    # pull is refused by in-flight work — backfilling from a
                    # stale HEAD silently omits every version pushed since.
QUIET=0             # -q: totals only, one line per repo — for fleet-wide sweeps

die() { printf 'release.sh: %s\n' "$1" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --backfill) MODE=backfill ;;
    --current)  MODE=current ;;
    --dry-run|-n) DRY=1 ;;
    --quiet|-q) QUIET=1 ;;
    --repo) REPO="${2:-}"; shift ;;
    --ref)  REF="${2:-}"; shift ;;
    --sleep) SLEEP="${2:-}"; shift ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

git rev-parse --git-dir >/dev/null 2>&1 || die "not inside a git repository"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || die "cannot cd to repo root"

[ -f version.md ] || die "no version.md at $ROOT — the fleet's version authority is missing"

# --- the version is the FIRST semver in the file, whatever shape it has -------
first_semver() { grep -oE '[0-9]+\.[0-9]+\.[0-9]+' "$1" 2>/dev/null | head -n 1; }

# THE RULE: the version.md ON GITHUB is what the Releases ON GITHUB must match.
# The local checkout does not enter the calculation — it can be behind, ahead or
# mid-work, and none of that is published. So the authority is the remote branch
# after refreshing it. A missing tracking HEAD must never select unpublished
# work from the local branch; ask origin which branch is its default.
refresh_origin() {
  local advertised default_ref tracking_ref
  advertised="$(git ls-remote --symref origin HEAD)" || die "cannot resolve origin's default branch"
  default_ref="$(printf '%s\n' "$advertised" | awk '$1 == "ref:" && $3 == "HEAD" { print $2 }')"
  case "$default_ref" in
    refs/heads/?*) ;;
    *) die "origin's HEAD does not name a branch" ;;
  esac
  git check-ref-format "$default_ref" >/dev/null 2>&1 || die "origin's default branch is invalid"
  tracking_ref="refs/remotes/origin/${default_ref#refs/heads/}"
  # Keep other configured histories fresh for --ref, then fetch the default
  # explicitly: remote.origin.fetch may exclude it and leave a stale ref behind.
  git fetch --quiet origin || die "cannot refresh origin — nothing can be inferred from stale refs"
  git fetch --quiet origin "+$default_ref:$tracking_ref" || die "cannot refresh origin's default branch"
  git symbolic-ref refs/remotes/origin/HEAD "$tracking_ref" || die "cannot update origin's tracking HEAD"
}
refresh_origin
DEFAULT_REF=refs/remotes/origin/HEAD
DEFAULT_SHA="$(git rev-parse --verify "$DEFAULT_REF^{commit}")" || die "origin's default branch does not resolve"
[ -n "$REF" ] || REF="$DEFAULT_REF"
# Pin the commit before reading version.md. Another fetch can move a tracking
# ref while release/list runs; the notes, version and target must stay together.
TARGET_SHA="$(git rev-parse --verify "$REF^{commit}")" || die "ref '$REF' does not exist"

CURRENT="$(git show "$TARGET_SHA:version.md" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
[ -n "$CURRENT" ] || die "version.md at $REF holds no X.Y.Z anywhere"
DEFAULT_VERSION="$(git show "$DEFAULT_SHA:version.md" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
[ -n "$DEFAULT_VERSION" ] || die "version.md at origin's default branch holds no X.Y.Z anywhere"

# Informational only: a local tree that disagrees is normal mid-work, and it is
# deliberately NOT published.
LOCAL_V="$(first_semver version.md)"
if [ -n "$LOCAL_V" ] && [ "$LOCAL_V" != "$CURRENT" ]; then
  printf 'release.sh: note — local version.md says %s; publishing %s from %s (the remote is the authority).\n' \
    "$LOCAL_V" "$CURRENT" "$REF" >&2
fi

# `origin`, explicitly, and only then gh's own guess. `gh repo view` with no
# argument resolves the repository from *all* the remotes by its own
# precedence: in a fork carrying an `upstream` remote it answers the upstream,
# and this script then tries to publish a Release into somebody else's
# repository. Measured in `000/hermes-agent` on 07/09/2026 — it asked
# NousResearch and got a 404. The 404 is luck. Where we hold write access to
# the second remote, it would have published to the wrong place and nothing
# would have said so.
if [ -z "$REPO" ]; then
  ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
  if [ -n "$ORIGIN_URL" ]; then
    CANDIDATE="$(printf '%s' "$ORIGIN_URL" | sed -E 's#^(git@|https://|ssh://git@)##; s#^github\.com[:/]##; s#\.git$##; s#/$##')"
    case "$CANDIDATE" in
      */*/*|"") ;;                 # not owner/name — leave it to gh
      */*) REPO="$CANDIDATE" ;;
    esac
  fi
fi
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"
fi
[ -n "$REPO" ] || die "cannot determine owner/name — pass --repo owner/name"

BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo master)"

# --- release notes ------------------------------------------------------------
# Preference: all CHANGELOG sections for this exact version at the release's
# target commit → the commit subjects that carried it → GitHub's own generated
# notes. The working tree may contain another version or unpublished edits.
# EOP has no CHANGELOG.md at all, so the fallback is not theoretical.
#
# Two heading shapes exist in this fleet, and both are matched:
#   ## 1.1.0 - título
#   ### `0.17.0` — 2026-08-24 — título
notes_for() {
  local ver="$1" sha="$2" out="$3" body="" changelog=""
  if changelog="$(git show "$sha:CHANGELOG.md" 2>/dev/null)"; then
    body="$(printf '%s\n' "$changelog" | awk -v ver="$ver" '
      # Returns the heading level (2..4), or 0 for a non-heading line.
      function hlevel(line,   m) {
        if (match(line, /^#{2,4}[ \t]/)) { m = substr(line, 1, RLENGTH); gsub(/[ \t]/, "", m); return length(m) }
        return 0
      }
      # Does this heading name our version? Backticks are stripped because the
      # fleet writes both `## 1.1.0 - x` and "### `0.17.0` - 2026-08-24 - x".
      function is_ours(line,   s) {
        s = line; sub(/^#+[ \t]*/, "", s); gsub(/`/, "", s)
        return s == ver || index(s, ver " ") == 1 || index(s, ver "\t") == 1
      }
      { lv = hlevel($0)
        # Only a heading at the SAME level or higher ends the section — the
        # entry keeps its own ### subsections, which is where the substance is.
        if (flag && lv && lv <= open_lv) flag = 0
        # Several commits may share a version; keep every matching section,
        # including those after a different version, in changelog order.
        if (!flag) {
          if (lv && is_ours($0)) {
            if (found++) print ""
            flag = 1; open_lv = lv
          }
          next
        }
        print }
    ')"
  fi
  if [ -z "$(printf '%s' "$body" | tr -d '[:space:]')" ]; then
    body="$(git log --format='- %s' --grep="^$(printf '%s' "$ver" | sed 's/\./\\./g') - " "$sha" 2>/dev/null | head -n 40)"
    [ -n "$body" ] && body="## Commits"$'\n\n'"$body"
  fi
  printf '%s\n' "$body" > "$out"
  [ -s "$out" ] && [ -n "$(tr -d '[:space:]' < "$out")" ]
}

# --- rate limit ---------------------------------------------------------------
rate_left() {
  local left
  left="$(gh api rate_limit --jq '.resources.core.remaining' 2>/dev/null)" || return 1
  case "$left" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#left}" -le 9 ] || return 1
  printf '%s\n' "$left"
}

# --- what is already published ------------------------------------------------
# Fetched ONCE per repo, not once per version. Asking `gh release view` for each
# version would cost one API call per version just to look — 2,764 calls
# fleet-wide before creating anything.
EXISTING="$(mktemp)"
trap 'rm -f "$EXISTING"' EXIT
gh release list --repo "$REPO" --limit 1000 --json tagName --jq '.[].tagName' > "$EXISTING" 2>/dev/null \
  || die "cannot list published releases — an unknown list is not an empty one"
EXISTING_N="$(grep -c . "$EXISTING" || true)"
# A version counts as published under EITHER name. Some repos in this fleet
# published Releases with a `v` prefix before the bare-number rule existed, and
# SSHVTERM-DESKTOP's carry 178 installer assets with 10k downloads. Creating a
# bare-tag Release for a version that already has a `v` one would not "fix" the
# naming — it would duplicate the version and leave the copy WITHOUT the
# binaries. The old Release stays; nothing is duplicated.
already() { grep -Fxq "$1" "$EXISTING" || grep -Fxq "v$1" "$EXISTING"; }

# --- one version --------------------------------------------------------------
CREATED=0; SKIPPED=0; FAILED=0; CONSEC_FAIL=0
publish() {
  local ver="$1" sha="$2" is_last="$3"
  if already "$ver"; then
    [ "${QUIET:-0}" = "1" ] || printf '  %-14s %s  already published — skipped\n' "$ver" "${sha:0:7}"
    SKIPPED=$((SKIPPED+1)); return 0
  fi
  if [ "$DRY" = "1" ]; then
    [ "${QUIET:-0}" = "1" ] || printf '  %-14s %s  WOULD CREATE\n' "$ver" "${sha:0:7}"
    CREATED=$((CREATED+1)); return 0
  fi

  local left
  if ! left="$(rate_left)"; then
    printf 'release.sh: STOPPING — cannot determine the remaining API budget. Re-run later.\n' >&2
    FAILED=$((FAILED+1)); return 9
  fi
  if [ "$left" -lt "$RATE_FLOOR" ]; then
    printf 'release.sh: STOPPING — only %s API calls left. Re-run later; it resumes.\n' "$left" >&2
    FAILED=$((FAILED+1)); return 9
  fi

  local nf; nf="$(mktemp)"
  local args=(release create "$ver" --repo "$REPO" --target "$sha" --title "$ver")
  if notes_for "$ver" "$sha" "$nf"; then args+=(--notes-file "$nf"); else args+=(--generate-notes); fi
  # `--latest` belongs to the version that version.md names, NOT to the last one
  # this run happens to touch. Measured the hard way: a backfill that started
  # while version.md said 1.2.80 stamped `--latest` on 1.2.80 minutes after a
  # push had moved the file to 1.2.81 — the Release for 1.2.81 existed, and the
  # badge sat on the older one.
  if [ "$ver" = "$DEFAULT_VERSION" ]; then args+=(--latest); else args+=(--latest=false); fi

  # Creating a release is a "content-creating" request, which GitHub throttles
  # far more tightly than reads — a secondary limit that answers 403 with a
  # "retry after" rather than a plain quota number. A backfill of thousands
  # WILL meet it, so meeting it politely is part of the job: back off and retry
  # rather than hammer, because hammering earns a longer block.
  local attempt=0 ok=0
  while [ "$attempt" -lt 5 ]; do
    if gh "${args[@]}" >/dev/null 2>"$nf.err"; then ok=1; break; fi
    if grep -qi 'secondary rate limit\|abuse detection\|rate limit' "$nf.err"; then
      attempt=$((attempt+1))
      local wait=$((attempt * 60))
      printf '  %-14s secondary rate limit — waiting %ss (attempt %s/5)\n' "$ver" "$wait" "$attempt" >&2
      sleep "$wait"
    else
      break
    fi
  done
  if [ "$ok" = "1" ]; then
    printf '  %-14s %s  published\n' "$ver" "${sha:0:7}"
    printf '%s\n' "$ver" >> "$EXISTING"
    CREATED=$((CREATED+1))
  else
    printf '  %-14s %s  FAILED: %s\n' "$ver" "${sha:0:7}" "$(head -n1 "$nf.err")" >&2
    FAILED=$((FAILED+1))
    # Three failures in a row is a wall, not a fluke — stop and let the operator
    # look, instead of burning the remaining budget against it.
    CONSEC_FAIL=$((CONSEC_FAIL+1))
    rm -f "$nf" "$nf.err"
    [ "$CONSEC_FAIL" -ge 3 ] && { printf 'release.sh: STOPPING after 3 consecutive failures.\n' >&2; return 9; }
    return 0
  fi
  CONSEC_FAIL=0
  rm -f "$nf" "$nf.err"
  sleep "$SLEEP"
}

[ "$QUIET" = "1" ] || printf 'repo:    %s\nbranch:  %s\nversion: %s (first semver in version.md at %s)\nmode:    %s%s\nalready: %s Release(s) published\n\n' \
  "$REPO" "$BRANCH" "$CURRENT" "$REF" "$MODE" "$([ "$DRY" = 1 ] && echo '  [DRY RUN — nothing is created]')" "$EXISTING_N"

if [ "$MODE" = "current" ]; then
  # Tag the commit the version actually lives on, on the remote. Uncommitted or
  # unpushed bumps are not published — GitHub cannot tag a commit it does not
  # have, and a Release for a version nobody can fetch is a lie.
  publish "$CURRENT" "$TARGET_SHA" 1
else
  # Oldest first, so the newest version is created last and ends up "Latest".
  # For each distinct version, the tag points at the LAST commit that carried
  # it — the finished state of that version, not its first commit. Several
  # commits sharing one version is expected and allowed (ADR-003).
  MAP="$(git log --reverse --format='%H%x09%s' "$TARGET_SHA" | awk -F'\t' '
    { if (match($2, /^[0-9]+\.[0-9]+\.[0-9]+/)) {
        v = substr($2, RSTART, RLENGTH)
        if (!(v in seen)) { order[++n] = v; seen[v] = 1 }
        last[v] = $1 } }
    END { for (i = 1; i <= n; i++) print order[i] "\t" last[order[i]] }')"
  TOTAL="$(printf '%s\n' "$MAP" | grep -c . || true)"
  [ "$QUIET" = "1" ] || printf '%s distinct version(s) in history of %s\n\n' "$TOTAL" "$REF"
  i=0
  while IFS=$'\t' read -r ver sha; do
    [ -n "$ver" ] || continue
    i=$((i+1))
    publish "$ver" "$sha" "$([ "$i" = "$TOTAL" ] && echo 1 || echo 0)" || break
  done <<< "$MAP"
fi

# Reconcile the badge against the remote AS IT IS NOW, not as it was when this
# run started. A push can land mid-run — that is not an edge case here, it is
# what happened. If the new version has no release yet, report an incomplete
# run; do not silently publish a version outside the selected history.
reconcile_latest() {
  [ "$DRY" = "1" ] && return 0
  refresh_origin
  local now
  now="$(git show "$DEFAULT_REF:version.md" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)"
  [ -n "$now" ] || { printf 'release.sh: cannot read the current remote version for Latest.\n' >&2; return 1; }
  local badge
  if ! badge="$(gh release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null)" || [ -z "$badge" ]; then
    printf 'release.sh: cannot read the Latest release.\n' >&2; return 1
  fi
  { [ "$badge" = "$now" ] || [ "$badge" = "v$now" ]; } && return 0
  local tag="$now"
  if ! grep -Fxq "$now" "$EXISTING" && grep -Fxq "v$now" "$EXISTING"; then tag="v$now"; fi
  if ! gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then
    printf 'release.sh: cannot confirm a release for remote version %s; re-run after it is published.\n' "$now" >&2
    return 1
  fi
  if ! gh release edit "$tag" --repo "$REPO" --latest >/dev/null 2>&1; then
    printf 'release.sh: cannot move Latest to %s.\n' "$tag" >&2; return 1
  fi
  local observed
  if ! observed="$(gh release view --repo "$REPO" --json tagName -q .tagName 2>/dev/null)"; then
    printf 'release.sh: cannot verify Latest after editing %s.\n' "$tag" >&2; return 1
  fi
  if [ "$observed" != "$tag" ]; then
    printf 'release.sh: Latest did not confirm %s after the edit.\n' "$tag" >&2; return 1
  fi
  printf 'release.sh: Latest moved from %s to %s (the remote version is the authority).\n' "$badge" "$tag" >&2
}
if [ "$FAILED" -eq 0 ]; then
  reconcile_latest || FAILED=$((FAILED+1))
fi
if [ "$DRY" != 1 ] && [ "$FAILED" -eq 0 ]; then
  if ! git fetch --tags --quiet origin 2>/dev/null; then
    printf 'release.sh: cannot refresh local tags after publication.\n' >&2
    FAILED=$((FAILED+1))
  fi
fi

if [ "$QUIET" = "1" ]; then
  printf '%-34s %-12s versions=%-5s todo=%-5s have=%s failed=%s\n' "$REPO" "$CURRENT" "$((CREATED+SKIPPED))" "$CREATED" "$SKIPPED" "$FAILED"
else
  printf '\ncreated/would-create: %s   skipped: %s   failed: %s\n' "$CREATED" "$SKIPPED" "$FAILED"
fi
[ "$FAILED" -eq 0 ]
