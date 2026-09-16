# Auto Git

Utility scripts to manage **all repositories** in the `~/x/` workspace
at once: clone, update (`pull`) and send (`push`) in bulk.

This repository lives in `~/x/git/` and the projects are cloned one level above,
in `~/x/` — referred to as **BASE** by the scripts. Origin of this repo:
`https://github.com/samirhvbr/GIT.git`.

## 🔄 Before you start: `git pull`

**ALWAYS** pull remote updates before writing or changing anything. `git pull` is pre-authorized (allow). Here in the `~/x/` workspace you can update **all** repositories at once with `pull.sh`; for a single repo, just `git pull`.

```bash
git pull            # this repo
./pull.sh       # all repositories in ~/x at once
```

Working on top of an outdated base causes conflicts. Pull first, always.

## Requirements

- **`git`** (all scripts).
- **GitHub CLI (`gh`)** authenticated — used by `clone` to clone **without asking for a
  username/password**, the same on Windows and Linux. Install it from <https://cli.github.com> and run
  `gh auth login` (once per machine). `pull`/`push` use `git` directly.

## Structure

```
git/
├── README.md          # this file
├── clone.sh       # clones the 17 repos (Linux/macOS)
├── clone.cmd      # clone equivalent for Windows (cmd)
├── pull.sh        # git pull --ff-only in all repos (Linux/macOS)
├── pull.cmd       # pull equivalent for Windows (cmd)
├── push.sh        # status + git push in all repos (Linux/macOS)
├── push.cmd       # push equivalent for Windows (cmd)
├── status.sh      # git status (read-only) in all repos (Linux/macOS)
├── status.cmd     # status equivalent for Windows (cmd)
├── run.sh             # sweeps the repos and runs the house SKILLS (COMMITTER/AUDITOR)
├── .gitattributes     # eol=lf for *.sh, eol=crlf for *.cmd
├── .gitignore         # versions everything, ignores only what is named there
├── deploy/
│   ├── deploy.sh.template  # Laravel deploy template (copy to the project root)
│   └── README.md           # deploy standard (ownership, lock, checklist)
├── .continue/
│   └── README_20260623.md  # Continue notes
└── .claude/
    └── README.md      # Claude Code configuration notes (Blue3)
```

## Scripts

| Script          | Platform     | What it does |
|-----------------|--------------|-----------|
| `clone.sh`  | Linux/macOS  | Clones the 17 repositories via `gh repo clone`, rebuilding the folder tree. Skips those that already have `.git`; refuses non-empty existing folders. |
| `clone.cmd` | Windows (cmd)| Same function as `clone.sh` (also via `gh repo clone`), in batch. Text without accents for compatibility with the `cmd` code page. |
| `pull.sh`   | Linux/macOS  | Auto-discovers every git repository up to 3 levels below BASE and runs `git pull --ff-only` on each one. A failed pull is reported with its reason — no upstream, branch deleted on the remote, diverged, dirty tree, conflict, unreachable remote — and the summary groups the failures by it. |
| `pull.cmd`  | Windows (cmd)| Same function as `pull.sh`, in batch. Discovers repos in `BASE\repo` and `BASE\group\repo`. Same report of the failure reason. |
| `push.sh`   | Linux/macOS  | Auto-discovers the repos, shows the branch, warns about files with a pending commit and runs `git push` for the ready commits. |
| `push.cmd`  | Windows (cmd)| Same function as `push.sh`, in batch. Discovers repos in `BASE\repo` and `BASE\group\repo`. |
| `status.sh` | Linux/macOS  | Auto-discovers the repos and runs `git status` **read-only** on each one: branch, commits ahead of/behind the remote and pending files. Changes nothing. Accepts folders to skip via argument. |
| `status.cmd`| Windows (cmd)| Same function as `status.sh` (read-only), in batch. Shows branch, commits ahead/behind and pending files. |
| `run.sh`        | Linux        | Auto-discovers the repos (same as `pull.sh`), filters those that **opted into a house skill** and runs its cycle. Today: COMMITTER (`.committer.yml` marker) and AUDITOR (`.auditor/config.yml`, still without a headless runner). Always skips the third-party bucket (`000/`). Accepts `--dry-run`, `--list`, `--quiet-min N` and folders to skip as arguments. This is what crontab calls — so a new repo joins the sweep by just creating the marker, with no crontab edit. |

The list of repositories and their destinations is fixed only in `clone` (origin of each
repo). `pull` and `push` **discover** the repositories automatically by
scanning BASE, so they always reflect the folders present at the time.

## Usage

```bash
# Linux/macOS — from ~/x/git/
./clone.sh      # clones everything the first time
./pull.sh       # updates all repos
./push.sh       # pushes pending commits from all repos
```

```bat
:: Windows — from ~/x/git/
clone.cmd      :: clones everything the first time
pull.cmd       :: updates all repos
push.cmd       :: pushes pending commits from all repos
```

## Managed repositories

Mapping `repository → destination folder` (relative to `~/x/`):

| Repository (GitHub)                 | Destination                   |
|-------------------------------------|-------------------------------|
| `AREA81`                            | `AREA81`                      |
| `BLUE3_F1`                          | `BLUE3/F1`                    |
| `BLUE3_INTRANET`                    | `BLUE3/INTRANET`              |
| `MEUIP`                             | `BLUE3/MEUIP`                 |
| `BLUE3-INTRANET-MOBILE`             | `BLUE3/MOBILE`                |
| `BLUE3_SITE_FRONT`                  | `BLUE3/SITE`                  |
| `BLUE3_WORLD_CUP_2026`              | `BLUE3/WCUP`                  |
| `GIT`                               | `git`                         |
| `GITHUB_DESKTOP`                    | `GITHUB_DESKTOP`              |
| `SHVIA`                             | `IA`                          |
| `MARTHINA_CLASS`                    | `KIDS/MARTHINA`               |
| `RAFAELA_MEMORIA`                   | `KIDS/RAFAELA_JOGO_MEMORIA`   |
| `BLUE3_DEBIAN_CUSTOM_ISO`           | `LINUX/B3_CUSTOM_ISO`         |
| `LINUX`                             | `LINUX/KERNEL`                |
| `LINUX-START`                       | `LINUX/START`                 |
| `SHVTERM`                           | `SHVTERM/GUI`                 |
| `SHVTERM-WEB`                       | `SHVTERM/SITE`                |

The clones use the **GitHub CLI** (`gh repo clone`): auth is managed by `gh` — without asking for a
username/password and without configuring an SSH key per machine —, the same on Windows and Linux. The protocol
(ssh/https) follows `gh config get git_protocol`.

## Notes

- **Line endings** (`.gitattributes`): `*.sh` always LF, `*.cmd` always CRLF —
  the repo runs on both Linux and Windows.
- **`.gitignore`**: ordinary polarity since `1.8.11` — everything is versioned,
  and a file stays out only by being named there (`*.tmp-sync`,
  `.claude/settings.local.json`, `.loop/`, OS litter). There is **no naming
  requirement for a new script**: the old whitelist only accepted `git_*` and
  silently swallowed everything else, which is how `CHANGELOG.md` and both git
  hooks spent months outside the repository without `git status` ever saying so.
- **`deploy/`**: source of truth for `deploy.sh.template` (Laravel deploy
  standard) — copied to the root of each project. Secrets come from the `.env` at
  runtime, never versioned.
- **`.claude/README.md`**: documents the Claude Code configuration used in the
  Blue3 context (model, effort, blocked permissions).
