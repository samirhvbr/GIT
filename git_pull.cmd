@echo off
setlocal enabledelayedexpansion
rem git_pull.cmd v1.0.0 - equivalente Windows do git_pull.sh
rem Auto-descobre os repos git sob a BASE (BASE\repo e BASE\grupo\repo)
rem e roda "git pull --ff-only" em cada um.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.0.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\git\, entao
rem subimos de git\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

echo git_pull.cmd v%VERSION% - base: %BASE%
echo.

set /a OK=0, FAIL=0
set "OKLIST="
set "FAILLIST="

rem Nivel 1: BASE\repo. Se nao for repo, olha um nivel abaixo (BASE\grupo\repo).
for /d %%D in ("%BASE%\*") do (
    if exist "%%D\.git" (
        call :pull "%%D"
    ) else (
        for /d %%E in ("%%D\*") do (
            if exist "%%E\.git" call :pull "%%E"
        )
    )
)

echo.
echo ==============================
echo   OK: %OK%   Falhou: %FAIL%
if defined OKLIST   echo   OK:    %OKLIST%
if defined FAILLIST echo   Falhou:%FAILLIST%
echo.
pause
exit /b 0

:pull
set "repo=%~1"
set "rel=!repo:%BASE%\=!"
echo.
echo -- !rel!
cd /d "%repo%"
set "branch="
for /f "delims=" %%b in ('git branch --show-current 2^>nul') do set "branch=%%b"
echo    branch: !branch!
git pull --ff-only
if errorlevel 1 (
    set /a FAIL+=1
    set "FAILLIST=!FAILLIST! !rel!"
) else (
    set /a OK+=1
    set "OKLIST=!OKLIST! !rel!"
)
exit /b 0
