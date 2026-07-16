@echo off
setlocal
rem clone_all.cmd v1.1.0 - equivalente Windows do git_clone_all.sh
rem Clona TODOS os repositorios de um dono via GitHub CLI (gh repo list), sem
rem manter lista fixa. gh usa a auth do proprio gh (sem pedir usuario/senha).
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).
rem
rem Uso:
rem   git_clone_all.cmd                          (usuario do gh -> BASE)
rem   git_clone_all.cmd outro-usuario            (outro dono    -> BASE)
rem   git_clone_all.cmd outro-usuario C:\destino (outro dono    -> pasta escolhida)

set "VERSION=1.1.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\GIT\, entao subimos de
rem GIT\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

rem Destino: 2o argumento (pasta onde clonar), senao BASE (comportamento antigo).
if "%~2"=="" (set "DEST_DIR=%BASE%") else (set "DEST_DIR=%~2")

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

rem Dono: 1o argumento, senao o usuario autenticado no gh.
if "%~1"=="" (
    for /f "usebackq delims=" %%u in (`gh api user --jq ".login"`) do set "OWNER=%%u"
) else (
    set "OWNER=%~1"
)
if not defined OWNER (
    echo Nao foi possivel descobrir o usuario do gh. Passe explicito: git_clone_all.cmd ^<usuario^>
    pause
    exit /b 1
)

echo clone_all.cmd v%VERSION% - dono: %OWNER%  destino: %DEST_DIR%
echo.
if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"

set /a OK=0, SKIP=0, FAIL=0, FOUND=0

echo Consultando repositorios de %OWNER%...
for /f "usebackq delims=" %%r in (`gh repo list "%OWNER%" --no-archived --limit 1000 --json nameWithOwner --jq ".[].nameWithOwner"`) do call :clone "%%r"

if %FOUND%==0 (
    echo Nenhum repositorio encontrado para %OWNER% ^(ou falha na consulta^).
    pause
    exit /b 0
)

echo.
echo ==============================
echo   Clonado: %OK%   Ja existia: %SKIP%   Falhou: %FAIL%
echo.
pause
exit /b 0

:clone
set /a FOUND+=1
set "repo=%~1"
rem Clone plano: a pasta usa so o nome do repo (owner/REPO -> REPO).
for /f "tokens=2 delims=/" %%n in ("%repo%") do set "dest=%%n"
set "target=%DEST_DIR%\%dest%"
echo -- %dest%
echo    %repo%
if exist "%target%\.git" (
    echo    Ja existe - pulando
    set /a SKIP+=1
    exit /b 0
)
rem Pasta existe e nao esta vazia (sem .git): nao mexe.
dir /b /a "%target%" >nul 2>nul && (
    echo    Pasta existe e nao esta vazia
    set /a FAIL+=1
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
