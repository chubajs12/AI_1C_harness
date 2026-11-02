# Vanessa for Dolea: ports from harness config/ports-registry.yaml (9875 / 1542).
# Does not stop SmallBusiness :9880/:1539 or other foreign processes.
param(
    [switch]$StopOnly,
    [switch]$RegisterTask,
    [switch]$Status,
    [int]$WaitReadySec = 240
)
$ErrorActionPreference = 'Stop'
$EnvFile = 'F:\AI_1C\projects\dolea\config\project.env.local'
if (-not (Test-Path -LiteralPath $EnvFile)) {
    throw "Missing env file: $EnvFile"
}
$env:KIT_ENV_FILE = $EnvFile
$kit = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
. (Join-Path $kit 'kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
if ($cfg['PROJECT'] -ne 'dolea') {
    throw "PROJECT must be dolea, got $($cfg['PROJECT'])"
}
$vaPort = [int]$cfg['VANESSA_MCP_PORT']
$tcPort = [int]$cfg['VANESSA_TC_PORT']
$ibPattern = Get-KitIbPattern $cfg
$root = $cfg['VANESSA_ROOT']

function Get-DoleaVanessaProcs {
    @(Get-CimInstance Win32_Process -Filter "Name='1cv8c.exe' OR Name='1cv8.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match $ibPattern -and
            ($_.CommandLine -match "/TESTMANAGER.*mcpPort=$vaPort\b" -or $_.CommandLine -match "/TestClient\s+-TPort\s+$tcPort\b") })
}

function Test-VaMcp {
    try {
        $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"status","version":"1"}}}'
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$vaPort/mcp" -Method POST -Body $body -ContentType 'application/json' `
            -Headers @{ Accept = 'application/json, text/event-stream' } -TimeoutSec 5 -UseBasicParsing
        return $r.StatusCode -lt 400
    } catch { return $false }
}

if ($Status) {
    $sb = Get-NetTCPConnection -LocalPort 9880 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    $own = Get-DoleaVanessaProcs
    $listen = Get-NetTCPConnection -LocalPort $vaPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    [pscustomobject]@{
        Registry        = $cfg['HARNESS_PORTS_REGISTRY']
        VanessaMcpPort  = $vaPort
        TestClientPort  = $tcPort
        VanessaRoot     = $root
        OwnProcesses    = @($own | ForEach-Object { $_.ProcessId }) -join ','
        McpListening    = [bool]$listen
        McpToolsReady   = (Test-VaMcp)
        SmallBusiness9880 = [bool]$sb
        SmallBusinessPid  = if ($sb) { $sb.OwningProcess } else { $null }
    } | Format-List
    exit 0
}

Write-Host "[dolea-va] MCP :$vaPort TC :$tcPort IB $($cfg['INFOBASE_SERVER'])/$($cfg['INFOBASE_REF'])" -ForegroundColor Cyan

if ($RegisterTask) {
    & (Join-Path $PSScriptRoot 'register-launch-task.ps1') -EnvFile $EnvFile
    if (-not $StopOnly) {
        Write-Host '[dolea-va] task registered; rerun without -RegisterTask to start' -ForegroundColor Yellow
        exit 0
    }
}

$make = Join-Path $PSScriptRoot 'make_vaparams.py'
& python $make
if ($LASTEXITCODE -ne 0) { throw "make_vaparams.py failed with exit code $LASTEXITCODE" }

$restartArgs = @{ EnvFile = $EnvFile; WaitReadySec = $WaitReadySec }
if ($StopOnly) { $restartArgs['StopOnly'] = $true }
& (Join-Path $PSScriptRoot 'restart-vanessa.ps1') @restartArgs
