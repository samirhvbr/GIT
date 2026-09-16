#!/bin/bash
# sync-version.sh — propaga o version.md para todos os scripts do repo.
#
# ── Por que existe ───────────────────────────────────────────────────────────
# Cada script tinha a SUA versão, e os pares .sh/.cmd — que são equivalentes por
# construção ("equivalente Windows do git_pull.sh") — divergiam: em 28/07/2026 o
# git_pull.sh estava 1.4.0 e o git_pull.cmd 1.0.0. Quem roda no Windows não tinha
# como saber se o script dele já tinha a correção que o irmão recebeu, porque o
# número não queria dizer a mesma coisa nos dois lados.
#
# Com o version.md como fonte ÚNICA, `pull.cmd v1.5.0` e `pull.sh v1.5.0`
# significam "saíram da mesma release deste repo" — que é a pergunta que o usuário
# realmente faz. A versão de cada ferramenta isolada vive no git log, que é onde
# esse tipo de detalhe se consulta.
#
# ── O que ele reescreve ──────────────────────────────────────────────────────
#   .sh   → VERSION="X.Y.Z"        e o `# nome.sh vX.Y.Z` do cabeçalho
#   .cmd  → set "VERSION=X.Y.Z"    e o `rem nome.cmd vX.Y.Z` do cabeçalho
#
# O NOME no comentário não é tocado, só a versão depois dele. Até a 1.8.13 isso
# importava: o cabeçalho dizia `# clone.sh` dentro de um arquivo chamado
# `git_clone.sh`, e consertar o nome aqui misturaria duas mudanças numa só. A
# 1.9.0 renomeou os arquivos para os nomes que os cabeçalhos já usavam, então
# hoje os dois coincidem — o sed continua sem tocar no nome, agora por não haver
# nada a corrigir.
#
# Idempotente: só escreve o arquivo que mudou de fato, e é silencioso quando tudo
# já está em dia — assim dá para rodar sem medo antes de cada commit.
#
# USO:  ./scripts/sync-version.sh            # aplica
#       ./scripts/sync-version.sh --check    # não escreve; sai != 0 se algo divergir
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1

VERSION="$(tr -d ' \t\n\r' < version.md)"
if ! printf '%s' "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "sync-version: versão inválida em version.md: '$VERSION' (esperado X.Y.Z)" >&2
  exit 1
fi

mudou=0
divergentes=""

# Escreve por REDIRECIONAMENTO no arquivo original (`cat > "$f"`), não por `mv`:
# `mv` substitui o inode e o arquivo perderia o bit de execução dos .sh.
aplicar() {
  local f="$1" novo="$2"
  if [ "$CHECK" -eq 1 ]; then
    divergentes="$divergentes $f"
    return 0
  fi
  printf '%s' "$novo" > "$f.tmp-sync" && cat "$f.tmp-sync" > "$f" && rm -f "$f.tmp-sync"
  echo "[sync-version] $f → $VERSION"
  mudou=$((mudou + 1))
}

for f in *.sh *.cmd; do
  [ -f "$f" ] || continue
  atual="$(cat "$f")"

  case "$f" in
    *.sh)
      novo="$(printf '%s' "$atual" \
        | sed -E "s/^VERSION=\"[0-9]+\.[0-9]+\.[0-9]+\"/VERSION=\"$VERSION\"/" \
        | sed -E "1,6s/^(# .*[[:space:]])v[0-9]+\.[0-9]+\.[0-9]+/\1v$VERSION/")"
      ;;
    *.cmd)
      novo="$(printf '%s' "$atual" \
        | sed -E "s/^set \"VERSION=[0-9]+\.[0-9]+\.[0-9]+\"/set \"VERSION=$VERSION\"/" \
        | sed -E "1,6s/^(rem .*[[:space:]])v[0-9]+\.[0-9]+\.[0-9]+/\1v$VERSION/")"
      ;;
  esac

  [ "$novo" = "$atual" ] || aplicar "$f" "$novo"
done

if [ "$CHECK" -eq 1 ]; then
  if [ -n "$divergentes" ]; then
    echo "sync-version: fora de sincronia com a $VERSION:$divergentes" >&2
    echo "  rode ./scripts/sync-version.sh" >&2
    exit 1
  fi
  echo "[sync-version] $VERSION — tudo em sincronia"
  exit 0
fi

echo "[sync-version] $VERSION ($mudou arquivo(s) atualizado(s))"
