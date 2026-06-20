@echo off
setlocal
rem clone_drive.cmd v1.0.0 - equivalente Windows do git_clone_drive.sh
rem Reconstroi o espelho do Nextcloud em DRIVE\ (clona nextcloud\* oficial).
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.0.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\git\, entao
rem subimos de git\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

echo clone_drive.cmd v%VERSION% - base: %BASE%
echo.

set /a OK=0, SKIP=0, FAIL=0

rem Formato: call :clone "URL"  "DEST"   (DEST relativo a BASE, com \ )
call :clone "git@github.com:nextcloud/admin_notifications.git"  "DRIVE\admin_notifications"
call :clone "git@github.com:nextcloud/all-in-one.git"  "DRIVE\ALLinONE"
call :clone "git@github.com:nextcloud/android.git"  "DRIVE\ANDROID"
call :clone "git@github.com:nextcloud/apple-clients.git"  "DRIVE\apple-clients"
call :clone "git@github.com:nextcloud/appstore.git"  "DRIVE\appstore"
call :clone "git@github.com:nextcloud/files_antivirus.git"  "DRIVE\AVIRUS"
call :clone "git@github.com:nextcloud/bookmarks.git"  "DRIVE\BOOKMARKS"
call :clone "git@github.com:nextcloud/bruteforcesettings.git"  "DRIVE\BRUTEFORCE"
call :clone "git@github.com:nextcloud/calendar.git"  "DRIVE\CALENDAR"
call :clone "git@github.com:nextcloud/deck.git"  "DRIVE\deck"
call :clone "git@github.com:nextcloud/desktop.git"  "DRIVE\DESKTOP"
call :clone "git@github.com:nextcloud/documentation.git"  "DRIVE\docs"
call :clone "git@github.com:nextcloud/files_filter.git"  "DRIVE\files_filter"
call :clone "git@github.com:nextcloud/files_zip.git"  "DRIVE\files_zip"
call :clone "git@github.com:nextcloud/groupquota.git"  "DRIVE\groupquota"
call :clone "git@github.com:nextcloud/groupware.git"  "DRIVE\groupware"
call :clone "git@github.com:nextcloud/integration_gptzero.git"  "DRIVE\integration_gptzero"
call :clone "git@github.com:nextcloud/integration_openai.git"  "DRIVE\integration_openai"
call :clone "git@github.com:nextcloud/ios.git"  "DRIVE\IOS"
call :clone "git@github.com:nextcloud/NextcloudKit.git"  "DRIVE\IOS_KIT"
call :clone "git@github.com:nextcloud/ldap_contacts_backend.git"  "DRIVE\ldap_contacts_backend"
call :clone "git@github.com:nextcloud/limit_login_to_ip.git"  "DRIVE\limit_login_to_ip"
call :clone "git@github.com:nextcloud/mail.git"  "DRIVE\MAIL"
call :clone "git@github.com:nextcloud/news.git"  "DRIVE\news"
call :clone "git@github.com:nextcloud/nextcloud.com.git"  "DRIVE\nextcloud.com"
call :clone "git@github.com:nextcloud/nextcloud-register.git"  "DRIVE\nextcloud-register"
call :clone "git@github.com:nextcloud/nextcloud-theme.git"  "DRIVE\nextcloud-theme"
call :clone "git@github.com:nextcloud/notes-android.git"  "DRIVE\notes-android"
call :clone "git@github.com:nextcloud/notes.git"  "DRIVE\notes"
call :clone "git@github.com:nextcloud/notify_push.git"  "DRIVE\notify_push"
call :clone "git@github.com:nextcloud/office.git"  "DRIVE\office"
call :clone "git@github.com:nextcloud/queue.git"  "DRIVE\queue"
call :clone "git@github.com:nextcloud/richdocuments.git"  "DRIVE\richdocuments"
call :clone "git@github.com:nextcloud/nextcloudpi.git"  "DRIVE\RPI"
call :clone "git@github.com:nextcloud/server.git"  "DRIVE\SERVER"
call :clone "git@github.com:nextcloud/serverinfo.git"  "DRIVE\serverinfo"
call :clone "git@github.com:nextcloud/spreed.git"  "DRIVE\spreed"
call :clone "git@github.com:nextcloud/spreed-screensharing-chrome-extension.git"  "DRIVE\spreed-screensharing-chrome-extension"
call :clone "git@github.com:nextcloud/spreed-screensharing-firefox-addon.git"  "DRIVE\spreed-screensharing-firefox-addon"
call :clone "git@github.com:nextcloud/tasks.git"  "DRIVE\tasks"
call :clone "git@github.com:nextcloud/text.git"  "DRIVE\text"
call :clone "git@github.com:nextcloud/twofactor_gateway.git"  "DRIVE\twofactor_gateway"
call :clone "git@github.com:nextcloud/twofactor_totp.git"  "DRIVE\twofactor_totp"
call :clone "git@github.com:nextcloud/twofactor_webauthn.git"  "DRIVE\twofactor_webauthn"
call :clone "git@github.com:nextcloud/user_external.git"  "DRIVE\user_external"
call :clone "git@github.com:nextcloud/user_retention.git"  "DRIVE\user_retention"
call :clone "git@github.com:nextcloud/weather.git"  "DRIVE\weather"
call :clone "git@github.com:nextcloud/whiteboard.git"  "DRIVE\whiteboard"

echo.
echo ==============================
echo   Clonado: %OK%   Ja existia: %SKIP%   Falhou: %FAIL%
echo.
pause
exit /b 0

:clone
set "url=%~1"
set "dest=%~2"
set "target=%BASE%\%dest%"
echo -- %dest%
echo    %url%
if exist "%target%\.git" (
    echo    Ja existe - pulando
    set /a SKIP+=1
    exit /b 0
)
git clone "%url%" "%target%"
if errorlevel 1 (
    echo    FALHOU
    set /a FAIL+=1
) else (
    set /a OK+=1
)
exit /b 0
