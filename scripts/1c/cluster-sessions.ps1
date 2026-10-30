# Сеансы базы проекта на кластере (rac через временный RAS): кто мешает UpdateDB.
#   cluster-sessions.ps1                       # сеансы базы + живые процессы клиентов 1С этой машины
#   cluster-sessions.ps1 -Terminate 163,170    # завершить сеансы по номерам — ТОЛЬКО с согласия пользователя
# Клиент 1С, убитый Stop-Process (рестарт Vanessa), оставляет сеанс на кластере (hibernate=yes) до
# суток — он мешает монопольным операциям (UpdateDB). Надежная проверка «мертвый» — нет живого процесса клиента с тем
# же временем начала (вторая таблица; время сеанса на кластере — на несколько секунд позже старта процесса).
# Мертвые сеансы своих процессов — завершать с согласия пользователя; живые сеансы людей — только спросив отдельно.
# Сеансы публикации MCP 1С (app-id HTTPServiceConnection под USER) живого процесса клиента не имеют — их завершает
# mcp-pool.ps1 -Stop вместе с остановкой пула, не этот скрипт.
# Служба RAS на машине может быть не установлена: скрипт поднимает ras.exe на RasPort и после останавливает.
param(
    [int[]]$Terminate = @(),
    [int]$RasPort = 1545,
    [string]$Cluster = 'localhost:1540',
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$bin = Split-Path $cfg['PLATFORM']
$rac = Join-Path $bin 'rac.exe'
$started = $null
if (-not (Get-NetTCPConnection -LocalPort $RasPort -State Listen -ErrorAction SilentlyContinue)) {
    $started = Start-Process -FilePath (Join-Path $bin 'ras.exe') -ArgumentList "cluster --port=$RasPort $Cluster" -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

function ConvertFrom-Rac([string[]]$Lines) {
    $items = @(); $cur = @{}
    foreach ($l in $Lines + '') {
        if (-not $l.Trim()) { if ($cur.Count) { $items += [pscustomobject]$cur; $cur = @{} }; continue }
        $k, $v = $l -split ':', 2
        $cur[$k.Trim()] = $v.Trim()
    }
    return $items
}

try {
    $cl = (ConvertFrom-Rac (& $rac "localhost:$RasPort" cluster list))[0].cluster
    $ib = (ConvertFrom-Rac (& $rac "localhost:$RasPort" infobase summary list --cluster=$cl) |
        Where-Object { $_.name -eq $cfg['INFOBASE_REF'] }).infobase
    if (-not $ib) { throw "База $($cfg['INFOBASE_REF']) не найдена в кластере $Cluster" }
    $sessions = ConvertFrom-Rac (& $rac "localhost:$RasPort" session list --cluster=$cl --infobase=$ib)
    if ($Terminate.Count) {
        foreach ($n in $Terminate) {
            $s = $sessions | Where-Object { [int]$_.'session-id' -eq $n }
            if (-not $s) { Write-Host "[sessions] нет сеанса $n" -ForegroundColor DarkYellow; continue }
            & $rac "localhost:$RasPort" session terminate --cluster=$cl --session=$($s.session)
            Write-Host "[sessions] завершен $n ($($s.'app-id') $($s.'user-name') $($s.'started-at'))"
        }
    } else {
        $sessions | Sort-Object { [int]$_.'session-id' } |
            Select-Object @{n = 'N'; e = { $_.'session-id' } }, @{n = 'Прил'; e = { $_.'app-id' } },
            @{n = 'Пользователь'; e = { $_.'user-name' } }, @{n = 'Начало'; e = { $_.'started-at' } },
            @{n = 'hibernate'; e = { $_.hibernate } }, @{n = 'Хост'; e = { $_.host } } | Format-Table -AutoSize | Out-String -Width 200 | Write-Host
        Write-Host 'Живые процессы клиентов 1С этой базы на машине:'
        Get-CimInstance Win32_Process -Filter "Name='1cv8.exe' OR Name='1cv8c.exe'" |
            Where-Object { $_.CommandLine -match (Get-KitIbPattern $cfg) } |
            Select-Object ProcessId, Name, @{n = 'Начало'; e = { $_.CreationDate.ToString('s') } },
            @{n = 'Режим'; e = { [regex]::Match($_.CommandLine, '/TESTMANAGER|/TestClient|DESIGNER').Value } } |
            Format-Table -AutoSize | Out-String -Width 200 | Write-Host
    }
} finally {
    if ($started) { Stop-Process -Id $started.Id -Force -ErrorAction SilentlyContinue }
}
