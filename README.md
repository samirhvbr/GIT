# Auto Git

Utility scripts to manage **all repositories** in the `~/x/` workspace
at once: clone, update (`pull`) and send (`push`) in bulk.

This repository lives in `~/x/git/` and the projects are cloned one level above,
in `~/x/` — referred to as **BASE** by the scripts. Origin of this repo:
`https://github.com/samirhvbr/GIT.git`.

## 🔄 Before you start: `git pull`

**ALWAYS** pull remote updates before writing or changing anything. `git pull` is pre-authorized (allow). Here in the `~/x/` workspace you can update **all** repositories at once with `git_pull.sh`; for a single repo, just `git pull`.

```bash
git pull            # this repo
./git_pull.sh       # all repositories in ~/x at once
```

Working on top of an outdated base causes conflicts. Pull first, always.

## Requirements

- **`git`** (all scripts).
- **GitHub CLI (`gh`)** authenticated — used by `git_clone` to clone **without asking for a
  username/password**, the same on Windows and Linux. Install it from <https://cli.github.com> and run
  `gh auth login` (once per machine). `git_pull`/`git_push` use `git` directly.

## Structure

```
git/
├── README.md          # this file
├── git_clone.sh       # clones the 17 repos (Linux/macOS)
├── git_clone.cmd      # clone equivalent for Windows (cmd)
├── git_pull.sh        # git pull --ff-only in all repos (Linux/macOS)
├── git_pull.cmd       # pull equivalent for Windows (cmd)
├── git_push.sh        # status + git push in all repos (Linux/macOS)
├── git_push.cmd       # push equivalent for Windows (cmd)
├── git_status.sh      # git status (read-only) in all repos (Linux/macOS)
├── git_status.cmd     # status equivalent for Windows (cmd)
├── .gitattributes     # eol=lf for *.sh, eol=crlf for *.cmd
├── .gitignore         # ignores everything, versions only what is in the whitelist
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
| `git_clone.sh`  | Linux/macOS  | Clones the 17 repositories via `gh repo clone`, rebuilding the folder tree. Skips those that already have `.git`; refuses non-empty existing folders. |
| `git_clone.cmd` | Windows (cmd)| Same function as `git_clone.sh` (also via `gh repo clone`), in batch. Text without accents for compatibility with the `cmd` code page. |
| `git_pull.sh`   | Linux/macOS  | Auto-discovers every git repository up to 3 levels below BASE and runs `git pull --ff-only` on each one. |
| `git_pull.cmd`  | Windows (cmd)| Same function as `git_pull.sh`, in batch. Discovers repos in `BASE\repo` and `BASE\group\repo`. |
| `git_push.sh`   | Linux/macOS  | Auto-discovers the repos, shows the branch, warns about files with a pending commit and runs `git push` for the ready commits. |
| `git_push.cmd`  | Windows (cmd)| Same function as `git_push.sh`, in batch. Discovers repos in `BASE\repo` and `BASE\group\repo`. |
| `git_status.sh` | Linux/macOS  | Auto-discovers the repos and runs `git status` **read-only** on each one: branch, commits ahead of/behind the remote and pending files. Changes nothing. Accepts folders to skip via argument. |
| `git_status.cmd`| Windows (cmd)| Same function as `git_status.sh` (read-only), in batch. Shows branch, commits ahead/behind and pending files. |

The list of repositories and their destinations is fixed only in `git_clone` (origin of each
repo). `git_pull` and `git_push` **discover** the repositories automatically by
scanning BASE, so they always reflect the folders present at the time.

## Usage

```bash
# Linux/macOS — from ~/x/git/
./git_clone.sh      # clones everything the first time
./git_pull.sh       # updates all repos
./git_push.sh       # pushes pending commits from all repos
```

```bat
:: Windows — from ~/x/git/
git_clone.cmd      :: clones everything the first time
git_pull.cmd       :: updates all repos
git_push.cmd       :: pushes pending commits from all repos
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
- **`.gitignore`**: ignores everything by default and versions only what is in the
  whitelist (`README.md`, `git_*`, `.gitattributes`, `.gitignore`, `.claude/`,
  `.continue/`, `deploy/`). **A new script must start with `git_`** (or be
  added to the whitelist) — otherwise it falls under `*` and becomes invisible to git (does not
  show up in `status`, does not get pushed).
- **`deploy/`**: source of truth for `deploy.sh.template` (Laravel deploy
  standard) — copied to the root of each project. Secrets come from the `.env` at
  runtime, never versioned.
- **`.claude/README.md`**: documents the Claude Code configuration used in the
  Blue3 context (model, effort, blocked permissions).
