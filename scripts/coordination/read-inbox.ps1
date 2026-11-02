# Print inbox messages that have no ack (type=ack, replyTo=<id>). Ack rows themselves are skipped.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('energy', 'dolea', 'harness')]
    [string]$Project,

    [string]$InboxFile
)

$ErrorActionPreference = 'Stop'

if (-not $InboxFile) {
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $InboxFile = Join-Path $root "coordination\inbox\$Project.jsonl"
}

if (-not (Test-Path -LiteralPath $InboxFile)) {
    Write-Output 'pending: 0'
    return
}

$rows = @()
$n = 0
foreach ($row in @(Get-Content -LiteralPath $InboxFile -Encoding UTF8)) {
    $n++
    if ([string]::IsNullOrWhiteSpace($row)) { continue }
    try {
        $rows += ($row | ConvertFrom-Json)
    } catch {
        throw "Malformed JSONL at line ${n}: $($_.Exception.Message)"
    }
}

$acked = @{}
foreach ($row in $rows) {
    if ([string]$row.type -eq 'ack' -and $row.replyTo) {
        $acked[[string]$row.replyTo] = $true
    }
}

$pending = @()
foreach ($row in $rows) {
    if ([string]$row.type -eq 'ack') { continue }
    if ($acked.ContainsKey([string]$row.id)) { continue }
    $pending += $row
}

Write-Output ("pending: {0}" -f $pending.Count)
foreach ($row in $pending) {
    Write-Output ($row | ConvertTo-Json -Compress -Depth 8)
}
