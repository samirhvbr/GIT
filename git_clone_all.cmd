@echo off
setlocal
rem clone_all.cmd v1.2.0 - equivalente Windows do git_clone_all.sh
rem Clona TODOS os repositorios de um dono via GitHub CLI (gh repo list), sem
rem manter lista fixa. gh usa a auth do proprio gh (sem pedir usuario/senha).
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).
rem
rem Uso:
rem   git_clone_all.cmd                          (usuario do gh -> BASE)
rem   git_clone_all.cmd outro-usuario            (outro dono    -> BASE)
rem   git_clone_all.cmd outro-usuario C:\destino (outro dono    -> pasta escolhida)

set "VERSION=1.2.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\GIT\, entao subimos de
rem GIT\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

rem Destino: 2o argumento (pasta onde clonar), senao BASE (comportamento antigo).
if "%~2"=="" (set "DEST_DIR=%BASE%") else (set "DEST_DIR=%~2")

rem Pre-requisito: gh instalado.
where gh >nul 2>nul
if errorlevel 1 (
    echo gh GitHub CLI nao encontrado. Instale: https://cli.github.com  e rode: gh auth login
    pause
    exit /b 1
)

rem Auth: NAO usar "gh auth status" como porteiro - num 503 transitorio ele
rem reporta "The token in keyring is invalid" e sai 1 com o token valido.
rem O teste honesto e uma chamada real a API, com retry (o 503 e intermitente).
set "RETRIES=5"
set "GH_TMP=%TEMP%\gh_login_%RANDOM%%RANDOM%.txt"
set "GH_LOGIN="
for /L %%a in (1,1,%RETRIES%) do if not defined GH_LOGIN call :try_login
del "%GH_TMP%" 2>nul
if not defined GH_LOGIN (
    echo Nao foi possivel falar com a API do GitHub apos %RETRIES% tentativas.
    echo Resposta da ultima tentativa:
    echo.
    gh api user
    echo.
    echo Se aparecer HTTP 503 / "invalid character", e instabilidade do GitHub:
    echo espere alguns minutos e rode de novo - seu login esta OK.
    echo Se for 401/403, ai sim rode: gh auth login
    pause
    exit /b 1
)

rem Dono: 1o argumento, senao o usuario autenticado no gh.
if "%~1"=="" (set "OWNER=%GH_LOGIN%") else (set "OWNER=%~1")

echo clone_all.cmd v%VERSION% - dono: %OWNER%  destino: %DEST_DIR%
echo.
if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"

set /a OK=0, SKIP=0, FAIL=0, FOUND=0

rem A listagem tambem sofre com o 503 intermitente. Gravamos num arquivo
rem temporario com retry: assim "lista vazia" (dono sem repos) nunca se
rem confunde com "a consulta falhou".
set "REPOS_TMP=%TEMP%\gh_repos_%RANDOM%%RANDOM%.txt"
set "LISTED="
echo Consultando repositorios de %OWNER%...
for /L %%a in (1,1,%RETRIES%) do (
    if not defined LISTED (
        gh repo list "%OWNER%" --no-archived --limit 1000 --json nameWithOwner --jq ".[].nameWithOwner" > "%REPOS_TMP%" 2>nul && set "LISTED=1"
        if not defined LISTED ping -n 3 127.0.0.1 >nul
    )
)
if not defined LISTED (
    del "%REPOS_TMP%" 2>nul
    echo Falha ao listar os repositorios de %OWNER% apos %RETRIES% tentativas.
    echo Resposta da ultima tentativa:
    echo.
    gh repo list "%OWNER%" --no-archived --limit 1000 --json nameWithOwner --jq ".[].nameWithOwner"
    echo.
    echo Se for HTTP 503, e instabilidade do GitHub - tente de novo em alguns minutos.
    pause
    exit /b 1
)

for /f "usebackq delims=" %%r in ("%REPOS_TMP%") do call :clone "%%r"
del "%REPOS_TMP%" 2>nul

if %FOUND%==0 (
    echo Nenhum repositorio encontrado para %OWNER%.
    pause
    exit /b 0
)

echo.
echo ==============================
echo   Clonado: %OK%   Ja existia: %SKIP%   Falhou: %FAIL%
echo.
pause
exit /b 0

:try_login
rem Em erro o "gh api" manda o JSON do erro para o STDOUT (so o resumo vai para
rem o stderr): sem checar o errorlevel antes, GH_LOGIN viraria "{".
gh api user --jq ".login" > "%GH_TMP%" 2>nul
if errorlevel 1 (
    ping -n 3 127.0.0.1 >nul
    exit /b 0
)
for /f "usebackq delims=" %%u in ("%GH_TMP%") do set "GH_LOGIN=%%u"
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
rem Nao dah para usar o errorlevel do dir: "dir /b /a <pasta vazia>" sai com 0,
rem entao qualquer pasta existente parecia "nao vazia" e bloqueava o clone.
rem O teste honesto e ver se o dir produziu ao menos uma linha.
set "NOTEMPTY="
for /f "delims=" %%x in ('dir /b /a "%target%" 2^>nul') do set "NOTEMPTY=1"
if defined NOTEMPTY (
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
