# Свежая пара Vanessa проекта: закрыть клиент тестирования через MCP, остановить СВОИ TM/TC (по имени своей базы в
# командной строке), запустить ровно 2 новых сеанса в RDP-сессии (задача VANESSA_LAUNCH_TASK) и дождаться готовности
# MCP (порт слушает, PID новые, инструменты зарегистрированы).
#   restart-vanessa.ps1            # перезапуск
#   restart-vanessa.ps1 -StopOnly  # только остановить свою пару
# Когда нужен: после UpdateDB/загрузки CFE, после правки VAParams (читается только при старте), когда порт MCP не
# отвечает. На обычный FAIL шага — НЕ нужен. MCP 1С не трогает.
# На одном порту MCP может жить только одна пара: если порт занят чужим процессом — стоп с сообщением.
param(
    [switch]$StopOnly,
    [int]$WaitReadySec = 240,
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$port = [int]$cfg['VANESSA_MCP_PORT']
$root = $cfg['VANESSA_ROOT']
$pidTm = Join-Path $root '.tm-pid'
$pidTc = Join-Path $root '.tc-pid'
$ibPattern = Get-KitIbPattern $cfg

function Get-OwnVanessa {
    # своя пара = своя база И свой порт (TM: mcpPort=<порт MCP>, TC: -TPort <порт клиента>) — даже если базу делят
    # с другим проектом, чужая пара на других портах не трогается
    $tcPort = $cfg['VANESSA_TC_PORT']
    @(Get-CimInstance Win32_Process -Filter "Name='1cv8c.exe' OR Name='1cv8.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match $ibPattern -and
            ($_.CommandLine -match "/TESTMANAGER.*mcpPort=$port\b" -or $_.CommandLine -match "/TestClient\s+-TPort\s+$tcPort\b") })
}

function Invoke-Mcp([string]$Body, [string]$Sid = '', [int]$Timeout = 5) {
    $headers = @{ Accept = 'application/json, text/event-stream' }
    if ($Sid) { $headers['Mcp-Session-Id'] = $Sid }
    Invoke-WebRequest -Uri "http://127.0.0.1:$port/mcp" -Method POST -Body ([Text.Encoding]::UTF8.GetBytes($Body)) `
        -ContentType 'application/json; charset=utf-8' -Headers $headers -TimeoutSec $Timeout -UseBasicParsing
}

function Get-McpSession {
    $init = Invoke-Mcp '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"kit-restart","version":"1"}}}'
    $sid = $init.Headers['Mcp-Session-Id']
    Invoke-Mcp '{"jsonrpc":"2.0","method":"notifications/initialized"}' $sid | Out-Null
    return $sid
}

# 1. порт занят чужим (не нашим TM) — не трогаем, сообщаем
$listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
$own = Get-OwnVanessa
if ($listen -and ($own.ProcessId -notcontains $listen.OwningProcess)) {
    $who = Get-CimInstance Win32_Process -Filter "ProcessId=$($listen.OwningProcess)" -ErrorAction SilentlyContinue
    throw "Порт MCP $port занят чужим процессом PID $($listen.OwningProcess) ($($who.Name)) — другой проект/сессия; выбрать другой VANESSA_MCP_PORT или договориться"
}

# 2. стоп своей пары
$oldPids = @($own | ForEach-Object { [int]$_.ProcessId })
Write-Host "[va] своих процессов Vanessa: $($oldPids.Count) ($($oldPids -join ','))"
if ($listen) {
    try {
        $sid = Get-McpSession
        Invoke-Mcp '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"close_test_client","arguments":{}}}' $sid 10 | Out-Null
        Write-Host '[va] close_test_client'
    } catch { Write-Host '[va] MCP не ответил на close_test_client — останавливаю процессы' -ForegroundColor DarkYellow }
}
foreach ($p in (Get-OwnVanessa)) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item $pidTm, $pidTc -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 10
$left = Get-OwnVanessa
if ($left.Count -gt 0) { throw "[va] после остановки живы: $(@($left.ProcessId) -join ',')" }
Write-Host '[va] своя пара остановлена' -ForegroundColor Green
if ($StopOnly) { exit 0 }

# 3. старт в RDP-сессии через задачу планировщика (SYSTEM -> wts-launch.ps1 -> start-tm-tc.ps1)
$task = $cfg['VANESSA_LAUNCH_TASK']
if (-not (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue)) {
    throw "Нет задачи планировщика $task — один раз выполнить register-launch-task.ps1 от администратора (docs/04)"
}
schtasks /Run /TN $task | Out-Null
Write-Host "[va] schtasks /Run $task"

# 4. готовность: порт слушает, PID новые и живы, своих процессов ровно 2, инструменты зарегистрированы
$deadline = (Get-Date).AddSeconds($WaitReadySec)
$ready = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if (-not ((Test-Path $pidTm) -and (Test-Path $pidTc))) { continue }
    $tm = [int](Get-Content $pidTm -Raw).Trim()
    $tc = [int](Get-Content $pidTc -Raw).Trim()
    if ($oldPids -contains $tm -or $oldPids -contains $tc) { continue }
    if (-not ((Get-Process -Id $tm -ErrorAction SilentlyContinue) -and (Get-Process -Id $tc -ErrorAction SilentlyContinue))) { continue }
    if (-not (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) { continue }
    if ((Get-OwnVanessa).Count -ne 2) { continue }
    try {
        $sid = Get-McpSession
        $list = Invoke-Mcp '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' $sid 15
        if ($list.Content -match 'run_scenario') { $ready = $true; break }
    } catch { }
}
if (-not $ready) {
    throw "[va] пара не готова за $WaitReadySec с: смотреть $root\vanessa-start.log и окна 1С в RDP-сессии $($cfg['VANESSA_RDP_USER'])"
}
@{ utc = (Get-Date).ToUniversalTime().ToString('o'); tm = $tm; tc = $tc; old = $oldPids; port = $port } |
    ConvertTo-Json | Set-Content -Path (Join-Path $root '.vanessa-fresh.json') -Encoding UTF8
Write-Host "[va] OK: новая пара TM=$tm TC=$tc, MCP :$port готов" -ForegroundColor Green
exit 0
