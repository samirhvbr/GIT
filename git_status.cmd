@echo off
setlocal enabledelayedexpansion
rem git_status.cmd v1.0.0 - equivalente Windows do git_status.sh
rem Verificador de status (SOMENTE LEITURA) dos repos git sob a BASE
rem (BASE\repo e BASE\grupo\repo). Mostra o branch, commits a enviar/atras
rem do remoto e os arquivos pendentes de commit. NAO altera nada: nao faz
rem add, commit, pull nem push.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.0.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\git\, entao
rem subimos de git\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

echo git_status.cmd v%VERSION% - base: %BASE%
echo.

set /a CLEAN=0, DIRTY=0
set "CLEANLIST="
set "DIRTYLIST="

rem Nivel 1: BASE\repo. Se nao for repo, olha um nivel abaixo (BASE\grupo\repo).
for /d %%D in ("%BASE%\*") do (
    if exist "%%D\.git" (
        call :status "%%D"
    ) else (
        for /d %%E in ("%%D\*") do (
            if exist "%%E\.git" call :status "%%E"
        )
    )
)

echo.
echo ==============================
echo   Limpo: %CLEAN%   Pendente: %DIRTY%
if defined DIRTYLIST echo   Pendente: %DIRTYLIST%
if defined CLEANLIST echo   Limpo:    %CLEANLIST%
echo.
pause
exit /b 0

:status
set "repo=%~1"
set "rel=!repo:%BASE%\=!"
echo.
echo -- !rel!
cd /d "%repo%"
set "branch="
for /f "delims=" %%b in ('git branch --show-current 2^>nul') do set "branch=%%b"
if not defined branch set "branch=(detached)"
echo    branch: !branch!

rem Commits locais a enviar / atras do remoto (se houver upstream).
set "ahead=0"
set "behind=0"
for /f %%a in ('git rev-list --count @{u}..HEAD 2^>nul') do set "ahead=%%a"
for /f %%a in ('git rev-list --count HEAD..@{u} 2^>nul') do set "behind=%%a"
if not "!ahead!"=="0"  echo    ^> !ahead! commit^(s^) local^(is^) a enviar
if not "!behind!"=="0" echo    ^< !behind! commit^(s^) atras do remoto

rem Arquivos modificados/staged/untracked ainda nao commitados.
set "dirty=0"
for /f %%c in ('git status --porcelain 2^>nul ^| find /c /v ""') do set "dirty=%%c"
if not "!dirty!"=="0" (
    echo    [*] !dirty! arquivo^(s^) pendente^(s^) de commit:
    for /f "delims=" %%f in ('git status --porcelain 2^>nul') do echo          %%f
    set /a DIRTY+=1
    set "DIRTYLIST=!DIRTYLIST! !rel!"
) else (
    echo    [ok] limpo ^(nada pendente de commit^)
    set /a CLEAN+=1
    set "CLEANLIST=!CLEANLIST! !rel!"
)
exit /b 0
