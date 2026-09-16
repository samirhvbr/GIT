@echo off
setlocal enabledelayedexpansion
rem pull.cmd v1.9.0 - equivalente Windows do pull.sh
rem Auto-descobre os repos git sob a BASE (BASE\repo e BASE\grupo\repo)
rem e roda "git pull --ff-only" em cada um.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.9.0"

rem BASE = pasta-mae deste script. O .cmd fica em <BASE>\git\, entao
rem subimos de git\ para a base. %~dp0 = pasta do script (com \ no final).
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
for %%I in ("%SCRIPT_DIR%") do set "BASE=%%~dpI"
set "BASE=%BASE:~0,-1%"

rem -- Quais repositorios entram: -d exclui, -i restringe -------------------
rem A flag vale para todas as palavras seguintes ate aparecer outra, entao
rem "-d 000 001" e "-d 000 -d 001" dizem a mesma coisa. Palavra solta, sem
rem flag nenhuma, continua sendo exclusao - como o script sempre funcionou.
rem
rem Ate a 1.9.0 este lado nao lia argumento NENHUM: a lista de repos a pular
rem estava documentada no .sh e no README, e quem rodava no Windows achava que
rem tinha o comportamento que leu. Um par divergente e pior que uma feature
rem ausente - por isso as flags nascem nos dois lados no mesmo commit.
rem
rem As listas sao strings separadas por ponto-e-virgula: o cmd nao tem array.
set "EXCLUDE="
set "ONLY="
set "modo=d"

:parse
if "%~1"=="" goto parsed
if /i "%~1"=="-d" goto parse_d
if /i "%~1"=="--exclude" goto parse_d
if /i "%~1"=="-i" goto parse_i
if /i "%~1"=="--only" goto parse_i
if /i "%~1"=="--include" goto parse_i
if /i "%~1"=="-h" goto parse_help
if /i "%~1"=="--help" goto parse_help
set "arg=%~1"
if "!arg:~0,1!"=="-" goto parse_unknown
rem tolera ".\BLUE3", "BLUE3\" e a barra do jeito unix
if "!arg:~0,2!"==".\" set "arg=!arg:~2!"
if "!arg:~0,2!"=="./" set "arg=!arg:~2!"
set "arg=!arg:/=\!"
if "!arg:~-1!"=="\" set "arg=!arg:~0,-1!"
if "!modo!"=="i" (set "ONLY=!ONLY!;!arg!") else (set "EXCLUDE=!EXCLUDE!;!arg!")
shift
goto parse

:parse_d
set "modo=d"
shift
goto parse

:parse_i
set "modo=i"
shift
goto parse

:parse_unknown
echo opcao desconhecida: %~1
echo.
call :usage
pause
exit /b 2

:parse_help
call :usage
pause
exit /b 0

:parsed

set /a OK=0, FAIL=0
set "OKLIST="
set "FAILLIST="
set "SKIPLIST="

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
set "TMPOUT=%TEMP%\pull_%RANDOM%%RANDOM%.txt"

rem -- descoberta: BASE\repo e BASE\grupo\repo (mesma do .sh) ---------------
set "ACHADOS="
set /a NACHADOS=0
for /d %%D in ("%BASE%\*") do (
    if exist "%%D\.git" (
        call :achou "%%D"
    ) else (
        for /d %%E in ("%%D\*") do (
            if exist "%%E\.git" call :achou "%%E"
        )
    )
)

if %NACHADOS%==0 (
    echo Nenhum repositorio git encontrado em %BASE%
    pause
    exit /b 1
)

rem O -i corta aqui, antes do laco de trabalho, e o -d corta la dentro, onde
rem continua aparecendo como "pulado". Mesma divisao do .sh e pelo mesmo
rem motivo: um "-i BLUE3" numa base de mais de cem repositorios imprimiria uma
rem centena de linhas de pulado antes da primeira linha util, enquanto o -d
rem nomeia repos um a um e quem digitou quer ver a exclusao confirmada.
set "SELEC="
set /a NSELEC=0, NFORA=0
for %%R in ("%ACHADOS:;=" "%") do (
    set "_r=%%~R"
    if defined _r call :seleciona "%%~R"
)

echo pull.cmd v%VERSION% - base: %BASE% ^(%NSELEC% de %NACHADOS% repos^)
if defined ONLY    echo   -i so:   %ONLY:;= % ^(%NFORA% fora^)
if defined EXCLUDE echo   -d fora: %EXCLUDE:;= %
call :avisa "%ONLY%" "-i"
call :avisa "%EXCLUDE%" "-d"
if %NSELEC%==0 (
    echo Nenhum repositorio sobrou depois do -i/-d - nada a fazer.
    pause
    exit /b 1
)
echo.

for %%R in ("%SELEC:;=" "%") do (
    set "_r=%%~R"
    if defined _r call :pull "%%~R"
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
if defined SKIPLIST echo   Pulado:%SKIPLIST%
echo.
pause
exit /b 0

:pull
set "rel=%~1"
set "repo=%BASE%\!rel!"
echo.
echo -- !rel!
call :casa "!rel!" "%EXCLUDE%"
if not errorlevel 1 (
    echo    [pulado -d]
    set "SKIPLIST=!SKIPLIST! !rel!"
    exit /b 0
)
cd /d "!repo!"
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

:usage
echo uso: pull.cmd [-d DIR...] [-i DIR...] [DIR...]
echo.
echo   -d, --exclude DIR   deixa DIR de fora ^(e tudo que estiver sob ele^)
echo   -i, --only DIR      roda SO em DIR ^(e no que estiver sob ele^)
echo   -h, --help          esta ajuda
echo.
echo A flag vale para todas as palavras seguintes ate aparecer outra, entao
echo "-d 000 001" e "-d 000 -d 001" sao a mesma coisa. Palavra solta, sem
echo flag nenhuma, e exclusao - o comportamento antigo do script.
echo.
echo DIR casa pelo caminho ^(BLUE3\CNPJ^), pelo nome final ^(CNPJ^) ou pela
echo pasta-mae ^(BLUE3 alcanca tudo que estiver sob BLUE3\^).
echo.
echo   pull.cmd -d 000                    todos, menos o balde de terceiros
echo   pull.cmd -d 000 -d B3DEV           todos, menos os dois
echo   pull.cmd -i BLUE3                  so os de BLUE3\
echo   pull.cmd -i BLUE3 -d BLUE3\CNPJ    so BLUE3\, menos o CNPJ
exit /b 0

rem Acumula o repo descoberto, ja relativo a BASE.
:achou
set "_p=%~1"
set "_r=!_p:%BASE%\=!"
set "ACHADOS=!ACHADOS!;!_r!"
set /a NACHADOS+=1
exit /b 0

rem Aplica o -i. Sem -i, tudo entra.
:seleciona
set "_r=%~1"
if defined ONLY (
    call :casa "!_r!" "!ONLY!"
    if errorlevel 1 (
        set /a NFORA+=1
        exit /b 0
    )
)
set "SELEC=!SELEC!;!_r!"
set /a NSELEC+=1
exit /b 0

rem Casa o caminho exato (BLUE3\CNPJ), o nome final (CNPJ) ou a pasta-mae
rem (BLUE3 alcanca tudo sob BLUE3\). A descoberta tem no maximo dois niveis,
rem entao "pasta-mae" aqui e exatamente "o grupo do caminho".
rem setlocal porque o :avisa chama esta rotina de dentro do proprio laco e
rem usaria as mesmas variaveis; o exit /b faz o endlocal e preserva o codigo.
:casa
setlocal enabledelayedexpansion
set "_rel=%~1"
set "_lst=%~2"
if not defined _lst exit /b 1
for %%N in ("%~1") do set "_nome=%%~nxN"
set "_grp="
if not "!_nome!"=="!_rel!" set "_grp=!_rel:\%_nome%=!"
for %%A in ("%_lst:;=" "%") do (
    set "_a=%%~A"
    if defined _a (
        if /i "!_a!"=="!_rel!" exit /b 0
        if /i "!_a!"=="!_nome!" exit /b 0
        if defined _grp if /i "!_a!"=="!_grp!" exit /b 0
    )
)
exit /b 1

rem Argumento que nao alcanca repositorio nenhum e quase sempre erro de
rem digitacao, e os dois modos erram em silencio em direcoes opostas: um -d
rem errado mexe no que era para ficar de fora, e um -i errado zera a varredura.
:avisa
setlocal enabledelayedexpansion
set "_lst=%~1"
set "_rot=%~2"
if not defined _lst exit /b 0
for %%A in ("%_lst:;=" "%") do (
    set "_a=%%~A"
    if defined _a (
        set "_achou=0"
        for %%R in ("%ACHADOS:;=" "%") do (
            set "_x=%%~R"
            if defined _x (
                call :casa "%%~R" "%%~A"
                if not errorlevel 1 set "_achou=1"
            )
        )
        if "!_achou!"=="0" echo   [aviso] !_rot! "!_a!" nao alcanca nenhum repositorio sob %BASE%
    )
)
exit /b 0
