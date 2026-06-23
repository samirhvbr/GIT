@echo off
setlocal
rem clone.cmd v1.1.0 - equivalente Windows do git_clone.sh
rem Clona os 17 repositorios via GitHub CLI (gh), reconstruindo a estrutura de pastas.
rem gh usa a auth do proprio gh (sem pedir usuario/senha) - igual no Windows e no Linux.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.1.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\git\, entao
rem subimos de git\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

echo clone.cmd v%VERSION% - base: %BASE%
echo.

rem Pre-requisito: gh instalado e autenticado.
where gh >nul 2>nul
if errorlevel 1 (
    echo gh GitHub CLI nao encontrado. Instale: https://cli.github.com  e rode: gh auth login
    pause
    exit /b 1
)
gh auth status >nul 2>nul
if errorlevel 1 (
    echo gh nao autenticado. Rode: gh auth login
    pause
    exit /b 1
)

set /a OK=0, SKIP=0, FAIL=0

rem Formato: call :clone "OWNER/REPO"  "DEST"   (DEST relativo a BASE, com \ )
call :clone "samirhvbr/AREA81"                  "AREA81"
call :clone "samirhvbr/BLUE3_F1"                "BLUE3\F1"
call :clone "samirhvbr/BLUE3_INTRANET"          "BLUE3\INTRANET"
call :clone "samirhvbr/MEUIP"                   "BLUE3\MEUIP"
call :clone "samirhvbr/BLUE3-INTRANET-MOBILE"   "BLUE3\MOBILE"
call :clone "samirhvbr/BLUE3_SITE_FRONT"        "BLUE3\SITE"
call :clone "samirhvbr/BLUE3_WORLD_CUP_2026"    "BLUE3\WCUP"
call :clone "samirhvbr/GIT"                     "git"
call :clone "samirhvbr/GITHUB_DESKTOP"          "GITHUB_DESKTOP"
call :clone "samirhvbr/SHVIA"                   "IA"
call :clone "samirhvbr/MARTHINA_CLASS"          "KIDS\MARTHINA"
call :clone "samirhvbr/RAFAELA_MEMORIA"         "KIDS\RAFAELA_JOGO_MEMORIA"
call :clone "samirhvbr/BLUE3_DEBIAN_CUSTOM_ISO" "LINUX\B3_CUSTOM_ISO"
call :clone "samirhvbr/LINUX"                   "LINUX\KERNEL"
call :clone "samirhvbr/LINUX-START"             "LINUX\START"
call :clone "samirhvbr/SHVTERM"                 "SHVTERM\GUI"
call :clone "samirhvbr/SHVTERM-WEB"             "SHVTERM\SITE"

echo.
echo ==============================
echo   Clonado: %OK%   Ja existia: %SKIP%   Falhou: %FAIL%
echo.
pause
exit /b 0

:clone
set "repo=%~1"
set "dest=%~2"
set "target=%BASE%\%dest%"
echo -- %dest%
echo    %repo%
if exist "%target%\.git" (
    echo    Ja existe - pulando
    set /a SKIP+=1
    exit /b 0
)
gh repo clone "%repo%" "%target%"
if errorlevel 1 (
    echo    FALHOU
    set /a FAIL+=1
) else (
    set /a OK+=1
)
exit /b 0
