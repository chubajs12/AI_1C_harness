# Проверка окружения комплекта (ничего не меняет): параметры, платформа, каталоги, инструменты, MCP, Docker, Vanessa.
#   doctor.ps1            # таблица OK / WARN / FAIL
# Запускать при первом запуске (docs/08) и когда «что-то не работает» — до того, как чинить.
param(
    [string]$EnvFile = '',
    [string]$Project = ''
)
if ($Project -and -not $EnvFile) {
    $EnvFile = Join-Path "F:\AI_1C\projects\$Project\config" 'project.env.local'
}
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'kitenv.ps1')
$rows = New-Object System.Collections.Generic.List[object]
function Add-Row([string]$What, [string]$State, [string]$Note) { $rows.Add([pscustomobject]@{ Проверка = $What; Итог = $State; Примечание = $Note }) }

try { $cfg = Get-KitEnv -EnvFile $EnvFile } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
Add-Row 'параметры' 'OK' $cfg['ENV_FILE']
$regPath = Get-KitPortsRegistryPath $cfg
if (Test-Path -LiteralPath $regPath) {
    Add-Row 'ports-registry' 'OK' "$regPath (project=$($cfg['HARNESS_PORTS_REGISTRY_PROJECT']))"
    $rawPortKeys = @{}
    foreach ($line in [IO.File]::ReadAllLines($cfg['ENV_FILE'], [Text.Encoding]::UTF8)) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k = ($line -split '=', 2)[0].Trim().TrimStart([char]0xFEFF)
        if ($k -in @('VANESSA_MCP_PORT', 'VANESSA_TC_PORT', 'CODE_INDEX_PORT', 'MCP1C_PORT')) { $rawPortKeys[$k] = $true }
    }
    if ($rawPortKeys.Count -gt 0) {
        Add-Row 'дубли портов в env' 'WARN' ("убрать из project.env.local — канон $($regPath): " + ($rawPortKeys.Keys -join ', '))
    }
    Add-Row 'Vanessa (реестр)' 'OK' "MCP $($cfg['VANESSA_MCP_PORT']) / TC $($cfg['VANESSA_TC_PORT'])"
} else {
    Add-Row 'ports-registry' 'WARN' "нет $regPath"
}
$empty = @($cfg.Keys | Where-Object { $cfg[$_] -match '^<.*>$' })
if ($empty) { Add-Row 'незаполненные параметры' 'FAIL' ($empty -join ', ') }

foreach ($k in @('PLATFORM', 'PLATFORM_THIN')) {
    if (Test-Path -LiteralPath $cfg[$k]) { Add-Row $k 'OK' $cfg[$k] } else { Add-Row $k 'FAIL' "нет $($cfg[$k])" }
}
foreach ($k in @('CONF_DIR', 'EXT_DIR')) {
    $x = Join-Path $cfg[$k] 'Configuration.xml'
    if (Test-Path -LiteralPath $x) { Add-Row $k 'OK' $cfg[$k] } else { Add-Row $k 'WARN' "нет выгрузки ($x) — designer.ps1 -Action Dump" }
}
$root = Get-KitRoot
$m = Get-KitMcp $cfg
$files = [ordered]@{
    (Join-Path $m.Dist 'MCP_Установщик_v*.epf') = 'дистрибутив MCP 1С (tools\mcp1c из архива комплекта)'
    $cfg['VANESSA_EPF'] = 'распаковать tools\vanessa\vanessa-automation-single.*.zip в tools\vanessa\single'
    (Join-Path $root 'tools\vanessa\client_mcp.cfe') = 'из архива комплекта'
    (Join-Path $root 'tools\vanessa\VAExtension.1.29.cfe') = 'из архива комплекта'
    $cfg['VANESSA_VAPARAMS'] = 'python scripts\vanessa\make_vaparams.py'
}
foreach ($f in $files.Keys) {
    if ($f -and (Test-Path -Path $f)) { Add-Row (Split-Path $f -Leaf) 'OK' $f }
    else { Add-Row (Split-Path $f -Leaf) 'WARN' "нет $f — $($files[$f])" }
}

function Test-Mcp([string]$Url) {
    try {
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"doctor","version":"1"}}}'
        $r = Invoke-WebRequest -Uri $Url -Method POST -Body $body -ContentType 'application/json' `
            -Headers @{ Accept = 'application/json, text/event-stream' } -TimeoutSec 5 -UseBasicParsing
        return $r.StatusCode -lt 400
    } catch { return $false }
}
$h = if ($cfg['MCP_HOST']) { $cfg['MCP_HOST'] } else { '127.0.0.1' }   # MCP-сервер команды (docs/10) или эта машина
$mcp = [ordered]@{
    '1c-syntax-checker-mcp :8002' = "http://${h}:8002/mcp"
    '1c-docs-mcp :8003' = "http://${h}:8003/mcp"
    '1c-templates-mcp :8004' = "http://${h}:8004/mcp"
    '1c-ssl-mcp :8008' = "http://${h}:8008/mcp"
    '1c-forms-mcp :8011' = "http://${h}:8011/mcp"
    'v8std :18766' = "http://${h}:18766/mcp"
    'graph-mcp :8006' = $cfg['GRAPH_URL']
    "code-index :$($cfg['CODE_INDEX_PORT'])" = "http://${h}:$($cfg['CODE_INDEX_PORT'])/mcp"
    "Vanessa :$($cfg['VANESSA_MCP_PORT'])" = "http://127.0.0.1:$($cfg['VANESSA_MCP_PORT'])/mcp"
}
foreach ($k in $mcp.Keys) {
    if (Test-Mcp $mcp[$k]) { Add-Row $k 'OK' $mcp[$k] }
    elseif ($k -match '^Vanessa') { Add-Row $k 'WARN' 'не запущен (restart-vanessa.ps1)' }
    elseif ($k -match '^code-index') { Add-Row $k 'WARN' 'не запущен (scripts\mcp\code-index\start-code-index.ps1)' }
    else { Add-Row $k 'FAIL' 'общий MCP не отвечает — сообщить пользователю, не пересоздавать' }
}

# MCP 1С базы: статус и безопасный режим execute_code (Basic USER/PASS)
$env:PYTHONIOENCODING = 'utf-8'
$client = Join-Path $root 'scripts\mcp1c\mcp1c.py'
$status = & python $client --status 2>&1
if ($LASTEXITCODE -eq 0) {
    $check = Join-Path $env:TEMP "$($cfg['PROJECT'])_doctor_mcp.bsl"
    [IO.File]::WriteAllText($check, 'Результат = "безопасный режим " + БезопасныйРежим();', (New-Object System.Text.UTF8Encoding($false)))
    $safe = & python $client $check 2>&1
    Remove-Item -LiteralPath $check -ErrorAction SilentlyContinue
    if ("$safe" -match 'безопасный режим Нет') { Add-Row "MCP 1С ($($m.Channel))" 'OK' $m.Url }
    else { Add-Row "MCP 1С ($($m.Channel))" 'WARN' "execute_code в безопасном режиме или с ошибкой — install-mcp.ps1 (docs/03): $("$safe".Substring(0, [Math]::Min(200, "$safe".Length)))" }
} else {
    Add-Row "MCP 1С ($($m.Channel))" 'WARN' "не отвечает: $($m.Url) — install-mcp.ps1 / mcp-pool.ps1 -Start (docs/03)"
}

$vaPort = [int]$cfg['VANESSA_MCP_PORT']
$listen = Get-NetTCPConnection -LocalPort $vaPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listen) {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$($listen.OwningProcess)" -ErrorAction SilentlyContinue
    if ($p.CommandLine -and $p.CommandLine -match (Get-KitIbPattern $cfg)) { Add-Row "порт $vaPort" 'OK' 'слушает свой TestManager' }
    else { Add-Row "порт $vaPort" 'FAIL' "занят чужим процессом PID $($listen.OwningProcess) — другой VANESSA_MCP_PORT" }
}

$dockerOk = $false
try { $null = docker version --format '{{.Server.Version}}' 2>$null; $dockerOk = ($LASTEXITCODE -eq 0) } catch { }
if ($dockerOk) {
    $st = docker ps -a --filter "name=^$($cfg['CODE_INDEX_CONTAINER'])$" --format '{{.Status}}'
    if ($st) { Add-Row $cfg['CODE_INDEX_CONTAINER'] ($(if ($st -match '^Up') { 'OK' } else { 'WARN' })) $st }
    else { Add-Row $cfg['CODE_INDEX_CONTAINER'] 'WARN' 'контейнера нет — start-code-index.ps1' }
} else { Add-Row 'docker' 'FAIL' 'docker недоступен этому пользователю (группа docker-users)' }

$rdp = (& query.exe user 2>&1 | Out-String) -match "\b$([regex]::Escape($cfg['VANESSA_RDP_USER']))\b"
Add-Row "RDP-сессия $($cfg['VANESSA_RDP_USER'])" ($(if ($rdp) { 'OK' } else { 'WARN' })) ($(if ($rdp) { 'есть' } else { 'нет — connect-rdp.ps1 (окна TM/TC живут там)' }))
$task = Get-ScheduledTask -TaskName $cfg['VANESSA_LAUNCH_TASK'] -ErrorAction SilentlyContinue
Add-Row "задача $($cfg['VANESSA_LAUNCH_TASK'])" ($(if ($task) { 'OK' } else { 'WARN' })) ($(if ($task) { 'есть' } else { 'нет — register-launch-task.ps1 (администратор)' }))

$py = Get-Command python -ErrorAction SilentlyContinue
Add-Row 'python' ($(if ($py) { 'OK' } else { 'FAIL' })) ($(if ($py) { $py.Source } else { 'нужен Python 3.10+' }))
foreach ($d in @($root, $cfg['SRC_ROOT'])) {
    if (Test-Path -LiteralPath (Join-Path $d '.git')) { Add-Row "git $d" 'OK' '' } else { Add-Row "git $d" 'WARN' 'нет локального репозитория (docs/05, git init)' }
}

$rows | Format-Table -AutoSize -Wrap
if ($rows.Итог -contains 'FAIL') { exit 1 }
exit 0
