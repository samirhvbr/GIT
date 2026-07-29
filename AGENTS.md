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
