@echo off
setlocal
rem clone.cmd v1.0.0 - equivalente Windows do git_clone.sh
rem Clona os 16 repositorios reconstruindo a estrutura de pastas atual.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.0.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\git\, entao
rem subimos de git\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

echo clone.cmd v%VERSION% - base: %BASE%
echo.

set /a OK=0, SKIP=0, FAIL=0

rem Formato: call :clone "URL"  "DEST"   (DEST relativo a BASE, com \ )
call :clone "git@github.com:samirhvbr/AREA81.git"                  "AREA81"
call :clone "git@github.com:samirhvbr/BLUE3_F1.git"                "BLUE3\F1"
call :clone "git@github.com:samirhvbr/BLUE3_INTRANET.git"          "BLUE3\INTRANET"
call :clone "git@github.com:samirhvbr/MEUIP.git"                   "BLUE3\MEUIP"
call :clone "git@github.com:samirhvbr/BLUE3-INTRANET-MOBILE.git"   "BLUE3\MOBILE"
call :clone "git@github.com:samirhvbr/BLUE3_SITE_FRONT.git"        "BLUE3\SITE"
call :clone "git@github.com:samirhvbr/BLUE3_WORLD_CUP_2026.git"    "BLUE3\WCUP"
call :clone "git@github.com:samirhvbr/GIT.git"                     "git"
call :clone "git@github.com:samirhvbr/SHVIA.git"                   "IA"
call :clone "git@github.com:samirhvbr/MARTHINA_CLASS.git"          "KIDS\MARTHINA"
call :clone "git@github.com:samirhvbr/RAFAELA_MEMORIA.git"         "KIDS\RAFAELA_JOGO_MEMORIA"
call :clone "git@github.com:samirhvbr/BLUE3_DEBIAN_CUSTOM_ISO.git" "LINUX\B3_CUSTOM_ISO"
call :clone "git@github.com:samirhvbr/LINUX.git"                   "LINUX\KERNEL"
call :clone "git@github.com:samirhvbr/LINUX-START.git"             "LINUX\START"
call :clone "git@github.com:samirhvbr/SHVTERM.git"                 "SHVTERM\GUI"
call :clone "git@github.com:samirhvbr/SHVTERM-WEB.git"             "SHVTERM\SITE"

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
