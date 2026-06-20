#!/bin/bash
# clone_drive.sh v1.0.0
set -euo pipefail

VERSION="1.0.0"
# repos: 48 (lista auto-gerada de ~/x/DRIVE em 2026-06-20)
#
# Reconstrói o espelho do Nextcloud em ~/x/DRIVE/ — clona cada repositório
# oficial nextcloud/* na pasta de destino correspondente. Mesma mecânica do
# git_clone.sh; idempotente (pula o que já existe, não mexe em pasta cheia).
#
# Para REGERAR esta lista depois que o Nextcloud sincronizar mais repos:
#   while IFS= read -r g; do r="${g%/.git}"; d="${r#"$HOME/x"/}"; \
#     printf '    "%s|%s"\n' "$(git -C "$r" remote get-url origin)" "$d"; \
#   done < <(find "$HOME/x/DRIVE" -maxdepth 3 -type d -name .git | sort)
#
# BASE = pasta-mãe deste script (clona para ~/x/, um nível acima de git/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$(dirname "$SCRIPT_DIR")"

# Formato: "URL_DO_REPO|PASTA_DESTINO"  (destino relativo a BASE).
REPOS=(
    "git@github.com:nextcloud/admin_notifications.git|DRIVE/admin_notifications"
    "git@github.com:nextcloud/all-in-one.git|DRIVE/ALLinONE"
    "git@github.com:nextcloud/android.git|DRIVE/ANDROID"
    "git@github.com:nextcloud/apple-clients.git|DRIVE/apple-clients"
    "git@github.com:nextcloud/appstore.git|DRIVE/appstore"
    "git@github.com:nextcloud/files_antivirus.git|DRIVE/AVIRUS"
    "git@github.com:nextcloud/bookmarks.git|DRIVE/BOOKMARKS"
    "git@github.com:nextcloud/bruteforcesettings.git|DRIVE/BRUTEFORCE"
    "git@github.com:nextcloud/calendar.git|DRIVE/CALENDAR"
    "git@github.com:nextcloud/deck.git|DRIVE/deck"
    "git@github.com:nextcloud/desktop.git|DRIVE/DESKTOP"
    "git@github.com:nextcloud/documentation.git|DRIVE/docs"
    "git@github.com:nextcloud/files_filter.git|DRIVE/files_filter"
    "git@github.com:nextcloud/files_zip.git|DRIVE/files_zip"
    "git@github.com:nextcloud/groupquota.git|DRIVE/groupquota"
    "git@github.com:nextcloud/groupware.git|DRIVE/groupware"
    "git@github.com:nextcloud/integration_gptzero.git|DRIVE/integration_gptzero"
    "git@github.com:nextcloud/integration_openai.git|DRIVE/integration_openai"
    "git@github.com:nextcloud/ios.git|DRIVE/IOS"
    "git@github.com:nextcloud/NextcloudKit.git|DRIVE/IOS_KIT"
    "git@github.com:nextcloud/ldap_contacts_backend.git|DRIVE/ldap_contacts_backend"
    "git@github.com:nextcloud/limit_login_to_ip.git|DRIVE/limit_login_to_ip"
    "git@github.com:nextcloud/mail.git|DRIVE/MAIL"
    "git@github.com:nextcloud/news.git|DRIVE/news"
    "git@github.com:nextcloud/nextcloud.com.git|DRIVE/nextcloud.com"
    "git@github.com:nextcloud/nextcloud-register.git|DRIVE/nextcloud-register"
    "git@github.com:nextcloud/nextcloud-theme.git|DRIVE/nextcloud-theme"
    "git@github.com:nextcloud/notes-android.git|DRIVE/notes-android"
    "git@github.com:nextcloud/notes.git|DRIVE/notes"
    "git@github.com:nextcloud/notify_push.git|DRIVE/notify_push"
    "git@github.com:nextcloud/office.git|DRIVE/office"
    "git@github.com:nextcloud/queue.git|DRIVE/queue"
    "git@github.com:nextcloud/richdocuments.git|DRIVE/richdocuments"
    "git@github.com:nextcloud/nextcloudpi.git|DRIVE/RPI"
    "git@github.com:nextcloud/server.git|DRIVE/SERVER"
    "git@github.com:nextcloud/serverinfo.git|DRIVE/serverinfo"
    "git@github.com:nextcloud/spreed.git|DRIVE/spreed"
    "git@github.com:nextcloud/spreed-screensharing-chrome-extension.git|DRIVE/spreed-screensharing-chrome-extension"
    "git@github.com:nextcloud/spreed-screensharing-firefox-addon.git|DRIVE/spreed-screensharing-firefox-addon"
    "git@github.com:nextcloud/tasks.git|DRIVE/tasks"
    "git@github.com:nextcloud/text.git|DRIVE/text"
    "git@github.com:nextcloud/twofactor_gateway.git|DRIVE/twofactor_gateway"
    "git@github.com:nextcloud/twofactor_totp.git|DRIVE/twofactor_totp"
    "git@github.com:nextcloud/twofactor_webauthn.git|DRIVE/twofactor_webauthn"
    "git@github.com:nextcloud/user_external.git|DRIVE/user_external"
    "git@github.com:nextcloud/user_retention.git|DRIVE/user_retention"
    "git@github.com:nextcloud/weather.git|DRIVE/weather"
    "git@github.com:nextcloud/whiteboard.git|DRIVE/whiteboard"
)

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

echo -e "${BOLD}clone_drive.sh v${VERSION} — base: ${BASE} (${#REPOS[@]} repos)${NC}"

ok=(); skip=(); fail=()

for entry in "${REPOS[@]}"; do
    url="${entry%%|*}"
    dest="${entry##*|}"
    target="$BASE/$dest"

    echo -e "\n${CYAN}${BOLD}── $dest${NC}"
    echo -e "   ${url}"

    # Já clonado: pula
    if [ -d "$target/.git" ]; then
        echo -e "   ${YELLOW}Já existe — pulando${NC}"
        skip+=("$dest"); continue
    fi

    # Pasta existe e não está vazia (sem .git): não mexe
    if [ -d "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
        echo -e "   ${RED}✗ Pasta existe e não está vazia${NC}"
        fail+=("$dest"); continue
    fi

    mkdir -p "$(dirname "$target")"
    if git clone "$url" "$target" 2>&1 | sed 's/^/   /'; then
        ok+=("$dest")
    else
        fail+=("$dest")
    fi
done

echo -e "\n${BOLD}══════════════════════════════${NC}"
[ ${#ok[@]}   -gt 0 ] && echo -e "${GREEN}  ✓ Clonado:   ${ok[*]}${NC}"
[ ${#skip[@]} -gt 0 ] && echo -e "${YELLOW}  ⊙ Já existia: ${skip[*]}${NC}"
[ ${#fail[@]} -gt 0 ] && echo -e "${RED}  ✗ Falhou:    ${fail[*]}${NC}"
echo ""
