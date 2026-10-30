# Пул IIS публикации MCP 1С проекта (MCP1C_POOL): освободить базу для монопольных операций (UpdateDB, загрузка
# служебных расширений) и вернуть MCP после.
#   mcp-pool.ps1 -Stop    — остановить пул, дождаться выхода рабочего процесса и завершить оставшиеся сеансы публикации
#                           (app-id HTTPServiceConnection под USER в базе проекта): сеанс без соединения кластер держит
#                           и после остановки пула. rac — через RAS на RAS_PORT; служба RAS может быть не установлена —
#                           тогда поднимается временный ras.exe и останавливается после. MCP до -Start отвечает 503,
#                           публикации других проектов (свои пулы) не затрагиваются. Вызывается из designer.ps1.
#   mcp-pool.ps1 -Start   — запустить пул (первый вызов MCP после старта — 10–20 с, старт сеанса)
#   mcp-pool.ps1          — состояние пула и рабочих процессов
param(
    [switch]$Stop,
    [switch]$Start,
    [int]$WaitSeconds = 120,
    [string]$EnvFile = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$m = Get-KitMcp $cfg
$appcmd = Join-Path $env:windir 'system32\inetsrv\appcmd.exe'

function Get-PoolWorkers { @(& $appcmd list wp "/apppool.name:$($m.Pool)" 2>$null | Where-Object { $_ }) }

# Завершить сеансы публикации MCP (HTTPServiceConnection под USER) в базе проекта; файловая база — сеансов кластера нет
function Stop-McpSessions {
    if ($cfg['INFOBASE_FILE']) { return }
    $rac = Join-Path $m.PlatformBin 'rac.exe'
    $ras = $null
    if (-not (Get-NetTCPConnection -LocalPort $m.RasPort -State Listen -ErrorAction SilentlyContinue)) {
        $ras = Start-Process (Join-Path $m.PlatformBin 'ras.exe') -ArgumentList 'cluster', "--port=$($m.RasPort)", $m.Cluster -PassThru -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    try {
        $ras_ = "localhost:$($m.RasPort)"
        $cluster = ([regex]::Match(((& $rac $ras_ cluster list) -join "`n"), 'cluster\s+:\s+(\S+)')).Groups[1].Value
        $ibList = (& $rac $ras_ infobase summary list "--cluster=$cluster") -join "`n"
        $name = [regex]::Escape($cfg['INFOBASE_REF'])
        $ib = [regex]::Match($ibList, "infobase\s+:\s+(\S+)\s+name\s+:\s+$name(\r?\n|$)").Groups[1].Value
        if (-not $ib) { return }
        $user = [regex]::Escape($cfg['USER'])
        $blocks = ((& $rac $ras_ session list "--cluster=$cluster" "--infobase=$ib") -join "`n") -split "`n\s*`n"
        foreach ($b in $blocks) {
            if ($b -notmatch 'app-id\s+:\s+HTTPServiceConnection' -or $b -notmatch "user-name\s+:\s+$user(\r?\n|$)") { continue }
            $sid = [regex]::Match($b, 'session\s+:\s+(\S+)').Groups[1].Value
            $num = [regex]::Match($b, 'session-id\s+:\s+(\d+)').Groups[1].Value
            & $rac $ras_ session terminate "--cluster=$cluster" "--session=$sid" | Out-Null
            "Сеанс публикации №$num завершен"
        }
    } finally {
        if ($ras) { Stop-Process -Id $ras.Id -Force -ErrorAction SilentlyContinue }
    }
}

if (-not (Test-Path -LiteralPath $appcmd) -or -not (& $appcmd list apppool "/apppool.name:$($m.Pool)" 2>$null)) {
    "Пула $($m.Pool) нет — MCP 1С не опубликован (install-mcp.ps1), останавливать нечего"
    return
}
if ($Stop) {
    $out = & $appcmd stop apppool "/apppool.name:$($m.Pool)" 2>&1
    if ($LASTEXITCODE -ne 0 -and "$out" -notmatch 'already stopped|уже остановлен') { throw "appcmd stop: $out" }
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-PoolWorkers).Count -gt 0) {
        if ((Get-Date) -gt $deadline) { throw "Рабочий процесс пула $($m.Pool) не завершился за $WaitSeconds с" }
        Start-Sleep -Milliseconds 500
    }
    "Пул $($m.Pool) остановлен, рабочих процессов нет"
    Stop-McpSessions
    return
}
if ($Start) {
    $out = & $appcmd start apppool "/apppool.name:$($m.Pool)" 2>&1
    if ($LASTEXITCODE -ne 0 -and "$out" -notmatch 'already started|уже запущен') { throw "appcmd start: $out" }
    "Пул $($m.Pool) запущен"
    return
}
& $appcmd list apppool "/apppool.name:$($m.Pool)"
Get-PoolWorkers
