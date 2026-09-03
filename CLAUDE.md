# GIT — Instruções para Claude Code

> Scripts de operação em massa dos repositórios: clonar, puxar, empurrar e conferir
> status de todos de uma vez, no macOS/Linux (`.sh`) e no Windows (`.cmd`).

---

## 🔄 Antes de começar: `git pull`

**SEMPRE** verifique atualizações remotas antes de escrever ou alterar qualquer coisa
neste repositório:

```bash
git pull
```

---

## Versão e Commits (obrigatório)

`version.md` na raiz é a **fonte única**. O `scripts/sync-version.sh` propaga para os
12 scripts — o `VERSION=` de cada um e o `vX.Y.Z` do cabeçalho.

```bash
./scripts/sync-version.sh          # aplica
./scripts/sync-version.sh --check  # não escreve; sai != 0 se algo divergir
```

Formato de commit: `X.Y.Z - description in English (US)`

```
1.5.0 - Unifica a versão dos scripts no version.md
1.5.1 - git_status.sh: ignora repositório sem upstream em vez de abortar
```

**Regras inegociáveis:**

1. A versão **sempre** vem do `version.md` — bumpe no **mesmo commit** da mudança.
2. Rode o `sync-version.sh` antes de commitar (ou o `--check` no pré-commit).
3. Critério de bump:
   - **Z**: correção ou ajuste em um script, mensagem, cor, flag nova compatível.
   - **Y**: comportamento novo (script novo, mudança no que é descoberto/afetado).
   - **X**: manual.
4. Mensagem em **português**, específica o suficiente para `git log --grep`.
5. Proibido `feat:`, `fix:`, `chore:` ou mensagens vagas ("ajuste", "update").

### Por que UMA versão para o repo, e não uma por script

Cada script tinha a sua: em 28/07/2026 o `git_pull.sh` estava 1.4.0 e o
`git_pull.cmd` — que é o equivalente Windows dele — estava 1.0.0. Quem roda no
Windows não tinha como saber se o script dele já tinha a correção que o irmão
recebeu, porque o número não queria dizer a mesma coisa dos dois lados.

Com o `version.md`, `git_pull.cmd v1.5.0` e `git_pull.sh v1.5.0` significam "saíram da
mesma release" — que é a pergunta que se faz de verdade. A evolução de uma ferramenta
isolada vive no `git log`.

---

## Paridade `.sh` ↔ `.cmd` é contrato

Cada ferramenta tem os dois. **Mudou um, mude o outro no mesmo commit** — ou registre
na mensagem por que não dá. Um par divergente é pior que uma feature ausente: o
usuário de Windows acha que tem o comportamento que leu no `.sh`.

---

## Layout dos repositórios: dois níveis

A BASE é a **pasta-mãe deste repo** (`~/x` quando ele está em `~/x/GIT`). Os scripts
descobrem repositórios em **dois níveis**:

```
BASE/REPO/.git                  ← projeto solto
BASE/GRUPO/REPO/.git            ← projeto com subprojetos (SHVIA/SHVIA-WEB)
```

Os `.sh` fazem `find "$BASE" -maxdepth 3 -type d -name .git -prune`; os `.cmd` varrem
nível 1 e descem um se o diretório não for repo. **Não reduza esse alcance** — a
organização por grupo (`SHVIA/`, `SSHVTERM/`, `BLUE3/`) depende dele.

Ao mexer na descoberta, teste com os dois formatos ao mesmo tempo; achar só o solto é
uma regressão silenciosa (o script roda, reporta menos repos, e ninguém percebe).

---

## Cuidado especial: os scripts que ESCREVEM

`git_status.sh` é somente leitura. `git_pull`/`git_push` alteram repositórios de
terceiros na máquina, e `git_clone*` cria árvore de diretórios.

- Nunca faça um script **descartar** trabalho local (`reset --hard`, `clean -xdf`,
  `checkout --force`) sem flag explícita e aviso na tela.
- `git_clone.sh` tem a lista `OWNER/REPO|PASTA_DESTINO`, que **define** o layout
  agrupado. Ela precisa acompanhar a organização real — lista desatualizada recria a
  estrutura antiga em máquina nova.
- `git_clone_all.sh` clona **tudo do dono, achatado** (`dest="${repo##*/}"`). Ele é
  para inventário/bootstrap, não para reproduzir a organização por grupo.

---

## Referências rápidas

- Versão atual: `version.md`
- Sincronizador: `scripts/sync-version.sh`
- Configuração do agente: `.claude/settings.json`
- Notas de continuidade: `.continue/`

---

<!-- COMMIT-RULE:repodocs -->

## Commits — you commit, and nothing is delivered until you have

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/versioning.md#who-commits-and-when)**
> — change it there, not here. This block is regenerated.

**Committing is your job.** Not "leave the tree ready and something downstream
packages it" — you run `git commit`, and `git push`, as the last step of the work
you were asked to do. The COMMITTER skill that used to commit on an agent's
behalf is `enabled: false` in every repository of this fleet since 03/09/2026;
what is left of it is a kill-switch, not a scheduler. **If you do not commit,
nobody does.**

**Do not report a task as finished before the commit exists.** "Done",
"delivered", "concluded" mean the work is in `git log` — never that it is sitting
uncommitted where only this session can see it. The commit is the last step *of
the task*, not a follow-up for someone else. If you are about to write
"finished", commit first, then write it.

**Every commit obeys the versioning rules**, with no exception:

- Subject `X.Y.Z - short description in English (US)`, the version taken from
  `version.md` and **bumped in the same commit**.
- The `CHANGELOG.md` entry is written first — its `## X.Y.Z - description`
  heading *is* the subject.
- No Conventional Commits prefix (`feat:`, `fix:`, `chore:`) and no vague
  subject ("update", "ajuste", "wip", "changes", "several improvements").

**The bump is the one clause a repository may override — in writing.** If this
repository's own documentation says the version is stamped some other way, and says
why, follow that. Otherwise the line above applies to you. An override nobody wrote
down is not an exception. Nothing else in this block bends: the changelog entry, the
subject, the language, one subject per commit, and committing before you report done
all hold regardless.

**One subject per commit.** The subject has to describe the whole commit
honestly. The moment your description needs an "and" to be true, it is two
commits.

**Split a large delivery into blocks.** A complex task is committed as a series
of commits grouped by subject, each small enough to be described in one line and
read on its own. They may share a version — bump `version.md` in the first and
repeat the number in the rest; two commits carrying one version is expected, not
a mistake. **Splitting is the default** for anything non-trivial, because the
history is the documentation of *how* the work was done, and one commit touching
six unrelated subjects documents none of them.

**The standard you are keeping:** someone reading `git log` alone — a year from
now, without the conversation that produced the work — can say what happened,
when, why, and at which version. If your commit would fail that test, it is too
big or its subject is too vague, and both are fixed the same way.

<!-- /COMMIT-RULE -->

---

<!-- RELEASES-RULE:repodocs -->

## Releases — the `version.md` on GitHub is what the Releases show

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/versioning.md)**
> — change it there, not here. This block is regenerated.

**The `version.md` of the default branch, on GitHub, is what the GitHub Releases
must show.** The local checkout does not enter the calculation: it can be behind,
ahead or mid-work, and none of that is published — GitHub cannot tag a commit it
does not have.

**The bump and the Release are one act.** A commit that bumps `version.md` is not
finished until that version has a tag, a published Release, and the **`Latest`
badge on it** — the same push, not "later". A badge sitting on an older release
tells whoever looks that the project is at a version it is not.

- `.github/workflows/release.yml` does it on any push that touches `version.md`.
- `./tools/release.sh` does it by hand. It is **idempotent and self-healing**:
  it publishes whatever is missing and moves a drifted badge back. Running it is
  always safe, so it is both the check and the fix.

A PR publishes nothing while it is a PR. The moment it merges, the push moves
`version.md` on the default branch and the Release becomes that version.

Tag and Release title are the **bare version — no `v` prefix**.

## Language — English (US), everywhere in the repository

**Everything that lives in this repository, or in GitHub's interface around it,
is written in English (US)**: documents, **commit messages**, pull request titles
and bodies, issues, code comments, changelog entries, release notes.

Commit format: `X.Y.Z - short description in English`. The version comes from
`version.md` and is bumped in the same commit. Conventional Commits prefixes
(`feat:`, `fix:`, `chore:`) and vague one-word messages are forbidden.

**Exactly one carve-out:** end-user-facing strings — UI text, transactional
email, product copy. That is product i18n for a Brazilian audience, not
repository content.

History is not rewritten: Portuguese messages already in the log stay as they
are.

<!-- /RELEASES-RULE -->
