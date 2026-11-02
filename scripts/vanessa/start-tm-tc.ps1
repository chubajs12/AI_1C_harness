# Запуск пары Vanessa ВНУТРИ RDP-сессии пользователя VANESSA_RDP_USER (туда его запускает wts-launch.ps1):
#   TestManager (1cv8c /TESTMANAGER + vanessa-automation-single.epf, MCP на VANESSA_MCP_PORT через расширение client_mcp)
#   TestClient  (1cv8c /TestClient -TPort VANESSA_TC_PORT) — клиент, которым Vanessa кликает.
# PID пишутся в VANESSA_ROOT\.tm-pid / .tc-pid — по ним restart-vanessa.ps1 проверяет, что пара новая.
# Окна 1С остаются в RDP-сессии и не мешают рабочему столу пользователя. Классический плеер (StartFeaturePlayer)
# не используется — только MCP-режим (runMcp).
param(
    [Parameter(Mandatory)][string]$EnvFile,
    [switch]$NoTestClient,
    # TM: /DisableStartupDialogs ломает /Execute EPF (тихий отказ предупреждения безопасности) — по умолчанию выкл.
    [switch]$DisableStartupDialogsTm
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
if (-not $cfg['VANESSA_MCP_PORT'] -or -not $cfg['VANESSA_TC_PORT']) {
    $regFile = if ($cfg['HARNESS_PORTS_REGISTRY']) { $cfg['HARNESS_PORTS_REGISTRY'] } else {
        Join-Path ($(if ($cfg['HARNESS_ROOT']) { $cfg['HARNESS_ROOT'] } else { (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path })) 'config\ports-registry.json'
    }
    if (Test-Path -LiteralPath $regFile) {
        $reg = Get-Content -LiteralPath $regFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $p = $reg.projects.($cfg['PROJECT'])
        if ($p) {
            $cfg['VANESSA_MCP_PORT'] = [string]$p.vanessa_mcp_port
            $cfg['VANESSA_TC_PORT'] = [string]$p.vanessa_tc_port
        }
    }
}
if (-not $cfg['VANESSA_MCP_PORT'] -or -not $cfg['VANESSA_TC_PORT']) {
    throw "VANESSA_MCP_PORT/VANESSA_TC_PORT пусты — PROJECT=$($cfg['PROJECT']), ports-registry"
}

$v8c = $cfg['PLATFORM_THIN']
$epf = $cfg['VANESSA_EPF']
$params = $cfg['VANESSA_VAPARAMS']
$root = $cfg['VANESSA_ROOT']
foreach ($f in @($v8c, $epf, $params)) { if (-not (Test-Path -LiteralPath $f)) { throw "Нет файла $f" } }
$pidTm = Join-Path $root '.tm-pid'
$pidTc = Join-Path $root '.tc-pid'
$ib = Get-KitIbArgs $cfg
$auth = "/N`"$($cfg['USER'])`" /P`"$($cfg['PASS'])`""

# /C разбирает client_mcp: ключи через «;», голое число недопустимо. QuietInstallVanessaExt и DisableFirstRunHelper —
# для свежего профиля Windows (пользователь vanessa): компонента ставится без вопросов, без мастера первого запуска.
$c = "VAParams=$params;useaddin;runMcp;mcpPort=$($cfg['VANESSA_MCP_PORT']);QuietInstallVanessaExt;DisableFirstRunHelper"
$tm = "ENTERPRISE $ib $auth /TESTMANAGER /Execute`"$epf`" /DisableStartupMessages"
if ($DisableStartupDialogsTm) { $tm += ' /DisableStartupDialogs' }
$tm += " /C`"$c`""

$p = Start-Process -FilePath $v8c -ArgumentList $tm -PassThru
Set-Content -Path $pidTm -Value $p.Id -Encoding ASCII -NoNewline
Write-Host "[vanessa] TM PID=$($p.Id) MCP :$($cfg['VANESSA_MCP_PORT']) VAParams=$params"

if (-not $NoTestClient) {
    Start-Sleep -Seconds 12
    $tc = "ENTERPRISE $ib $auth /TestClient -TPort $($cfg['VANESSA_TC_PORT']) /DisableStartupDialogs /DisableStartupMessages"
    $p2 = Start-Process -FilePath $v8c -ArgumentList $tc -PassThru
    Set-Content -Path $pidTc -Value $p2.Id -Encoding ASCII -NoNewline
    Write-Host "[vanessa] TC PID=$($p2.Id) порт $($cfg['VANESSA_TC_PORT'])"
}
