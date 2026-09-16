# Changelog

Entries in the commit-message format (`version - short description in English`),
newest first. **Each `##` heading is literally the commit subject** — the entry
is written *before* the commit, so the sentence that lands in `git log` is one
that was weighed rather than improvised at `git commit` time.

Bodies are narrative: what changed, why, and what was measured. This file is
never rewritten.

> **The record starts here.** This file was created after the repository was:
> earlier versions are in `git log` and are deliberately not back-filled, because
> reconstructing them now would produce a plausible history rather than a true
> one.

## 1.9.0 - the scripts drop the git_ prefix and take the name of what they do

`./git_pull.sh` becomes `./pull.sh`, and the same for push, status, clone,
clone_all and clone_drive — twelve files, `.sh` and `.cmd` renamed in the same
commit, as the parity contract requires.

The prefix was never information. Everything in this repository is a git
operation; `git_` repeated that in every name and bought nothing, while the
header comment inside each file had already been calling them `pull.sh`,
`push.sh` and `clone.sh` for releases. The rename makes the two agree.

## What had to move with it

The old `.gitignore` re-included exactly `!git_*`, so a rename would have made
**every script in this repository invisible to git at once** — renamed away
from the only pattern that let them in. That ordering is why `1.8.11` came
first: with the file at ordinary polarity, the rename needs nothing from it.

`README.md`, `README_br.md`, `CLAUDE.md`, `AGENTS.md`, `run.sh`,
`scripts/sync-version.sh` and `repos-grupos.map` were rewritten to the new
names. Two kinds of text were deliberately left alone: the `CHANGELOG.md`
entries below this one, and the `1.5.1 - git_status.sh: ...` line quoted in
`CLAUDE.md` as the commit-format example. That line is a subject that is really
in `git log`; history is not rewritten, and neither is a quotation of it.

`scripts/sync-version.sh` needed one more edit than a substitution. Its header
explained that the name in the comment is left untouched *because* it differed
from the filename — an explanation that survived the rename as a sentence
contradicting itself. It now says what is true: the names coincide, and the
`sed` still does not touch them because there is nothing left to correct.

**Verified:** `bash -n` on all seven `.sh` files, and
`./scripts/sync-version.sh --check` clean.

## 1.8.13 - status.cmd names the missing upstream, as status.sh already did

Parity is a contract here, and this pair had drifted. `git_status.sh` prints
`sem upstream configurado`; `git_status.cmd` ran the two `rev-list` calls,
watched both fail, kept `ahead=0` and `behind=0` and printed nothing — so a
branch that was never connected to a remote looked exactly like a branch in
sync with one. On Windows, the read-only checker was quietest about the repo
it had the least information on.

It now asks `git rev-parse @{u}` first, says `sem upstream configurado` when
there is none, and only counts ahead/behind when there is. The `behind` line
also names the upstream, the way the `.sh` does.

**Not executed: there is no Windows on this machine.** The `.sh` side is
unchanged and was already correct.

## 1.8.12 - push stops aborting the sweep at the first repo without upstream

`git_push.sh` asked how many commits were waiting with

```bash
pending=$(git log '@{u}..' --oneline 2>/dev/null | wc -l | tr -d ' ')
```

With no upstream, `git log '@{u}..'` exits 128. `pipefail` carries that past
`wc` and `tr`, the assignment inherits the pipeline's status, and `set -e` ends
the script on the spot. Reproduced on a built tree:

```
── repo_sem
   branch: master
EXIT=128          ← no message, no summary, no repos after this one
```

**Every repository later in the listing was never pushed**, and nothing on
screen said so. This is the bug `1.5.1` fixed in `git_status.sh` — *"ignora
repositório sem upstream em vez de abortar"* — never carried over to the push.

`git_push.cmd` did not die; it lied. `git log @{u}..` failed there too, `find
/c` counted zero, and the repository landed in the green list as `Nada a enviar
(up-to-date)` — with its commits still local. The comment above the line said
so out loud: *"vazio/sem upstream conta como 0"*. A branch with commits and
nowhere to send them is the case where a push matters most.

## What it does now

Both sides ask for the upstream before asking about commits. Missing, the
repository is reported with the count of local commits and the exact repair,
and the sweep moves on:

```
── repo_sem
   branch: master
   ✗ sem upstream — 2 commit(s) sem para onde ir
      conserto: git push -u origin master
```

The summary gains a `Sem upstream:` line, kept apart from `Falhou:` because the
repair is different: one is a `git push -u`, the other is whatever git refused.

**Verified on Linux against a built tree of three repositories** — one up to
date, one with two commits and no upstream, one with an upstream and a push the
remote rejected. The sweep reached all three, the successful push went through,
the rejection was counted as a failure, and the exit code was 0 as before.
**`git_push.cmd` was not executed: there is no Windows on this machine.**

## 1.8.11 - the .gitignore stops hiding new files from git

The `.gitignore` opened with `*` and re-included one path at a time. That was
written when this repository shared a folder with loose work; it has held only
its own files for a long time, and what was left of the pattern was the side
effect: a new file did not enter the repository, and `git status` stayed clean
about it.

## 🔬 What was outside the repository, measured on 16/09/2026

| file | what it is |
|---|---|
| `CHANGELOG.md` | **this file** — the one the COMMIT-RULE says is written *before* the commit, whose `##` heading *is* the subject. It did not exist for anyone who cloned. |
| `tools/git-hooks/commit-msg` | the hook that rejects a subject that is not `X.Y.Z - description`, and that checks the version against the index |
| `tools/git-hooks/pre-push` | the hook that refuses a version already on the remote, or one that moves backward |

The two hooks are reached through `core.hooksPath=tools/git-hooks`, which is
**local config**. A fresh clone therefore had neither the setting nor the files:
zero enforcement of the very rules the repository documents at length.

Probed with `git check-ignore --no-index`, the same treatment waited for
`docs/`, any new `.md` at the root, any new file under `.claude/`, and any
second workflow in `.github/workflows/`. The file's own comment already knew
the failure mode — *"o padrão 'ignora tudo e libera na mão' cala arquivo novo
em vez de reclamar"*. It had gone quiet three times.

## What it does now

Ordinary polarity: everything is versioned, and a file stays out only by being
named, with the reason on the line above it — `*.tmp-sync` (a `sync-version.sh`
interrupted mid-write), `.claude/settings.local.json` (per machine by
definition), `.loop/` (session state) and the usual OS litter.

That trade is the point. The cost moves from *forgetting to version* to
*forgetting to ignore*, and only the second one shows up in `git status`.

## 1.8.10 - git_pull says why a repo failed, and groups the failures by reason

`git_pull` reported a failure as a bare `✗` and a flat list of repository names.
That answers *which*, never *why* — and the causes that actually show up need
different repairs, so the one mark was hiding three unrelated jobs.

## 🔬 The sweep of 15/09/2026, which is where this came from

Three repositories failed in the same run, under the same mark:

| repo | what git actually said | repair |
|---|---|---|
| `B3DEV/b3dev_geriapp_v2` | `no such ref was fetched` | the branch was merged and **deleted on the remote**; the stale local `origin/<branch>` survives the fetch and makes `git status` read `0/0`, so nothing on screen points at it |
| `EOP_backup` | `Diverging branches can't be fast-forwarded` | ahead 1, behind 317 — a decision, not a retry |
| `SHVIA/SHVIA-WEB` | `no tracking information` | branch never had an upstream and does not exist on the remote |

**None of the three was a network failure**, which is the thing the flat list
invites you to assume — `git fetch` worked in all three. `git_status.sh` already
told "no upstream" apart back in `1.5.1`; the pull never did.

## What it does now

The output is captured instead of streamed so it can be read back, `classify_fail`
names the reason from git's own message — *sem upstream*, *branch apagada no
remoto*, *divergiu do remoto*, *árvore suja*, *conflito*, *remoto inacessível*,
*outro* — the reason prints under the repo, and the final summary keeps the flat
list and adds one line per reason with the repos under it.

`git_pull.cmd` gets the same classification and the same grouped summary, with
`findstr` over a temporary file in place of `case`, and one `MOT_<key>` variable
per reason in place of the parallel array. Its reason list has no *diretório não
encontrado*: that side only calls `:pull` on a directory it has already seen
holding a `.git`.

**Verified on Linux against a built tree of five repositories** — up to date, no
upstream, diverged, branch deleted on the remote, and dirty tree — plus a sixth
run with the remote URL pointed at nothing. Six classifications, six correct
names. **`git_pull.cmd` was not executed: there is no Windows on this machine.**

## 1.8.9 - the echo blocks are regenerated from repodocs

The four marked rules in `CLAUDE.md` and `AGENTS.md` are rewritten from the
single source at [samirhvbr/repodocs](https://github.com/samirhvbr/repodocs):
`QUEUE-RULE`, `RELEASES-RULE`, `LANGUAGE-RULE` and `COMMIT-RULE`. A block is
replaced whole between its markers, heading included — which is what stops a
local edit from surviving a regeneration and confusing the next reader.

`QUEUE-RULE` is new and arrives here for the first time: `.continue/` holds work
that does not exist yet, and a document leaves it when — and only when — the
thing it describes **exists**. Length, language and untidiness are not exit
conditions. **Never empty that folder as tidying.**
