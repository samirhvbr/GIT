# GIT — Instruções para Agentes de IA

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

Formato de commit: `versão - comentário em português`

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

## PS — Commits: a skill COMMITTER cuida disso

**Existe `.committer.yml` na raiz deste repositório** — é o opt-in da skill
**COMMITTER**, que roda em ciclo (cron, via `~/x/GIT/run.sh`). Enquanto esse arquivo
existir com `enabled: true`, **commitar e pushar não é trabalho seu**.

**O que muda para você:**

- **Não commite nem pushe por padrão.** Conclua a entrega bumpando o `version.md`
  **com a entrada de changelog** e deixe a árvore pronta. É dali que a mensagem do
  commit sai — o changelog virou o artefato de handoff entre você e a skill.
- A skill monta `X.Y.Z - descrição`, commita e pusha a branch atual sozinha. Ela
  **nunca bumpa versão** (isso continua sendo julgamento seu) e nunca inventa
  mensagem: sem entrada de changelog ela cai num fallback Sonnet, e sem conseguir
  descrever com honestidade ela aborta e espera.

**Você ainda commita quando:**

- o Samir pedir explicitamente;
- a tarefa exigir o SHA na hora (deploy, abrir PR, referência cruzada);
- o `.committer.yml` sumir ou estiver `enabled: false` — aí vale o fluxo antigo,
  você bumpa, commita e pusha.

**Por que isso existe:** tirar de um modelo caro (Opus/Fable) o trabalho mecânico de
empacotar commit, que um Sonnet — ou, na maioria das vezes, nenhum modelo — resolve.
Economiza token e devolve tempo de desenvolvimento.

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
