# Padrão de Deploy — Apps Laravel (Blue3 / SHV)

Fonte da verdade para os `deploy.sh` dos projetos. **Projeto novo? Comece aqui:**
copie [`deploy.sh.template`](deploy.sh.template) para a raiz do projeto, ajuste o
bloco **Config** e siga o checklist de servidor abaixo.

---

## 1. Modelo de execução (o padrão)

**O deploy roda como `root`** e desce para os usuários auxiliares via `sudo`
(sem senha — root não precisa de NOPASSWD):

| Operação | Usuário | Por quê |
|---|---|---|
| `git` / `composer` / `npm` / `assets` | **OWNER** (dono do tree) | tocam `.git/`, `vendor/`, `node_modules/`, `public/` — precisam de quem é dono deles (evita *dubious ownership*) |
| `artisan` de runtime (`down`, backup, `migrate`, `*:cache`, `up`) | **WEB_USER** (web server) | escrevem em `storage/` e `bootstrap/cache/` — território do web server |

`OWNER` é **auto-detectado** (`stat -c %U $DIR`). `WEB_USER` é config (default `www-data`).

> **Por que root?** Unifica todos os deploys num único modo, dispensa configurar
> `sudo NOPASSWD`, e é o que destrava o lock em `/run` (próximo tópico).

---

## 2. Modelo de ownership no servidor

| Caminho | Dono:Grupo | Modo | Motivo |
|---|---|---|---|
| código (`app/`, `config/`, `routes/`, `vendor/`, `public/`, …) | `OWNER:WEB_USER` | dirs `2775`, arquivos `664` | web **só lê** o código (menor superfície de ataque) |
| `storage/`, `bootstrap/cache/` | `WEB_USER:WEB_USER` | `2775` | web **escreve** (cache, logs, sessões, views) |
| `.env` | `OWNER:WEB_USER` | `640` | web lê (via grupo); não é world-readable |

- **setgid (`2` / `drwxrwsr-x`)** nos diretórios → arquivos novos **herdam o grupo** `WEB_USER`.
- `vendor/` e `node_modules/` ficam com **OWNER** (o `composer`/`npm` roda como OWNER).
  Se derivarem para `www-data` (recuperação manual), o `heal_owner()` normaliza no
  próximo deploy que mexer neles.

---

## 3. Lock — sempre `/run`, nunca `/tmp`

```sh
LOCK="/run/${APP}-deploy.lock"
```

`/tmp` é *world-writable + sticky*; o hardening de kernel **`fs.protected_regular`**
impede **qualquer usuário (incluindo root)** de reabrir um arquivo que não é dele
nesse tipo de diretório. Resultado clássico: o deploy roda 1× como `b3sys`, cria
`/tmp/x.lock`, e o `root` depois leva **`Permission denied`** ao reabrir.

`/run` é tmpfs do root, limpo no boot (ideal pra lock) e sem esse problema.

---

## 4. Anatomia do `deploy.sh`

1. **Root check** → **Lock** (`flock` não-bloqueante: 2 deploys simultâneos → o 2º sai).
2. **Fetch + diff** — sai cedo se `HEAD == origin/BRANCH` (idempotente).
3. `git merge --ff-only` (sem merge-commit surpresa).
4. **Modo manutenção** (`artisan down`).
5. **Backup do banco** antes de tocar em schema (opcional via `BACKUP_CMD`).
6. **composer install** — só se `composer.lock` mudou (`--no-scripts`).
7. **npm ci + build** — só se o front mudou.
8. **migrate --force** — rollback do último batch se falhar.
9. **Caches** (`config/route/view/event:cache`).
10. **`artisan up`** + notificação (Telegram opcional).

`trap ... ERR` (a partir do passo 4): qualquer falha → sai da manutenção, tenta
rollback e avisa. Idempotência: rodar de novo é seguro.

---

## 5. Projeto novo — checklist

**No repositório:**
1. Copie `deploy.sh.template` → `deploy.sh` na raiz; `chmod +x deploy.sh`.
2. Ajuste o bloco **Config**: `DIR`, `APP`, `WEB_USER`, `BACKUP_CMD`, `BUILD_FRONTEND`.
3. Commit (segue a convenção do projeto: `versão - comentário`).

**No servidor (1ª vez, como root):**
```bash
# 1. Clonar como o OWNER (ex.: b3sys), pra .git já nascer com o dono certo
sudo -u b3sys git clone <url> /srv/www/<app>
cd /srv/www/<app>

# 2. Ownership: código = OWNER:WEB_USER ; runtime = WEB_USER
chown -R b3sys:www-data .
find . -type d -exec chmod 2775 {} \;          # setgid → grupo herdado
find . -type f -exec chmod 0664 {} \;
chown -R www-data:www-data storage bootstrap/cache
chmod 640 .env

# 3. Primeiro deploy
sudo bash deploy.sh
```

> Ajuste `b3sys` para o OWNER do projeto (varia por servidor). `WEB_USER` é o
> usuário do nginx/php-fpm (geralmente `www-data`).

---

## 6. Convenções

- **Cabeçalho:** `# versão X.Y - AAAA-MM-DD` no topo do `deploy.sh`. Bump ao alterar.
- **`.env` esperado:** `DEPLOY_TELEGRAM_BOT_TOKEN`, `DEPLOY_TELEGRAM_CHAT_ID`
  (notificação, opcional); `MARIADB_BACKUP_PATH` (se usar backup do MariaDB).
- **Branch:** `DEPLOY_BRANCH` (env) sobrescreve o default `master`.

---

## 7. Troubleshooting

| Sintoma | Causa | Correção |
|---|---|---|
| `lock: Permission denied` (como root) | lock em `/tmp` + `fs.protected_regular` | mover o lock p/ `/run` (já é o padrão) |
| `dubious ownership in repository` | `git` rodando como quem não é dono do `.git` | rodar git via `asowner` (como OWNER) |
| storage não grava (logs/cache) | `storage/` não é do `WEB_USER` | `chown -R www-data:www-data storage bootstrap/cache` |
| `rode como root` | rodou como usuário comum | `sudo bash deploy.sh` |
