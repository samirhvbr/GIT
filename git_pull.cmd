@echo off
setlocal enabledelayedexpansion
rem git_pull.cmd v1.8.13 - equivalente Windows do git_pull.sh
rem Auto-descobre os repos git sob a BASE (BASE\repo e BASE\grupo\repo)
rem e roda "git pull --ff-only" em cada um.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.8.13"

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

rem One list per failure reason, filled by :addmot. Same set of reasons as the
rem .sh, minus "diretorio nao encontrado": this side only calls :pull on a
rem directory it has already seen holding a .git.
set "MOT_UPSTREAM="
set "MOT_APAGADA="
set "MOT_DIVERGIU="
set "MOT_SUJA="
set "MOT_CONFLITO="
set "MOT_REMOTO="
set "MOT_OUTRO="

rem git's output goes to a file so that :classify can read it back.
set "TMPOUT=%TEMP%\git_pull_%RANDOM%%RANDOM%.txt"

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

if exist "%TMPOUT%" del /q "%TMPOUT%"

echo.
echo ==============================
echo   OK: %OK%   Falhou: %FAIL%
if defined OKLIST   echo   OK:    %OKLIST%
if defined FAILLIST (
    echo   Falhou:%FAILLIST%
    rem Agrupado por motivo: a lista corrida responde "quais", e o que se quer
    rem saber e "qual conserto", que nao e o mesmo para os repos dela.
    if defined MOT_UPSTREAM echo       sem upstream:!MOT_UPSTREAM!
    if defined MOT_APAGADA  echo       branch apagada no remoto:!MOT_APAGADA!
    if defined MOT_DIVERGIU echo       divergiu do remoto:!MOT_DIVERGIU!
    if defined MOT_SUJA     echo       arvore suja:!MOT_SUJA!
    if defined MOT_CONFLITO echo       conflito:!MOT_CONFLITO!
    if defined MOT_REMOTO   echo       remoto inacessivel:!MOT_REMOTO!
    if defined MOT_OUTRO    echo       outro:!MOT_OUTRO!
)
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
git pull --ff-only > "%TMPOUT%" 2>&1
set "RC=!errorlevel!"
type "%TMPOUT%"
if "!RC!"=="0" (
    set /a OK+=1
    set "OKLIST=!OKLIST! !rel!"
) else (
    call :classify
    echo    x !MOTIVO!
    call :addmot "!MOTKEY!" "!rel!"
    set /a FAIL+=1
    set "FAILLIST=!FAILLIST! !rel!"
)
exit /b 0

rem Nomeia o motivo da falha a partir da mensagem do proprio git. Um "x" seco
rem dizia que o repo falhou, nunca POR QUE - e as causas que aparecem na
rem pratica pedem consertos diferentes: branch sem upstream, branch apagada no
rem remoto (o ref local sobrevive ao fetch e esconde o caso) e historico
rem divergente sao tres trabalhos com a mesma marca.
:classify
set "MOTIVO=outro"
set "MOTKEY=OUTRO"
findstr /c:"no tracking information" /c:"no upstream" "%TMPOUT%" >nul
if not errorlevel 1 (
    set "MOTIVO=sem upstream"
    set "MOTKEY=UPSTREAM"
    exit /b 0
)
findstr /c:"no such ref was fetched" "%TMPOUT%" >nul
if not errorlevel 1 (
    set "MOTIVO=branch apagada no remoto"
    set "MOTKEY=APAGADA"
    exit /b 0
)
findstr /c:"Diverging branches" /c:"Not possible to fast-forward" /c:"divergent" /c:"non-fast-forward" "%TMPOUT%" >nul
if not errorlevel 1 (
    set "MOTIVO=divergiu do remoto"
    set "MOTKEY=DIVERGIU"
    exit /b 0
)
findstr /c:"local changes" /c:"would be overwritten" /c:"unstaged changes" /c:"Please commit" "%TMPOUT%" >nul
if not errorlevel 1 (
    set "MOTIVO=arvore suja"
    set "MOTKEY=SUJA"
    exit /b 0
)
findstr /c:"fix conflicts" /c:"CONFLICT" "%TMPOUT%" >nul
if not errorlevel 1 (
    set "MOTIVO=conflito"
    set "MOTKEY=CONFLITO"
    exit /b 0
)
findstr /c:"Could not read from remote" /c:"unable to access" /c:"Repository not found" /c:"Permission denied" /c:"ould not resolve host" /c:"Connection" /c:"timed out" "%TMPOUT%" >nul
if not errorlevel 1 (
    set "MOTIVO=remoto inacessivel"
    set "MOTKEY=REMOTO"
    exit /b 0
)
exit /b 0

rem Acumula o repo na lista do motivo. O nome da variavel e montado:
rem %~1 vira UPSTREAM, APAGADA, ... e o alvo e MOT_<chave>.
:addmot
set "MOT_%~1=!MOT_%~1! %~2"
exit /b 0