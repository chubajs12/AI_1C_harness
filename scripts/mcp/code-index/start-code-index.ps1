# Индексатор кода проекта — СВОЙ контейнер CODE_INDEX_CONTAINER (единственный MCP, который заводится на проект).
# Обычный docker run, без compose-группы; порт только на 127.0.0.1; исходники conf/ext — только чтение; индексы —
# в <PROJECT_ROOT>\indexes\code-index\{home,conf,ext} (внутри папки проекта, не соседней папкой).
#   start-code-index.ps1           # есть контейнер — запустить; нет — собрать образ (если нет) и создать
#   start-code-index.ps1 -Status   # состояние контейнера и /health
# Первичная индексация большой конфигурации (ERP) идет часы — это норма; ход — docker logs -f <контейнер>.
# Контейнер не удалять (docker rm) без просьбы пользователя: индексы переживают пересоздание, но это его решение.
param(
    [switch]$Status,
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$name = $cfg['CODE_INDEX_CONTAINER']
$image = $cfg['CODE_INDEX_IMAGE']
$port = $cfg['CODE_INDEX_PORT']
$state = Join-Path $cfg['PROJECT_ROOT'] 'indexes\code-index'

if ($Status) {
    docker ps -a --filter "name=^$name$" --format '{{.Names}} {{.Status}} {{.Ports}}'
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 5
        Write-Host $r.Content
    } catch { Write-Host "[code-index] /health не отвечает: $($_.Exception.Message)" -ForegroundColor DarkYellow }
    exit 0
}

if ((docker ps -a --filter "name=^$name$" --format '{{.Names}}') -eq $name) {
    docker start $name | Out-Null
    Write-Host "[code-index] запущен существующий контейнер $name (http://localhost:$port/mcp)" -ForegroundColor Green
    exit 0
}

# порт свободен?
if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) {
    throw "Порт $port занят — выбрать другой CODE_INDEX_PORT (занятые: docker ps --format '{{.Names}} {{.Ports}}')"
}

# образ
if (-not (docker images -q $image)) {
    Write-Host "[code-index] сборка образа $image" -ForegroundColor Cyan
    docker build -t $image $PSScriptRoot
    if ($LASTEXITCODE -ne 0) { throw 'docker build не выполнен' }
}

# каталоги состояния и точки монтирования индексов внутри исходников (без них контейнер не стартует:
# «make mountpoint /repos/ext/.code-index: read-only file system»)
foreach ($d in @('home', 'conf', 'ext')) { New-Item -ItemType Directory -Force -Path (Join-Path $state $d) | Out-Null }
foreach ($src in @($cfg['CONF_DIR'], $cfg['EXT_DIR'])) {
    if (-not (Test-Path -LiteralPath $src)) { throw "Нет каталога исходников $src — сначала выгрузка (designer.ps1 -Action Dump)" }
    New-Item -ItemType Directory -Force -Path (Join-Path $src '.code-index') | Out-Null
}

# daemon.toml: пути — внутри контейнера; http_port — служебный порт демона внутри контейнера (/health индексации)
$toml = Join-Path $state 'daemon.toml'
$tomlText = @"
# Сгенерировано start-code-index.ps1. Исходники: $($cfg['CONF_DIR']), $($cfg['EXT_DIR']) (только чтение).
[daemon]
http_host = "127.0.0.1"
http_port = 8031
max_concurrent_initial = 2
log_level = "info"

[[paths]]
path = "/repos/conf"
alias = "conf"
language = "bsl"
debounce_ms = 30000
batch_ms = 60000

[[paths]]
path = "/repos/ext"
alias = "ext"
language = "bsl"
debounce_ms = 15000
batch_ms = 30000
"@
[IO.File]::WriteAllText($toml, $tomlText, (New-Object Text.UTF8Encoding $false))  # UTF-8 без BOM

function To-DockerPath([string]$p) { return ($p -replace '\\', '/') }
docker run -d --name $name --restart unless-stopped `
    -p "127.0.0.1:${port}:8030" `
    -v "$(To-DockerPath (Join-Path $state 'home')):/data/code-index-home" `
    -v "$(To-DockerPath $toml):/data/code-index-home/daemon.toml:ro" `
    -v "$(To-DockerPath $cfg['CONF_DIR']):/repos/conf:ro" `
    -v "$(To-DockerPath $cfg['EXT_DIR']):/repos/ext:ro" `
    -v "$(To-DockerPath (Join-Path $state 'conf')):/repos/conf/.code-index" `
    -v "$(To-DockerPath (Join-Path $state 'ext')):/repos/ext/.code-index" `
    $image | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'docker run не выполнен' }
Write-Host "[code-index] создан $name, MCP http://localhost:$port/mcp; индексация — docker logs -f $name" -ForegroundColor Green
