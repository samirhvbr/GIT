# Auto Git

Scripts utilitários para gerenciar **todos os repositórios** do workspace `~/x/`
de uma vez só: clonar, atualizar (`pull`) e enviar (`push`) em lote.

Este repositório fica em `~/x/git/` e os projetos são clonados um nível acima,
em `~/x/` — chamada de **BASE** pelos scripts. Origin deste repo:
`https://github.com/samirhvbr/GIT.git`.

## Requisitos

- **`git`** (todos os scripts).
- **GitHub CLI (`gh`)** autenticado — usado pelo `git_clone` para clonar **sem pedir
  usuário/senha**, igual no Windows e no Linux. Instale em <https://cli.github.com> e rode
  `gh auth login` (uma vez por máquina). `git_pull`/`git_push` usam `git` direto.

## Estrutura

```
git/
├── README.md          # este arquivo
├── git_clone.sh       # clona os 17 repos (Linux/macOS)
├── git_clone.cmd      # equivalente do clone para Windows (cmd)
├── git_pull.sh        # git pull --ff-only em todos os repos (Linux/macOS)
├── git_pull.cmd       # equivalente do pull para Windows (cmd)
├── git_push.sh        # status + git push em todos os repos (Linux/macOS)
├── git_push.cmd       # equivalente do push para Windows (cmd)
├── .gitattributes     # eol=lf para *.sh, eol=crlf para *.cmd
├── .gitignore         # ignora tudo, versiona só os arquivos do utilitário
└── .claude/
    └── README.md      # notas de configuração do Claude Code (Blue3)
```

## Scripts

| Script          | Plataforma   | O que faz |
|-----------------|--------------|-----------|
| `git_clone.sh`  | Linux/macOS  | Clona os 17 repositórios via `gh repo clone`, reconstruindo a árvore de pastas. Pula os que já têm `.git`; recusa pastas existentes não vazias. |
| `git_clone.cmd` | Windows (cmd)| Mesma função do `git_clone.sh` (também via `gh repo clone`), em batch. Textos sem acento por compatibilidade com o code page do `cmd`. |
| `git_pull.sh`   | Linux/macOS  | Auto-descobre todo repositório git até 3 níveis abaixo da BASE e roda `git pull --ff-only` em cada um. |
| `git_pull.cmd`  | Windows (cmd)| Mesma função do `git_pull.sh`, em batch. Descobre os repos em `BASE\repo` e `BASE\grupo\repo`. |
| `git_push.sh`   | Linux/macOS  | Auto-descobre os repos, mostra branch, avisa sobre arquivos com commit pendente e faz `git push` dos commits prontos. |
| `git_push.cmd`  | Windows (cmd)| Mesma função do `git_push.sh`, em batch. Descobre os repos em `BASE\repo` e `BASE\grupo\repo`. |

A lista de repositórios e seus destinos é fixa só no `git_clone` (origin de cada
repo). `git_pull` e `git_push` **descobrem** os repositórios automaticamente
varrendo a BASE, então refletem sempre as pastas presentes no momento.

## Uso

```bash
# Linux/macOS — a partir de ~/x/git/
./git_clone.sh      # clona tudo na primeira vez
./git_pull.sh       # atualiza todos os repos
./git_push.sh       # envia commits pendentes de todos os repos
```

```bat
:: Windows — a partir de ~/x/git/
git_clone.cmd      :: clona tudo na primeira vez
git_pull.cmd       :: atualiza todos os repos
git_push.cmd       :: envia commits pendentes de todos os repos
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
- **`.gitignore`**: ignora tudo por padrão e versiona apenas os próprios
  arquivos do utilitário (`README.md`, `git_*`, `.gitattributes`, `.gitignore`,
  `.claude/`).
- **`.claude/README.md`**: documenta a configuração do Claude Code usada no
  contexto Blue3 (modelo, effort, permissões bloqueadas).
