# Auto Git

Scripts utilitários para gerenciar **todos os repositórios** do workspace `~/x/`
de uma vez só: clonar, atualizar (`pull`) e enviar (`push`) em lote.

Este repositório fica em `~/x/git/` e os projetos são clonados um nível acima,
em `~/x/` — chamada de **BASE** pelos scripts. Origin deste repo:
`https://github.com/samirhvbr/GIT.git`.

## 🔄 Antes de começar: `git pull`

**SEMPRE** puxe atualizações remotas antes de escrever ou alterar qualquer coisa. `git pull` está pré-autorizado (allow). Aqui no workspace `~/x/` dá para atualizar **todos** os repositórios de uma vez com `pull.sh`; para um único repo, basta `git pull`.

```bash
git pull            # este repo
./pull.sh       # todos os repositórios do ~/x de uma vez
```

Trabalhar sobre base desatualizada gera conflitos. Puxe primeiro, sempre.

## Requisitos

- **`git`** (todos os scripts).
- **GitHub CLI (`gh`)** autenticado — usado pelo `clone` para clonar **sem pedir
  usuário/senha**, igual no Windows e no Linux. Instale em <https://cli.github.com> e rode
  `gh auth login` (uma vez por máquina). `pull`/`push` usam `git` direto.

## Estrutura

```
git/
├── README.md          # este arquivo
├── clone.sh       # clona os 17 repos (Linux/macOS)
├── clone.cmd      # equivalente do clone para Windows (cmd)
├── pull.sh        # git pull --ff-only em todos os repos (Linux/macOS)
├── pull.cmd       # equivalente do pull para Windows (cmd)
├── push.sh        # status + git push em todos os repos (Linux/macOS)
├── push.cmd       # equivalente do push para Windows (cmd)
├── status.sh      # git status (somente leitura) em todos os repos (Linux/macOS)
├── status.cmd     # equivalente do status para Windows (cmd)
├── run.sh             # varre os repos e roda as SKILLS da casa (COMMITTER/AUDITOR)
├── .gitattributes     # eol=lf para *.sh, eol=crlf para *.cmd
├── .gitignore         # versiona tudo, ignora só o que está nomeado nele
├── deploy/
│   ├── deploy.sh.template  # modelo de deploy Laravel (copiar p/ raiz do projeto)
│   └── README.md           # padrão de deploy (ownership, lock, checklist)
├── .continue/
│   └── README_20260623.md  # notas do Continue
└── .claude/
    └── README.md      # notas de configuração do Claude Code (Blue3)
```

## Scripts

| Script          | Plataforma   | O que faz |
|-----------------|--------------|-----------|
| `clone.sh`  | Linux/macOS  | Clona os 17 repositórios via `gh repo clone`, reconstruindo a árvore de pastas. Pula os que já têm `.git`; recusa pastas existentes não vazias. |
| `clone.cmd` | Windows (cmd)| Mesma função do `clone.sh` (também via `gh repo clone`), em batch. Textos sem acento por compatibilidade com o code page do `cmd`. |
| `pull.sh`   | Linux/macOS  | Auto-descobre todo repositório git até 3 níveis abaixo da BASE e roda `git pull --ff-only` em cada um. A falha do pull sai com o motivo — sem upstream, branch apagada no remoto, divergiu, árvore suja, conflito, remoto inacessível — e o resumo agrupa as falhas por ele. |
| `pull.cmd`  | Windows (cmd)| Mesma função do `pull.sh`, em batch. Descobre os repos em `BASE\repo` e `BASE\grupo\repo`. Mesmo relato do motivo da falha. |
| `push.sh`   | Linux/macOS  | Auto-descobre os repos, mostra branch, avisa sobre arquivos com commit pendente e faz `git push` dos commits prontos. |
| `push.cmd`  | Windows (cmd)| Mesma função do `push.sh`, em batch. Descobre os repos em `BASE\repo` e `BASE\grupo\repo`. |
| `status.sh` | Linux/macOS  | Auto-descobre os repos e roda `git status` **somente leitura** em cada um: branch, commits a enviar/atrás do remoto e arquivos pendentes. Não altera nada. Aceita pastas a pular por argumento. |
| `status.cmd`| Windows (cmd)| Mesma função do `status.sh` (somente leitura), em batch. Mostra branch, commits a enviar/atrás e arquivos pendentes. |
| `run.sh`        | Linux        | Auto-descobre os repos (igual ao `pull.sh`), filtra os que **optaram por uma skill da casa** e roda o ciclo dela. Hoje: COMMITTER (marcador `.committer.yml`) e AUDITOR (`.auditor/config.yml`, ainda sem executor headless). Pula o balde de terceiros (`000/`) sempre. Aceita `--dry-run`, `--list`, `--quiet-min N` e pastas a pular por argumento. É o que a crontab chama — assim repo novo entra na varredura só criando o marcador, sem editar a crontab. |

A lista de repositórios e seus destinos é fixa só no `clone` (origin de cada
repo). `pull` e `push` **descobrem** os repositórios automaticamente
varrendo a BASE, então refletem sempre as pastas presentes no momento.

## Uso

```bash
# Linux/macOS — a partir de ~/x/git/
./clone.sh      # clona tudo na primeira vez
./pull.sh       # atualiza todos os repos
./push.sh       # envia commits pendentes de todos os repos
```

```bat
:: Windows — a partir de ~/x/git/
clone.cmd      :: clona tudo na primeira vez
pull.cmd       :: atualiza todos os repos
push.cmd       :: envia commits pendentes de todos os repos
```

## Repositórios gerenciados

Mapeamento `repositório → pasta destino` (relativo a `~/x/`):

| Repositório (GitHub)                | Destino                       |
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

Os clones usam o **GitHub CLI** (`gh repo clone`): a auth é gerenciada pelo `gh` — sem pedir
usuário/senha e sem configurar chave SSH por máquina —, igual no Windows e no Linux. O protocolo
(ssh/https) segue `gh config get git_protocol`.

## Notas

- **Line endings** (`.gitattributes`): `*.sh` sempre LF, `*.cmd` sempre CRLF —
  o repo roda tanto em Linux quanto em Windows.
- **`.gitignore`**: polaridade normal desde a `1.8.11` — versiona tudo, e
  arquivo só fica de fora sendo nomeado lá (`*.tmp-sync`,
  `.claude/settings.local.json`, `.loop/`, lixo de SO). **Não há exigência de
  nome para script novo**: o whitelist antigo só aceitava `git_*` e engolia o
  resto em silêncio — foi assim que o `CHANGELOG.md` e os dois hooks do git
  passaram meses fora do repositório sem o `git status` dizer nada.
- **`deploy/`**: fonte da verdade do `deploy.sh.template` (padrão de deploy
  Laravel) — copiado para a raiz de cada projeto. Segredos vêm do `.env` em
  runtime, nunca versionados.
- **`.claude/README.md`**: documenta a configuração do Claude Code usada no
  contexto Blue3 (modelo, effort, permissões bloqueadas).
