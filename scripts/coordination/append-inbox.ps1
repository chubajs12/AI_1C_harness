# Append one JSON object as a single UTF-8 line to coordination/inbox/<project>.jsonl.
# Does not rewrite existing lines. Rejects a duplicate id and secret-like field names.
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('energy', 'dolea', 'harness')]
    [string]$Project,

    [Parameter(Mandatory = $true)]
    [string]$MessageJson,

    [string]$InboxFile
)

$ErrorActionPreference = 'Stop'

$allowedTypes = @('request', 'reply', 'notify', 'ack')
$required = @('id', 'thread', 'at', 'from', 'to', 'type', 'subject', 'body')

try {
    $msg = $MessageJson | ConvertFrom-Json
} catch {
    throw "Invalid JSON: $($_.Exception.Message)"
}

foreach ($name in $required) {
    $has = $msg.PSObject.Properties.Name -contains $name
    if (-not $has) { throw "Missing field: $name" }
    $val = $msg.$name
    if ($null -eq $val) { throw "Empty field: $name" }
    if ($val -is [string] -and [string]::IsNullOrWhiteSpace($val)) { throw "Empty field: $name" }
}

if ($allowedTypes -notcontains [string]$msg.type) {
    throw "type must be one of: $($allowedTypes -join ', ')"
}
if (-not $msg.from.project) { throw 'from.project is required' }
if (-not $msg.to.project) { throw 'to.project is required' }
if ([string]$msg.type -eq 'ack' -and -not $msg.replyTo) { throw 'ack requires replyTo' }

function Test-NoSecrets {
    param($Node)
    if ($null -eq $Node) { return }
    if ($Node -is [string] -or $Node -is [ValueType]) { return }
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in @($Node.PSObject.Properties)) {
            if ($p.MemberType -ne 'NoteProperty') { continue }
            if ($p.Name -match '^(?i)(password|passwd|token|secret|api_key|apikey)$') {
                throw "Secret-like field is forbidden: $($p.Name)"
            }
            Test-NoSecrets -Node $p.Value
        }
        return
    }
    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in @($Node)) { Test-NoSecrets -Node $item }
    }
}
Test-NoSecrets -Node $msg

$line = $msg | ConvertTo-Json -Compress -Depth 8
if ($line -match '[\r\n]') { throw 'Serialized message must be one line' }

if (-not $InboxFile) {
    $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $InboxFile = Join-Path $root "coordination\inbox\$Project.jsonl"
}

$dir = Split-Path -Parent $InboxFile
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

if (Test-Path -LiteralPath $InboxFile) {
    foreach ($row in @(Get-Content -LiteralPath $InboxFile -Encoding UTF8)) {
        if ([string]::IsNullOrWhiteSpace($row)) { continue }
        $old = $row | ConvertFrom-Json
        if ([string]$old.id -eq [string]$msg.id) { throw "Duplicate id: $($msg.id)" }
    }
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::AppendAllText($InboxFile, ($line + "`n"), $utf8)
Write-Output $InboxFile
