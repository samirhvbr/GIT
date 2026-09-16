@echo off
setlocal enabledelayedexpansion
rem status.cmd v1.9.0 - equivalente Windows do status.sh
rem Verificador de status (SOMENTE LEITURA) dos repos git sob a BASE
rem (BASE\repo e BASE\grupo\repo). Mostra o branch, commits a enviar/atras
rem do remoto e os arquivos pendentes de commit. NAO altera nada: nao faz
rem add, commit, pull nem push.
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

set /a CLEAN=0, DIRTY=0
set "CLEANLIST="
set "DIRTYLIST="
set "SKIPLIST="

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

echo status.cmd v%VERSION% - base: %BASE% ^(%NSELEC% de %NACHADOS% repos^)
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
    if defined _r call :status "%%~R"
)


echo.
echo ==============================
echo   Limpo: %CLEAN%   Pendente: %DIRTY%
if defined DIRTYLIST echo   Pendente: %DIRTYLIST%
if defined CLEANLIST echo   Limpo:    %CLEANLIST%
if defined SKIPLIST echo   Pulado:  %SKIPLIST%
echo.
pause
exit /b 0

:status
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
if not defined branch set "branch=(detached)"
echo    branch: !branch!

rem Commits locais a enviar / atras do remoto (se houver upstream).
rem Sem upstream os dois `rev-list` falham e ficam em 0, e o repo aparecia
rem como 0/0 - indistinguivel de em dia com o remoto. O status.sh diz
rem "sem upstream configurado" desde a 1.5.1; este lado ficava calado.
set "ahead=0"
set "behind=0"
set "upstream="
for /f "delims=" %%u in ('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2^>nul') do set "upstream=%%u"
if not defined upstream (
    echo    sem upstream configurado
) else (
    for /f %%a in ('git rev-list --count @{u}..HEAD 2^>nul') do set "ahead=%%a"
    for /f %%a in ('git rev-list --count HEAD..@{u} 2^>nul') do set "behind=%%a"
    if not "!ahead!"=="0"  echo    ^> !ahead! commit^(s^) local^(is^) a enviar
    if not "!behind!"=="0" echo    ^< !behind! commit^(s^) atras de !upstream!
)

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

:usage
echo uso: status.cmd [-d DIR...] [-i DIR...] [DIR...]
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
echo   status.cmd -d 000                    todos, menos o balde de terceiros
echo   status.cmd -d 000 -d B3DEV           todos, menos os dois
echo   status.cmd -i BLUE3                  so os de BLUE3\
echo   status.cmd -i BLUE3 -d BLUE3\CNPJ    so BLUE3\, menos o CNPJ
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
