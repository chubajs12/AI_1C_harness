# Vanessa for Dolea: ports from harness config/ports-registry.json (9875 / 1542).
# Does not stop SmallBusiness :9880/:1539 or other foreign processes.
param(
    [switch]$StopOnly,
    [switch]$RegisterTask,
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

Write-Host "[dolea-va] MCP :$($cfg['VANESSA_MCP_PORT']) TC :$($cfg['VANESSA_TC_PORT']) IB $($cfg['INFOBASE_SERVER'])/$($cfg['INFOBASE_REF'])" -ForegroundColor Cyan

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
