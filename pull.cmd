@echo off
setlocal enabledelayedexpansion
rem pull.cmd v1.9.7 - equivalente Windows do pull.sh
rem Auto-descobre os repos git sob a BASE (BASE\repo e BASE\grupo\repo)
rem e roda "git pull --ff-only" em cada um.
rem Texto sem acentos de proposito (compatibilidade com o code page do cmd).

set "VERSION=1.9.7"

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
set "PARADOS="

rem One list per failure reason, filled by :addmot. Same set of reasons as the
rem .sh, minus "diretorio nao encontrado": this side only calls :pull on a
rem directory it has already seen holding a .git.
set "MOT_UPSTREAM="
set "MOT_MERGEADA="
set "MOT_APAGSUJA="
set "MOT_APAGADA="
set "MOT_DIVERGIU="
set "MOT_SUJA="
set "MOT_CONFLITO="
set "MOT_REMOTO="
set "MOT_OUTRO="

rem git's output goes to a file so that :classify can read it back.
set "TMPOUT=%TEMP%\pull_%RANDOM%%RANDOM%.txt"

rem -- descoberta: BASE\repo e BASE\grupo\repo (mesma do .sh) ---------------
rem A .git directory without a HEAD is not a repository: SHVIA\.git was exactly
rem that, so this side stopped at SHVIA as if it were a repo and never looked at
rem the repositories below it. :tipogit tells the three cases apart, and a folder
rem whose .git is empty is reported and still searched one level down.
set "ACHADOS="
set "VAZIOS="
set /a NACHADOS=0
for /d %%D in ("%BASE%\*") do (
    call :tipogit "%%D"
    if not errorlevel 1 (
        call :achou "%%D"
    ) else (
        if errorlevel 2 call :vazio "%%D"
        for /d %%E in ("%%D\*") do (
            call :tipogit "%%E"
            if errorlevel 2 (
                call :vazio "%%E"
            ) else if not errorlevel 1 (
                call :achou "%%E"
            )
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
for %%R in ("%VAZIOS:;=" "%") do (
    set "_r=%%~R"
    if defined _r echo   aviso: %%~R\.git ignorado: diretorio sem HEAD, nao e repositorio
)
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
    if defined MOT_MERGEADA echo       branch apagada, ja na principal:!MOT_MERGEADA!
    if defined MOT_APAGSUJA echo       branch apagada, arvore suja:!MOT_APAGSUJA!
    if defined MOT_APAGADA  echo       branch apagada no remoto:!MOT_APAGADA!
    if defined MOT_DIVERGIU echo       divergiu do remoto:!MOT_DIVERGIU!
    if defined MOT_SUJA     echo       arvore suja:!MOT_SUJA!
    if defined MOT_CONFLITO echo       conflito:!MOT_CONFLITO!
    if defined MOT_REMOTO   echo       remoto inacessivel:!MOT_REMOTO!
    if defined MOT_OUTRO    echo       outro:!MOT_OUTRO!
)
if defined SKIPLIST echo   Pulado:%SKIPLIST%
if defined PARADOS echo   Sem o que puxar:!PARADOS!
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
rem Two repositories have nothing to pull, and neither is a failure: one with
rem no remote configured, and one on a detached HEAD (no branch to advance, as in
rem a checkout pinned to a tag on purpose). Same checks as pull.sh. They are
rem listed apart, so the failure list keeps only what a person has to repair.
set "_nrem=0"
for /f %%n in ('git remote 2^>nul ^| find /c /v ""') do set "_nrem=%%n"
if "!_nrem!"=="0" (
    echo    branch: !branch!
    echo    [sem remote configurado - nada a puxar]
    set "PARADOS=!PARADOS! !rel!(sem remote)"
    exit /b 0
)
if not defined branch (
    set "_solto="
    for /f "delims=" %%s in ('git describe --tags --always 2^>nul') do set "_solto=%%s"
    echo    branch: ^(HEAD solto em !_solto!^)
    echo    [HEAD solto - nao ha branch para puxar]
    set "PARADOS=!PARADOS! !rel!(HEAD solto)"
    exit /b 0
)
echo    branch: !branch!
git pull --ff-only > "%TMPOUT%" 2>&1
set "RC=!errorlevel!"
type "%TMPOUT%"
if "!RC!"=="0" (
    set /a OK+=1
    set "OKLIST=!OKLIST! !rel!"
) else (
    call :classify
    set "DETALHE="
    set "DICA="
    set "ALVO="
    if "!MOTKEY!"=="APAGADA" call :apagada "!branch!"
    set "LINHA=x !MOTIVO!"
    if defined DETALHE set "LINHA=!LINHA! - !DETALHE!"
    echo    !LINHA!
    if defined DICA echo    -^> !DICA!
    call :addmot "!MOTKEY!" "!rel!!ALVO!"
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

rem Same diagnosis as diagnose_deleted_branch in pull.sh. A branch deleted on
rem the remote is usually one whose pull request merged and was cleaned up, and
rem the repair is to leave it; a branch deleted with commits no default branch
rem ever received needs a person. The work counts as landed when HEAD is an
rem ancestor of a remote's default branch, or when merging HEAD into it would not
rem change its tree (a squash or rebase merge). The tracking remote is tried
rem first and then every other one: a contribution lands in the upstream, not in
rem the fork its branch was pushed to. When git alone cannot tell, the forge is
rem asked (:pr_mesclada). Otherwise the commits are counted against the tracking
rem remote and nothing is claimed. A landed branch whose tracked files are
rem modified gets its own reason and no switch command (see :marca_pouso).
rem Sets MOTIVO, MOTKEY, DETALHE, DICA and ALVO. TMPOUT is free again here:
rem :classify has already read it.
:apagada
set "_rem="
for /f "delims=" %%r in ('git config "branch.%~1.remote" 2^>nul') do set "_rem=%%r"
if not defined _rem set "_rem=origin"
call :acha_pouso "%~1" "!_rem!" "!_rem!"
if not errorlevel 1 (
    call :marca_pouso "!LREM!" "!LDEF!" "branch apagada, ja na principal" "branch apagada, arvore suja" MERGEADA APAGSUJA
    exit /b 0
)
call :pr_mesclada "%~1"
if not errorlevel 1 (
    call :marca_pouso "!LREM!" "!LDEF!" "branch apagada, ja na principal" "branch apagada, arvore suja" MERGEADA APAGSUJA
    set "DETALHE=!DETALHE! - PR #!LPR! mesclado com este mesmo commit"
    exit /b 0
)
if defined PAHEAD if defined PDEF set "DETALHE=%PAHEAD% commit(s) fora de %PREM%/%PDEF%; confira antes de trocar de branch"
exit /b 0

rem default_branch of pull.sh: sets DEFB to the default branch of the remote named
rem by the first argument, from the local HEAD ref of that remote, then from the
rem remote itself, then by the two names in use; empty when none of them answers.
:def_remoto
set "DEFB="
for /f "delims=" %%h in ('git symbolic-ref --quiet --short "refs/remotes/%~1/HEAD" 2^>nul') do set "DEFB=%%h"
if defined DEFB set "DEFB=!DEFB:*/=!"
if defined DEFB exit /b 0
for /f "tokens=2" %%h in ('git ls-remote --symref "%~1" HEAD 2^>nul ^| findstr /b /c:"ref:"') do set "DEFB=%%h"
if defined DEFB set "DEFB=!DEFB:refs/heads/=!"
if defined DEFB exit /b 0
git rev-parse --verify --quiet "refs/remotes/%~1/main" >nul 2>&1 && set "DEFB=main"
if defined DEFB exit /b 0
git rev-parse --verify --quiet "refs/remotes/%~1/master" >nul 2>&1 && set "DEFB=master"
exit /b 0

rem find_landing of pull.sh. Arguments: the branch itself, the tracking remote
rem (tried first), and the remote the failed pull has just fetched. The default
rem branch of every other remote is fetched before the comparison, because a
rem local upstream/main is only as new as the last fetch from that remote.
rem errorlevel 0 = the work is in LREM/LDEF; 1 = nowhere we can see. PREM, PDEF
rem and PAHEAD always describe the tracking remote, for the "N commits outside"
rem message; PAHEAD stays empty when that cannot be measured.
:acha_pouso
set "LREM="
set "LDEF="
set "PREM=%~2"
set "PDEF="
set "PAHEAD="
call :pouso_um "%~1" "%~2" "%~3" 1
if not errorlevel 1 exit /b 0
for /f "delims=" %%r in ('git remote 2^>nul') do (
    if /i not "%%r"=="%~2" (
        call :pouso_um "%~1" "%%r" "%~3" 0
        if not errorlevel 1 exit /b 0
    )
)
exit /b 1

rem One remote of :acha_pouso. The fourth argument is 1 for the tracking remote.
:pouso_um
call :def_remoto "%~2"
if "%~4"=="1" set "PDEF=%DEFB%"
if not defined DEFB exit /b 1
if /i "%DEFB%"=="%~1" exit /b 1
if /i not "%~2"=="%~3" git fetch --quiet --no-tags "%~2" "%DEFB%" >nul 2>&1
git rev-parse --verify --quiet "refs/remotes/%~2/%DEFB%" >nul 2>&1 || exit /b 1
set "_n="
for /f %%n in ('git rev-list --count HEAD --not "%~2/%DEFB%" 2^>nul') do set "_n=%%n"
if not defined _n exit /b 1
if "%~4"=="1" set "PAHEAD=%_n%"
if "%_n%"=="0" goto pouso_sim
git merge-tree --write-tree "%~2/%DEFB%" HEAD > "%TMPOUT%" 2>nul
if errorlevel 1 exit /b 1
set "_t="
set /p _t=<"%TMPOUT%"
if not defined _t exit /b 1
git diff --quiet %_t% "%~2/%DEFB%" 2>nul || exit /b 1
:pouso_sim
set "LREM=%~2"
set "LDEF=%DEFB%"
exit /b 0

rem landed_by_pr of pull.sh: the last resort for a branch deleted on the remote,
rem when git alone cannot tell but the forge can. A pull request merged by squash,
rem or rebased after the default branch had moved on, leaves no commit at HEAD in
rem the history and no tree that still compares equal, yet it records the head
rem commit it was merged with. When gh is installed, every GitHub remote is asked
rem for merged pull requests from this branch, and the work counts as landed only
rem when one of them was merged with exactly the commit at HEAD. errorlevel 0 =
rem LREM, LDEF and LPR are set; 1 = no, also when gh is missing.
:pr_mesclada
where gh >nul 2>&1
if errorlevel 1 exit /b 1
set "_head="
for /f %%h in ('git rev-parse HEAD 2^>nul') do set "_head=%%h"
if not defined _head exit /b 1
set "LREM="
set "LDEF="
set "LPR="
for /f "delims=" %%r in ('git remote 2^>nul') do (
    call :pr_um "%~1" "%%r" "!_head!"
    if not errorlevel 1 exit /b 0
)
exit /b 1

rem One remote of :pr_mesclada. The third argument is the commit at HEAD.
:pr_um
set "_url="
for /f "delims=" %%u in ('git config --get "remote.%~2.url" 2^>nul') do set "_url=%%u"
if not defined _url exit /b 1
set "_slug="
if "!_url:~0,15!"=="git@github.com:" set "_slug=!_url:~15!"
if "!_url:~0,19!"=="https://github.com/" set "_slug=!_url:~19!"
if "!_url:~0,21!"=="ssh://git@github.com/" set "_slug=!_url:~21!"
if not defined _slug exit /b 1
if "!_slug:~-4!"==".git" set "_slug=!_slug:~0,-4!"
if "!_slug:~-1!"=="/" set "_slug=!_slug:~0,-1!"
call :def_remoto "%~2"
if not defined DEFB exit /b 1
for /f "tokens=1,2" %%a in ('gh pr list -R "%_slug%" --state merged --head "%~1" --limit 10 --json "number,headRefOid" --jq ".[] | [.number, .headRefOid] | @tsv" 2^>nul') do (
    if /i "%%b"=="%~3" (
        set "LREM=%~2"
        set "LDEF=!DEFB!"
        set "LPR=%%a"
        exit /b 0
    )
)
exit /b 1

rem mark_landed of pull.sh. Arguments: remote, default branch, the reason and key
rem for a clean tree, then the reason and key for a modified one. The work of HEAD
rem is already in that remote and branch, and the repair is a "git switch".
rem Whether that is safe depends on the working tree: with modified tracked files
rem (staged or not) the switch either refuses or carries them onto the default
rem branch, so those get the second reason and no switch command. Untracked files
rem are not counted. Sets MOTIVO, MOTKEY, DETALHE, DICA and ALVO.
:marca_pouso
set "_sujo=0"
for /f %%n in ('git status --porcelain --untracked-files=no 2^>nul ^| find /c /v ""') do set "_sujo=%%n"
if not "%_sujo%"=="0" goto marca_suja
set "MOTIVO=%~3"
set "MOTKEY=%~5"
set "DETALHE=o trabalho ja esta em %~1/%~2"
set "DICA=git switch %~2 && git pull --ff-only"
set "ALVO=->%~2"
exit /b 0
:marca_suja
set "MOTIVO=%~4"
set "MOTKEY=%~6"
set "DETALHE=o trabalho ja esta em %~1/%~2, mas ha alteracoes nao commitadas em %_sujo% arquivo(s) rastreado(s)"
set "DICA=git status --short - guarde ou commite as alteracoes antes de trocar para %~2"
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

rem Acumula a pasta cuja .git esta vazia, ja relativa a BASE.
:vazio
set "_p=%~1"
set "_r=!_p:%BASE%\=!"
set "VAZIOS=!VAZIOS!;!_r!"
exit /b 0

rem What %~1\.git is: errorlevel 0 = a repository (a .git that holds a HEAD, or a
rem .git file, as a worktree has), 1 = no .git at all, 2 = a .git directory
rem without a HEAD. The trailing backslash makes "exist" true for directories only.
:tipogit
if not exist "%~1\.git" exit /b 1
if exist "%~1\.git\HEAD" exit /b 0
if exist "%~1\.git\" exit /b 2
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
