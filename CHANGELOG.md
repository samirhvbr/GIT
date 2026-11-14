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

## 1.9.8 - push finishes the sweep, pushes only the folder's own repository and never recreates a deleted branch

The 14/11/2026 review reproduced three ways `push.sh` failed, all at once in one
base. A repository whose `git status` failed (an unreadable index) ended the
whole sweep: under `set -euo pipefail` the pipeline's status reached the
assignment, the script exited 128 with no summary, and every repository after it
went unpushed — the class of bug 1.8.12 had fixed for `@{u}` only. An empty
`.git` was taken for a repository, and git walked up from it: with a repository
above BASE, `push.sh` pushed that one under the group folder's name. And a branch
whose upstream had been deleted on the remote, usually after its pull request
merged, got `git push -u origin <branch>` as its repair, which recreates it.

Discovery now counts a `.git` directory only when it holds a HEAD, as `pull.sh`
has since 1.9.5, and names the ones it skips. Each folder must be the repository
git answers for (`git rev-parse --show-toplevel`), or it is a failure and nothing
runs there. A failing `git status` is a failure of that repository and the sweep
goes on. A configured upstream that no longer resolves is `upstream apagado no
remoto`, in a summary line of its own, with the diagnosis as the repair — run
`pull.sh`, which tells merged from unmerged — and never the push. A repository
with no remote, or on a detached HEAD, is `Sem o que enviar` instead of "sem
upstream, push to origin", and the count printed for a branch with no upstream is
its commits that no remote has, not its whole history.

`tests/push_sweep_test.sh` is the first test of `push.sh`: six repositories and an
empty `.git`, one with an unreadable index, one whose upstream was deleted, one
with no remote. The previous commit's `push.sh` exits 128 on it; this one pushes
the three ready repositories, files the unreadable one as a failure and leaves
the deleted branch deleted. `push.cmd` carries the same changes, with the
`:tipogit` discovery of `pull.cmd`; it was not executed: no cmd interpreter on
this machine.

## 1.9.8 - pull keeps a stopped rebase and a detached HEAD with unsaved commits among the failures

1.9.7 moved every detached HEAD out of the failure list into `Sem o que puxar`,
because the one case in the 14/11/2026 sweep was `strix-build`, pinned to a tag on
purpose. The review then reproduced the other cases that wear a detached HEAD: a
rebase stopped by a conflict showed up as `HEAD solto` next to that tag pin, and
the interrupted operation, with whatever resolution sat in the index, dropped out
of the list a person acts on. A detached HEAD carrying commits no ref holds was
treated the same, though the next `git switch` leaves them to the reflog.

Before any other check, `operation_in_progress` now looks for git's own markers
(`rebase-merge`, `rebase-apply`, `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`,
`BISECT_LOG`) and files the repository as `operação em andamento`, naming the
operation. A detached HEAD is `Sem o que puxar` only when some branch,
remote-tracking ref or tag holds its commit; otherwise it is `HEAD solto, commits
fora de refs`, with the count and `git switch -c <nome>` as the repair. Nothing is
touched in either case.

`pull.cmd` gets the same two checks, and closes a parity gap the review found: a
folder where git itself fails used to be listed there as having no remote, while
`pull.sh` keeps it as a failure; it now goes straight to the pull, as in
`pull.sh`. `tests/pull_nothing_to_pull_test.sh` adds a rebase stopped by a
conflict and a detached HEAD with a commit of its own, and checks that the rebase
is still stopped afterwards. `pull.cmd` was not executed: no cmd interpreter on
this machine.

## 1.9.8 - pull's diagnosis fetches into remote-tracking refs only and never waits on a prompt

To tell whether a branch's work landed, 1.9.7 fetches each remote's default
branch with `git fetch <remote> <branch>`. With no destination, git maps the ref
through the remote's own configured refspec, and with a mirror-style one
(`+refs/*:refs/*`) it force-moves the **local** branch of the same name. The review
reproduced it: a local `main` with a commit nobody else had was reset to the
mirror's, and the commit survived only in the reflog — while the README said the
diagnosis never moves a branch.

The fetch now names its destination, `+refs/heads/<branch>:refs/remotes/<remote>/<branch>`,
and passes an empty `--refmap=`: an explicit destination alone is not enough,
because git still applies the configured refspec as an "opportunistic" update of
the refs it fetched.

The same calls reached remotes the sweep's own `git pull` never touches, with
nothing to stop a prompt: `git ls-remote` had no `GIT_TERMINAL_PROMPT=0`, and
neither had an SSH remote asking about a host key or a host that never answers.
`diag_net` now runs every network call of the diagnosis with the terminal prompt
off and, unless the person set `core.sshCommand` or `GIT_SSH_COMMAND`, SSH in
`BatchMode` with a 10-second connect timeout. `pull.cmd` turns off the git prompt
and Git Credential Manager's (`GCM_INTERACTIVE=never`) while it diagnoses a
repository, and gives the person's values back afterwards.

`tests/pull_deleted_branch_test.sh` adds `mirrorbk`, whose local `main` the
previous commit's `pull.sh` moved; it stays put now. `pull.cmd` was not executed:
no cmd interpreter on this machine.

## 1.9.8 - pull calls work landed by patches only when no merge or revert can hide a loss

The 14/11/2026 review reproduced two ways 1.9.7 could talk someone out of their
own work. A `master` holding a plain commit and a merge that added a file of its
own, whose remote had been rewritten with the patches of the plain commits, was
reported `divergiu, já no remoto` with `git rebase` as the repair — and following
it deleted the file the merge had added, because `git cherry` never judges merge
commits and `git rebase` drops them. And a local commit that the upstream had
applied and then reverted was reported the same way, because its forward patch is
upstream even though the work is not. The same weakness made a deleted branch
whose merge carried content of its own read `branch apagada, já na principal`.

`patches_in` is now strict. It says yes only when every commit of `HEAD` that the
ref lacks is a non-merge commit with a patch-equivalent there, there is at least
one, and none of them was reverted afterwards. The revert is found by its
patch-id: the reverse diff of the local commit has the same patch-id as the
revert commit upstream (`reverted_upstream`). A real divergence now names both
things the counts used to hide — `1 aplicado(s) e depois revertido(s) no remoto`,
`mais 1 merge(s), que o git cherry não compara`.

`tests/pull_diverged_test.sh` adds `evilmerge` and `applyrevert`, and
`tests/pull_deleted_branch_test.sh` adds `mergecontent`; the three were filed as
landed by the previous commit's `pull.sh` and are real divergences or unlanded
branches now. `pull.cmd` gets the same rule in `:patches_em` and a `:revertidos`
routine; it was not executed: no cmd interpreter on this machine.

## 1.9.8 - release.sh and the release workflow are resynchronised with repodocs

The 14/11/2026 review found this repository's `tools/release.sh` 169 lines behind
the one in repodocs, and the defects it found there are the ones repodocs had
already fixed. Measured on GitHub the same day:

- five versions in the log have no tag and no Release (1.8.2, 1.8.11, 1.8.12,
  1.8.13 and 1.9.2), because a push that carried several bumps only published
  the one at its tip;
- the 1.9.7 Release holds the README section alone, 965 characters, because the
  notes stopped at the first `##` heading of the version;
- the 1.8.1 Release body reads `## Commits- 1.8.1 - …` on one line, because the
  fallback's blank lines were lost.

Running the documented repair, `--backfill`, with the old script would have made
it worse: nothing in it reconciled the `Latest` badge, and every Release it
created without `--latest` takes the badge by GitHub's default, so the last one
backfilled — 1.9.2 — would have ended up `Latest`.

Both files now come from repodocs as they are. `release.sh` fetches before it
reads, takes the notes from the commit's own `CHANGELOG.md` and gathers every
section of the version, matches a version exactly instead of by prefix, gives
`--latest` only to the version `version.md` names (`--latest=false` to the rest)
and moves a drifted badge back, and counts a rate-limit stop as a failure. The
workflow pins `actions/checkout` by commit SHA, reads `vars.CI_RUNNER`, and fires
on any branch but publishes only from the default one. The missing Releases and
the 1.9.7 notes are repaired after this push, with this script.

## 1.9.7 - the READMEs describe the new pull reasons and what its diagnosis touches

Both READMEs said of `pull.sh` that "the diagnosis only reads", and that was true
of 1.9.6 and stopped being true in the second commit of this version: to say that
a deleted or unpublished branch's work has landed, the script fetches the default
branch of each remote it did not just pull from, and for a deleted branch it asks
`gh` for merged pull requests. The sentence now says exactly what the diagnosis
touches: it never moves a branch, the index or the working tree, it updates
remote-tracking refs for one branch per remote (never a prune), and it asks `gh`.

The same row lists what a summary can now say: `Sem o que puxar` for a repository
with no remote or a detached HEAD, the three kinds of `sem upstream`, `já na
principal` and the commit count for a deleted branch, `já no remoto` and the counts
for a diverged one, and where "already landed" is looked for and by which test.
`README.md` and `README_br.md` carry the same row in their two languages.

## 1.9.7 - pull tells a diverged branch whose patches are already upstream from a real divergence

`git pull --ff-only` fails on a diverged branch with a message that says nothing
about how it diverged, and the summary line was just `divergiu do remoto`. Five
repositories wore it in the 14/11/2026 sweep, and they were not the same:

- `b3dev/b3dev_janelinha_project`, on `codex/cartolina-validacao-conjunta-20261030`,
  had five commits ahead and 107 behind, and `git cherry origin/master` marks all
  five `-`: every patch is already on `master`. The branch also tracked `master`
  (`branch.<name>.merge = refs/heads/master`), so the pull tried to fast-forward a
  feature branch onto it. Nothing was at risk; the clone only needed to leave it.
- `audi`, on `master`, had four commits ahead (0.1.14 to 0.1.17, the photo
  reading) and ten behind, and all four are `+`: fourteen of the twenty-seven
  files they touch do not exist on `origin/master`. A real divergence, and it
  needs a person.
- `0forks/Netflix-API`, `000/shvia-web-docs-20261106` and
  `000/shvia-web-flake-20261106` are the cases in between, below.

`diagnose_diverged` reads the counts and the patches. When every non-merge commit
of the branch has its patch in the upstream (`patches_in`, the check the previous
commit added), the reason is `divergiu, já no remoto`. On a branch with a name of
its own, the hint is `git switch <tracked branch> && git pull --ff-only`, as for a
deleted branch. When the branch IS the upstream's branch (a stale copy of a
history the remote rewrote) the hint is `git rebase`, which drops exactly the
commits the upstream already has; with modified tracked files it would refuse, so
the reason stays `divergiu do remoto` and the hint is `git status --short`. A real
divergence now says what it is made of: `4 commit(s) local, 10 no remoto; 4 de 4
sem equivalente em origin/master (git cherry)`.

**Only the patches count here, and that is a correction.** A first version also
used the tree test that `landed_in` makes for a deleted branch (merging `HEAD`
into the upstream would not change its tree). Replayed against a copy of the real
`Netflix-API`, it called the clone `divergiu, já no remoto — o trabalho já está em
upstream/master` and printed `git switch master`. The branch is an integration
branch whose three commits are merges of contributions that the maintainer merged
and then reverted. Merging it changes nothing, because the upstream already "has"
those commits, but the work is not there: it was taken out. A line saying it had
landed would have hidden that decision. `tests/pull_diverged_test.sh` now builds
that story (`reverted`) and fails on that first version. `git cherry` does not
judge merge commits, so they are counted and named, never claimed: the same clone
now reads `3 commit(s) local, todos merges; 11 no remoto`, and a branch whose
non-merge commits all match but which also carries merges says how many.

The two `shvia-web` clones stay `divergiu do remoto`, with their counts (`2
commit(s) local, 2 no remoto; 1 de 2 sem equivalente`). Their local commits carry
`(versão no merge)` in the subject and the CHANGELOG, the remote's carry the
version the watcher stamped at merge, so the patches differ by exactly that. With
the CHANGELOG and `version.md` left out the patch ids are equal; the script does
not know about that stamp and does not guess it.

The words "landed" and "já na principal" of the deleted-branch and no-upstream
diagnoses mean that the work went through the default branch, by ancestry, by an
equal tree, by patches or by a merged pull request. They do not say the
maintainers kept it, and they are not meant to: those branches are gone from the
remote or never had one, and the repair they offer, `git switch`, deletes
nothing. A diverged branch is still on the remote and is being asked to be
dropped, which is why it gets the stricter reading.

`tests/pull_diverged_test.sh` builds `rebased` (two commits cherry-picked into a
`main` that has since edited the same file, branch tracking `main`), `samename`
(the remote force-pushed the same two patches over a new base), `dirty` (the
same, with a modified file), `real` (two commits nowhere else) and `reverted`. It
checks the reasons, the hints, the counts and the grouped summary lines, and that
no clone moved, lost a commit or lost its modified file. `pull.cmd` carries the
same in `:diverge`; it was not executed: no cmd interpreter on this machine.

## 1.9.7 - pull tells a branch with no upstream apart: set it, already landed, or never published

`git pull` on a branch with no upstream fails the same way whatever the reason,
and `classify_fail` filed all of them under `sem upstream`. In the 14/11/2026
sweep that label held seven repositories with four different stories. The repair
git prints (`git branch --set-upstream-to=...`) could not work for any of them:
`git ls-remote` found no branch of that name on any remote of the seven.

- `0forks/YouPI-PG` and `0forks/ai-jail` were on local branches whose commits are
  already in `upstream/main` and `upstream/master`: nothing to publish, and the
  clone is simply on a branch it no longer needs.
- `000/shvia-mobile-pr-fixes-20261105` was on `recut/docs-review-0.7.15`, whose
  nine commits had reached `origin/master` by rebase: `git cherry` says `+0 -9`,
  nine patches there and none missing, while `HEAD` is neither an ancestor nor
  tree-equal to it, and `origin/master` had moved fifteen commits on.
- `000/b3dev-projects-back-contrib-20261022`, `000/bemcuidar-v2-contrib-20261022`
  and `000/mmo-project-contrib-20261022` were on integration branches that were
  never pushed, with five commits each that no remote has. That is unpublished
  work, and a person should see it as that.
- `000/recon-deck-review2-evidence-20261022` has no remote at all, which the
  previous commit already sets apart.

`diagnose_no_upstream` splits them. If a remote has the branch under its own name
(local refs only), the reason stays `sem upstream` and the hint is the
`--set-upstream-to` that now fits. Otherwise `find_landing` looks for the work in
every remote's default branch, fetching that one branch from each remote first:
the pull that failed fetched nothing, so a claim that the work is safe must not
rest on refs of unknown age. Found, and the working tree clean, it is
`sem upstream, já na principal` with `git switch <default> && git pull --ff-only`;
found with modified tracked files, it stays `sem upstream` with the count of files
and no switch command, as `branch apagada, árvore suja` does. Not found, it is
`sem upstream, só local`, with `branch nunca publicada: N commit(s) fora de
<remote>/<default>`. The three are three lines of the summary.

`landed_in` learns a third way to say yes, `patches_in`: every non-merge commit of
`HEAD` that the ref lacks has a patch-equivalent in it, and there is at least one.
It is what a rebase merge or a cherry-pick leaves behind, and it keeps holding as
the branch moves on, which the tree comparison does not. `git cherry` does not
judge merge commits, so a branch of merges only gives empty output, and empty
output answers no. The deleted-branch diagnosis of the previous commit gets it
too.

Replayed against copies of those seven clones, the 1.9.6 `pull.sh` reported seven
`sem upstream`; this one reports `YouPI-PG`, `ai-jail` and `shvia-mobile-pr-fixes`
as `já na principal`, the three integration branches as `só local`, and the
repository with no remote is the previous commit's `sem remote`. None of the
seven has a same-name branch on a remote, so that path is only exercised by the
test.

`tests/pull_no_upstream_test.sh` builds each story: a branch pushed under its own
name with no upstream, one never published and already in `origin/main`, the same
with a modified file, one landed in an upstream the clone had not fetched since
setup, one cherry-picked into a `main` that has since edited the same file (so the
tree comparison conflicts and only the patches tell), the same with one extra
commit that never reached `main` (not landed), and one with two commits nobody
has. It checks that the switch is offered to exactly the three clean landed
clones and that no clone changed branch or lost its modified file. It fails on
the previous commit's `pull.sh`. `pull.cmd` carries the same in `:semup` and
`:patches_em`; it was not executed: no cmd interpreter on this machine.

## 1.9.7 - pull finds a deleted branch whose work landed in any remote or by pull request

Eight clones in the 14/11/2026 sweep were filed under `branch apagada no remoto`
with `N commit(s) fora de <fork>/<default>; confira antes de trocar de branch`:
`ai-memory-web-contrib`, `gv_music-contrib`, `redisover-contrib`,
`youpi-pg-contrib`, `ai-jail`, `deckcraft`, `projectfw-audit` and
`repodocs-projectfw-release`. In every one the pull request had merged with
exactly the commit at `HEAD`: `gh pr list --state merged --head <branch>` returned
a head commit equal to the local one (PRs #6, #3, #4, #85, #190, #1 and #3, and
deckcraft's #1187). Nothing was at risk; the warning was wrong, and it was wrong
in three different ways.

- **Only the tracking remote was compared.** The branch was pushed to a fork, and
  `diagnose_deleted_branch` asked whether `HEAD` was in the fork's default
  branch. A contribution is merged in the upstream. Six of the eight were plain
  ancestors of the upstream's default branch.
- **That remote's refs were as old as the clone.** The pull that fails fetches the
  tracking remote only, so `upstream/main` still held whatever it held when the
  clone was set up, before the pull request merged.
- **For two of them git has nothing left to compare.** `projectfw-audit` and
  `repodocs-projectfw-release` merged as #1 and #3, and `HEAD` is neither an
  ancestor of `origin/master` nor tree-equal to it (the 1.9.3 test: merging `HEAD`
  into the default branch would not change its tree). The merge was not a plain
  one, and by the time of the sweep `origin/master` was 155 and 4 commits ahead,
  so a comparison that could have held the day after the merge no longer does.
  Only the forge still knows.

`find_landing` now tries the tracking remote first and then every other remote,
fetching each one's default branch (that one branch; never a prune) before it
compares, except for the remote the failed pull has just fetched. When git alone
says no, `landed_by_pr` asks `gh pr list --state merged --head <branch>` of every
GitHub remote and counts the work as landed only when a pull request was merged
with exactly the commit at `HEAD`: a branch with commits made after the merge is
still reported with its commit count. Without `gh`, or with no GitHub remote, that
step answers "no" silently and the behavior is the one before. The summary line
names the proof: `o trabalho já está em origin/master — PR #1 mesclado com este
mesmo commit`.

Replayed against copies of the eight clones, with the old branch checked out, the
1.9.6 `pull.sh` reported all eight as `branch apagada no remoto`; this one reports
all eight as `branch apagada, já na principal` with
`git switch <default> && git pull --ff-only`, six by ancestry in the upstream and
the two `projectfw`/`repodocs` ones by the pull request. The originals were not
touched.

`tests/pull_deleted_branch_test.sh` gains four clones with a fork and an upstream:
`contrib` (squash-merged upstream, local `upstream/main` older than the squash),
`contribopen` (never merged: still `2 commit(s) fora de origin/main`), `prmerged`
(the upstream rewrites the file after the squash, so only the pull request proves
it) and `prextra` (the pull request merged an older commit than `HEAD`: not
landed). A fake `gh` ahead of the real one answers from files, so the test needs
no network and no login. It fails on the previous commit's `pull.sh`. `pull.cmd`
carries the same logic in `:acha_pouso`, `:pouso_um`, `:pr_mesclada` and
`:marca_pouso`; it was not executed: no cmd interpreter on this machine.

## 1.9.7 - pull sets a detached HEAD and a repository with no remote apart from the failures

The 14/11/2026 sweep over 173 repositories ended with 27 in the failure list, and
two of them had nothing to repair:

- `strix-build` is checked out on the tag `shvia-v1.2.45` on purpose: it is the
  directory the release binaries are built from. With no branch, `git pull` says
  "You are not currently on a branch", which `classify_fail` has no pattern for,
  so the repository was filed under `outro` with git's whole message above it.
- `000/recon-deck-review2-evidence-20261022` has no remote at all. `git pull`
  answers "There is no tracking information for the current branch", which is
  the `sem upstream` pattern, and the summary listed it next to the branches whose
  repair is `git branch --set-upstream-to`.

Neither has a repair, because neither has anything to pull. `pull.sh` now checks
both before it calls `git pull`: no remote configured prints
`↷ sem remote configurado — nada a puxar`, and a detached HEAD prints
`branch: (HEAD solto em <tag or short hash>)` and `↷ HEAD solto — não há branch
para puxar`. The repository goes to a new summary line, `↷ Sem o que puxar:`, with
the reason in parentheses beside each name, and not to `Falhou`. Nothing is
pulled, fetched or moved in either case. A branch name of `?` — git itself failed
in that directory — is still a failure, and still reaches the pull.

`tests/pull_nothing_to_pull_test.sh` builds a repository with no remote, a clone
detached on a tag and an ordinary clone. Against the 1.9.6 `pull.sh` it fails on
the first expectation; now it passes, and it also checks that the pinned clone is
still detached on its tag afterwards. `pull.cmd` carries the same two checks and
the same summary line; it was not executed: no cmd interpreter on this machine.

## 1.9.6 - push.cmd and status.cmd drop a stray CR that kept the tree dirty

The `exit /b 0` line that closes the per-repository subroutine of `push.cmd`
(line 205) and `status.cmd` (line 189) has been stored with a CRLF inside an
otherwise LF blob since the 1.9.0 rename commit (`9763402`).
`git ls-files --eol` reported both files as `i/mixed`; the other four `.cmd`
files and every `.sh` and `.md` were already `i/lf`.

`.gitattributes` says `*.cmd text eol=crlf`, so git converts the checked-out file
to LF before comparing it with the index, and the stored CR can never match. In
every clone both files read as modified, with a one-line diff that looks
identical on screen (`-exit /b 0` / `+exit /b 0`) and is empty under
`git diff --ignore-cr-at-eol`. `git checkout -- <file>` does not clear it: the
checkout rewrites the same bytes and the next hash shows the same difference.

It surfaced on 15/10/2026 as `árvore suja` in `pull.sh`. The 1.9.5 fast-forward
changes both files, so `git pull --ff-only` aborted with "Your local changes to
the following files would be overwritten by merge" on a tree where nobody had
edited anything. The classification was right; the dirtiness was not real.

`git add --renormalize` rewrites the two blobs with LF on that line. Nothing a
script does changes: with `eol=crlf` the working-tree files stay CRLF on every
line, as before. A fresh clone now reports `i/lf` for all six `.cmd` files and a
clean `git status`.

**Cleaning an affected clone:** a clone that already holds the stray CR must
delete the two files from disk before pulling this commit (`rm push.cmd
status.cmd`, then `git pull --ff-only`). `git checkout -- push.cmd status.cmd`
was tried first and the pull aborted again.

## 1.9.5 - pull separates a landed deleted branch with a modified tree from a safe one

The 1.9.3 diagnosis decides "already on the default branch" from commits alone.
On `000/ai-memory-akita` the branch `fix/multi-page-relations` was an ancestor of
`origin/main` — the pull request had landed and the fork's branch was deleted —
so the summary filed it under `branch apagada, já na principal` and printed
`git switch main && git pull --ff-only`. The working tree held 177 staged files
(+20189/-1016) that match no ref and no commit between `HEAD` and `origin/main`,
and `HEAD` had not moved since 07/09/2026. Following the printed command would
have been refused or, worse, carried that state onto `main`.

A landed branch whose tracked files are modified, staged or not, now gets its own
reason, `branch apagada, árvore suja`, with the count of files and
`git status --short` in place of the switch command. Untracked files are not
counted: they matter only if they collide with the default branch, and the
switch reports that itself — counting them would move most clones out of the safe
group over build leftovers. The diagnosis still only reads.

The extended `tests/pull_deleted_branch_test.sh` adds clones with a staged change,
an unstaged change and only an untracked file, checks that the switch command is
offered to exactly the clean ones, and checks the staged and unstaged changes are
still there afterwards. It fails on the 1.9.5 discovery commit's `pull.sh` and
passes now; on the real `ai-memory-akita` the summary now reads
`branch apagada, árvore suja: 000/ai-memory-akita`. `pull.cmd` was not executed:
no cmd interpreter on this machine.

## 1.9.5 - pull skips a .git directory with no HEAD instead of failing its folder

`SHVIA/.git` was an empty directory: no HEAD, no objects, created on 08/10/2026
next to two other empty directories (`.agents`, `.aws`). Discovery looked only
for a directory named `.git`, so the sweep listed `SHVIA` as a repository and
`git pull` answered "not a git repository", which the summary filed under the
catch-all `outro`. The repositories that really live under `SHVIA/` were pulled
all the same; the failure was the folder around them.

A `.git` directory now counts only when it holds a HEAD. An empty one is
reported under the header (`⚠ SHVIA/.git ignorado: diretório sem HEAD, não é
repositório`) and skipped, and the folder is still searched one level down.
`pull.cmd` had the same defect with a worse effect: it stops at the first level
that has a `.git`, so an empty one made it skip every repository under that
group. It now tells three cases apart — a `.git` with a HEAD, a `.git` file (as
a worktree has, still accepted there), and an empty or HEAD-less `.git`
directory. Measured on this machine: 121 repositories found, one warning.

New test: `tests/pull_discovery_test.sh`, a loose repository and a grouped one
under a group folder with an empty `.git`, plus a folder holding nothing else.
It fails on the 1.9.4 `pull.sh` with `outro: GRP stray` and passes now.
`pull.cmd` was not executed: no cmd interpreter on this machine.

`push`, `status` and `run` use the same `find` and still count an empty `.git`;
they are not changed here.

## 1.9.4 - the echo blocks are regenerated from repodocs

The marked rules in `CLAUDE.md` and `AGENTS.md` are rewritten from the single
source at [samirhvbr/repodocs](https://github.com/samirhvbr/repodocs):
`QUEUE-RULE`, `RELEASES-RULE`, `LANGUAGE-RULE`, `COMMIT-RULE` and `CICD-RULE`.
A block is replaced whole between its markers, heading included — which is what
stops a local edit from surviving a regeneration and confusing the next reader.

`QUEUE-RULE` is new and arrives here for the first time: `.continue/` holds work
that does not exist yet, and a document leaves it when — and only when — the
thing it describes **exists**. Length, language and untidiness are not exit
conditions. **Never empty that folder as tidying.**

## 1.9.3 - pull tells a merged deleted branch apart and names the repair

A pull that fails with `no such ref was fetched` used to land in a single
bucket, "branch apagada no remoto". On 28/09/2026 four SHVIA repositories landed
there after that day's branch cleanup: three sat on branches whose pull requests
had merged, and one on a branch whose content had been rebuilt on master with
its comments translated. Those are two different repairs under one label.

`pull.sh` and `pull.cmd` now look at the default branch that the failed pull has
just fetched. When HEAD is an ancestor of it, or when merging HEAD into it would
leave its tree unchanged (which is what a squash or rebase merge leaves behind),
the reason becomes "branch apagada, já na principal". The repo's block then
prints `git switch <default> && git pull --ff-only`, and the summary names the
target (`repo→main`). Otherwise the old reason stays, now with the count of
commits outside the default branch. The diagnosis only reads. Switching is left
to the user, as the rule on scripts that write requires.

The default branch comes from the local `origin/HEAD`, then from
`git ls-remote --symref`, then from whichever of `main`/`master` exists.

Measured: `tests/pull_deleted_branch_test.sh` (a merge, a squash with no local
`origin/HEAD`, and a branch deleted unmerged) passes on this version and fails
against 1.9.2. Run read-only on the four SHVIA repositories, the diagnosis
classifies BENCH, CODE and SITE as landed and WORKSPACE as one commit outside
master, which matches the cleanup's own record. `pull.cmd` was not executed:
there is no cmd interpreter on the machine where this was written.

## 1.9.2 - version sync preserves terminal line endings

The synchronizer now restores the line feed removed by command substitution and
checks that byte when it decides whether a script is current. Repeated runs keep
both shell and CRLF batch scripts terminated correctly instead of leaving a
last lone carriage return or an unterminated line.

## 1.9.2 - clone all normalizes workspace directory names

`clone_all.sh` now writes lowercase directory components for repository and
group names. The former `SKILL` group is named `skills`; `EOP` and
`MIGRANDO-ZIMBRA-CARBONIO` are the two intentional uppercase exceptions.

An existing repository at the former case-preserving location is moved to the
canonical location during a normal run. The migration is skipped in dry-run
mode and refuses to touch either location if both already exist, so a collision
cannot silently overwrite a clone. This moves `SKILL/skill-*` into
`skills/skill-*` as the affected repositories are processed.

## 1.9.1 - the repository stops choosing the model

`CLAUDE_CODE_SUBAGENT_MODEL` leaves `.claude/settings.json`. The model is now the user's
choice, made with `/model`, and a subagent inherits it: by default Claude Code gives a
subagent the session's model, and this variable was the only thing making it different —
with the session on Opus 5.5, subagents were measured on Opus 5, because the variable names
the `opus` alias and the alias still resolves through the organization's managed pin.

`.claude/README.md` stop(s) describing a model profile.

Rule and measurement: repodocs ADR-027.

No test: configuration and documents. Checked that the file parses and that repodocs
runbook §7's check is silent here.

## 1.9.0 - pull, push and status choose repositories with -d and -i

Same version as the rename above: one delivery, split into the block that moves
files and the block that adds behaviour.

`-d DIR` leaves `DIR` out and everything under it. `-i DIR` runs **only** on
`DIR` and what is under it. `-h` prints the usage.

A flag stays in force for every word that follows it until another flag
appears, so `-d 000 001` and `-d 000 -d 001` say the same thing. That is the
whole reason for the rule: there is no form to memorise, and neither spelling
is an error. A bare word with no flag at all is still an exclusion — the
behaviour the scripts always had — so anything already in a crontab keeps
working untouched.

`DIR` matches by path (`BLUE3/CNPJ`), by final name (`CNPJ`) or by parent
folder (`BLUE3` reaches everything under `BLUE3/`). That is the matching rule
the old positional skip already used; `-i` reads it the same way, so the two
flags never disagree about what "that one" means.

## Why the two cuts are reported differently

`-i` filters **before** the sweep and says nothing per repository, only a count
in the banner. `-d` filters **inside** it and prints `↷ pulado (-d)` under each
repository it drops.

It is not lost symmetry. On this machine the sweep finds 114 repositories:
`-i BLUE3` would open with a hundred lines of *pulado* before the first useful
one. `-d` names repositories one at a time, and whoever typed it wants the
exclusion confirmed on screen.

An argument that reaches no repository is warned about. The two modes fail
silently in opposite directions — a mistyped `-d` touches exactly what was
meant to stay out, and a mistyped `-i` empties the whole sweep without saying
why — and neither failure announces itself.

## The Windows side, which had no arguments at all

`pull.cmd`, `push.cmd` and `status.cmd` read **no argument whatsoever** before
this. The skip list was documented in the `.sh` and in the README, and someone
running on Windows believed they had the behaviour they had read about. A
divergent pair is worse than a missing feature, so the flags are born on both
sides in the same commit.

The three `.cmd` files gained a parser (`:parse`), a two-pass discovery — find
everything, then select — and `:casa`, `:avisa`, `:seleciona` and `:usage`.
Two implementation differences from the `.sh`, both forced: lists are
semicolon-separated strings because `cmd` has no arrays, and `:casa` reads the
parent folder as "the group part of the path" because the discovery is at most
two levels deep, which makes the two definitions equivalent here.

**Verified on Linux**, on a built tree of eight repositories shaped like the
real one (groups `000/`, `BLUE3/`, `B3DEV/`, `KIDS/` plus loose repos):
no flag, `-d 000`, `-d 000 -d B3DEV`, `-d 000 B3DEV`, the bare `000 B3DEV`,
`-i 000`, `-i BLUE3 -d BLUE3/CNPJ`, `-i BLUE3/MEUIP`, `-i CNPJ`, `-i 001`
(warns, exits 1), `-d 001` (warns, continues), `-x` (exit 2), `-h`, and
`-d BLUE3/ -d ./AREA81` for the trailing-slash and `./` forms. Then against the
real base of 114 repositories with `status.sh`, which is read-only.

**The `.cmd` files were not executed: there is no Windows on this machine.**
They were checked statically instead — every `goto`/`call` target resolves, and
block parentheses balance — and every `echo` with parentheses or `!` was
written with the escaping the rest of these files already uses.

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
