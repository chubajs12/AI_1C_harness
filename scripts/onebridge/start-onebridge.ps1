# ЗАПАСНОЙ вариант (docs/09, DB_CHANNEL=onebridge); основной канал в базу — MCP 1С (scripts\mcp1c, docs/03).
# OneBridge проекта: толстый клиент 1С (управляемое приложение) + обработка OneBridge.epf, которая поднимает HTTP MCP
# на ONEBRIDGE_PORT внутри сеанса базы. Запускается в сеансе пользователя (console), не в RDP-сессии Vanessa.
#
#   start-onebridge.ps1            # поднять, если не отвечает (ждет до 3 минут)
#   start-onebridge.ps1 -Status    # код 0 — отвечает
#   start-onebridge.ps1 -Stop      # остановить ТОЛЬКО свой процесс (PID из .onebridge-pid), чужие 1С не трогать
#   start-onebridge.ps1 -Force     # перезапустить
#
# Мешает монопольным операциям (UpdateDB, загрузка служебных расширений): designer.ps1 сам останавливает и поднимает.
param(
    [switch]$Force,
    [switch]$Status,
    [switch]$Stop,
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile

$Port = $cfg['ONEBRIDGE_PORT']
$Epf = if ($cfg['ONEBRIDGE_EPF']) { $cfg['ONEBRIDGE_EPF'] } else { Join-Path (Get-KitRoot) 'tools\onebridge\OneBridge.epf' }
$Url = "http://127.0.0.1:$Port/mcp"
$PidFile = Join-Path $PSScriptRoot ".onebridge-$($cfg['PROJECT'])-pid"

function Test-OneBridge {
    try {
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}'
        $r = Invoke-WebRequest -Uri $Url -Method POST -Body $body -ContentType 'application/json' `
            -Headers @{ Accept = 'application/json, text/event-stream' } -TimeoutSec 3 -UseBasicParsing
        return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500)
    } catch {
        return $false
    }
}

function Stop-TrackedOneBridge {
    if (-not (Test-Path $PidFile)) {
        Write-Host "[onebridge] нет PID-файла ($PidFile) — чужие 1cv8 не трогаю" -ForegroundColor DarkYellow
        return
    }
    $tracked = [int]((Get-Content $PidFile -Raw).Trim())
    $proc = Get-Process -Id $tracked -ErrorAction SilentlyContinue
    if ($proc -and $proc.ProcessName -match '^1cv8') {
        Write-Host "[onebridge] останавливаю свой процесс 1С PID $tracked" -ForegroundColor Yellow
        Stop-Process -Id $tracked -Force
    }
    Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
}

if ($Status) {
    if (Test-OneBridge) { Write-Host "[onebridge] UP $Url" -ForegroundColor Green; exit 0 }
    Write-Host "[onebridge] DOWN $Url" -ForegroundColor DarkYellow
    exit 1
}
if ($Stop) { Stop-TrackedOneBridge; exit 0 }
if (-not $Force -and (Test-OneBridge)) { Write-Host "[onebridge] уже работает на :$Port" -ForegroundColor Green; exit 0 }
if ($Force) { Stop-TrackedOneBridge }

if (-not (Test-Path -LiteralPath $Epf)) { throw "Нет OneBridge.epf: $Epf" }
$before = @(Get-Process -Name '1cv8' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })

# Параметр /C разбирается и OneBridge, и client_mcp (если он есть в базе) как структура: голое «1440» — недопустимый
# ключ (начинается с цифры). OneBridge понимает «1440» | «Port=1440» | «MCPPort=1440» — используем Port=.
$argLine = "ENTERPRISE $(Get-KitIbArgs $cfg) /N`"$($cfg['USER'])`" /P`"$($cfg['PASS'])`" /Execute `"$Epf`" /C `"Port=$Port`" /RunModeManagedApplication /DisableStartupDialogs"
Write-Host "[onebridge] запуск 1С + OneBridge на :$Port ($($cfg['INFOBASE_SERVER'])/$($cfg['INFOBASE_REF']))" -ForegroundColor Cyan
$null = Start-Process -FilePath $cfg['PLATFORM'] -ArgumentList $argLine -PassThru

$deadline = (Get-Date).AddMinutes(3)
$resolved = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 3
    if (-not $resolved) {
        $new = @(Get-Process -Name '1cv8' -ErrorAction SilentlyContinue | Where-Object { $before -notcontains $_.Id })
        if ($new.Count -ge 1) {
            $resolved = ($new | Sort-Object StartTime -Descending | Select-Object -First 1).Id
            Set-Content -Path $PidFile -Value $resolved -Encoding ASCII -NoNewline
        }
    }
    if (Test-OneBridge) {
        Write-Host "[onebridge] OK $Url (PID $resolved)" -ForegroundColor Green
        exit 0
    }
}
Write-Host "[onebridge] не отвечает на :$Port за 3 минуты — посмотреть окно 1С (вход, предупреждение безопасности EPF)" -ForegroundColor Yellow
exit 1
