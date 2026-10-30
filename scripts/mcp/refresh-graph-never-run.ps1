# Запуск refresh_graph_project для project_id с ingestion_state never_run (или явный список).
# Обходит проблему PowerShell с кавычками в mcp_http.py.
param(
    [string[]]$ProjectIds = @(),
    [string]$GraphUrl = 'http://127.0.0.1:8006/mcp/',
    [string]$Mode = 'incremental',
    [int]$PollSeconds = 30,
    [int]$MaxWaitMinutes = 360
)
$ErrorActionPreference = 'Stop'
$harnessRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$py = Join-Path $PSScriptRoot 'refresh_graph_project.py'

if (-not $ProjectIds -or $ProjectIds.Count -eq 0) {
    $listJson = & python (Join-Path $PSScriptRoot 'mcp_http.py') $GraphUrl list_graph_projects '{}'
    if ($LASTEXITCODE -ne 0) { throw 'list_graph_projects failed' }
    $ProjectIds = @()
    foreach ($line in ($listJson -split "`n")) {
        if ($line -match '"project_id"\s*:\s*"([^"]+)"' -and $line -match '"ingestion_state"\s*:\s*"never_run"') {
            if ($line -match '"project_id"\s*:\s*"([^"]+)"') { $ProjectIds += $Matches[1] }
        }
    }
    # list_graph_projects returns one JSON line; parse properly
    try {
        $parsed = $listJson | ConvertFrom-Json
        $items = @()
        if ($parsed.items) { $items = $parsed.items }
        elseif ($parsed.data.items) { $items = $parsed.data.items }
        $ProjectIds = @($items | Where-Object { $_.ingestion_state -eq 'never_run' } | ForEach-Object { $_.project_id })
    } catch {
        Write-Warning "ConvertFrom-Json failed, using manual list"
        $ProjectIds = @(
            'BuhDemoConf', 'BuhDemoExt', 'EnergyConf', 'EnergyExt', 'MiraxConf',
            'Rostviplast', 'RostviplastExt', 'SmallBusinessConf', 'SmallBusinessExt'
        )
    }
}

Write-Host "[graph] refresh mode=$Mode projects: $($ProjectIds -join ', ')"
$ops = @{}
foreach ($pid in $ProjectIds) {
    Write-Host "=== start $pid ===" -ForegroundColor Cyan
    $out = & python $py $pid '' $Mode $GraphUrl 2>&1 | Out-String
    Write-Host $out
    if ($out -match '"operation_id"\s*:\s*"([^"]+)"') { $ops[$pid] = $Matches[1] }
}

if ($PollSeconds -le 0) { return }

$deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
Write-Host "[graph] polling list_graph_projects every ${PollSeconds}s (max ${MaxWaitMinutes} min)"
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds $PollSeconds
    $listJson = & python (Join-Path $PSScriptRoot 'mcp_http.py') $GraphUrl list_graph_projects '{}' 2>&1 | Out-String
    try {
        $parsed = $listJson | ConvertFrom-Json
        $items = if ($parsed.items) { $parsed.items } else { $parsed.data.items }
        $pending = @($ProjectIds | ForEach-Object {
            $id = $_
            $row = $items | Where-Object { $_.project_id -eq $id } | Select-Object -First 1
            if (-not $row) { return $id }
            if ($row.ingestion_state -eq 'never_run' -or $row.status -eq 'registered') { return $id }
            if ($row.last_error) { Write-Warning "$id last_error=$($row.last_error)" }
        })
        $pending = @($pending | Where-Object { $_ })
        if ($pending.Count -eq 0) {
            Write-Host '[graph] all targeted projects left never_run/registered' -ForegroundColor Green
            break
        }
        Write-Host "[graph] still pending: $($pending -join ', ')"
    } catch {
        Write-Warning "poll parse failed: $_"
    }
}

Write-Host '[graph] done (refresh may still run inside graph_mcp; check docker logs graph_mcp)'
