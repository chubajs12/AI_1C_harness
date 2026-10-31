# Idempotent deploy: canonical clone main -> harness/tools/mcp1c (CFE).
# After develop work: merge to main on GitHub, then run this script.
# Design: docs/16_MCP_VypolnenieKoda.md
param(
    [string]$CanonicalRepo = 'F:\AI_1C\upstream\git\MCP_VypolnenieKoda',
    [string]$DevWorktree = 'F:\AI_1C\projects\mcp-vypolnenie-koda_dev',
    [string]$DistDir = '',
    [switch]$FetchDev
)

$ErrorActionPreference = 'Stop'
$HarnessRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not $DistDir) { $DistDir = Join-Path $HarnessRoot 'tools\mcp1c' }
$tempDir = Join-Path $HarnessRoot 'temp'
$stateFile = Join-Path $tempDir 'mcp-vypolnenie-koda-deploy.sha'
$logFile = Join-Path $tempDir ("sync-mcp-vypolnenie-koda-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Write-Log([string]$Msg) {
    $line = "{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Msg
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

if (-not (Test-Path -LiteralPath $CanonicalRepo)) {
    throw "Нет canonical repo: $CanonicalRepo"
}
if (-not (Test-Path -LiteralPath $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
}

Write-Log "fetch $CanonicalRepo (main)"
Push-Location -LiteralPath $CanonicalRepo
try {
    cmd /c "git fetch origin --prune 2>&1" | ForEach-Object { Write-Log $_ }
    cmd /c "git checkout main 2>&1" | ForEach-Object { Write-Log $_ }
    cmd /c "git pull --ff-only origin main 2>&1" | ForEach-Object { Write-Log $_ }
    $sha = (git rev-parse HEAD).Trim()
} finally {
    Pop-Location
}

if ($FetchDev -and (Test-Path -LiteralPath $DevWorktree)) {
    Write-Log "fetch dev worktree $DevWorktree"
    Push-Location -LiteralPath $DevWorktree
    try {
        cmd /c "git fetch origin --prune 2>&1" | ForEach-Object { Write-Log $_ }
        cmd /c "git status -sb 2>&1" | ForEach-Object { Write-Log $_ }
    } finally {
        Pop-Location
    }
}

$prevSha = ''
if (Test-Path -LiteralPath $stateFile) {
    $prevSha = (Get-Content -LiteralPath $stateFile -Raw).Trim()
}

Write-Log "HEAD main=$sha (prev=$prevSha)"
if ($sha -eq $prevSha) {
    Write-Log 'SHA unchanged, deploy skipped'
    exit 0
}

# MCP_Сервер / установщик - not this component (Unicode names)
$cfeExclude = 'MCP_\u0421\u0435\u0440\u0432\u0435\u0440|\u0423\u0441\u0442\u0430\u043d\u043e\u0432\u0449\u0438\u043a'

$buildDir = Join-Path $CanonicalRepo 'build'
$cfe = Get-ChildItem -LiteralPath $buildDir -File -Filter '*.cfe' -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -notmatch $cfeExclude } |
    Sort-Object { [version](($_.BaseName -replace '^.*_v', '') -replace '_', '.') } |
    Select-Object -Last 1
if (-not $cfe) {
    Write-Log "WARN: net CFE v $buildDir, tolko git obnovlen"
    Set-Content -LiteralPath $stateFile -Value $sha -Encoding ASCII -NoNewline
    exit 0
}

$oldDir = Join-Path $DistDir 'old'
if (-not (Test-Path -LiteralPath $oldDir)) { New-Item -ItemType Directory -Path $oldDir | Out-Null }

Get-ChildItem -LiteralPath $DistDir -File -Filter '*.cfe' -ErrorAction SilentlyContinue |
    Where-Object { $_.BaseName -notmatch $cfeExclude } |
    ForEach-Object {
        $dest = Join-Path $oldDir $_.Name
        if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
        Move-Item -LiteralPath $_.FullName -Destination $dest
        Write-Log "archived $($_.Name) -> old/"
    }

Copy-Item -LiteralPath $cfe.FullName -Destination (Join-Path $DistDir $cfe.Name) -Force
Write-Log "copied $($cfe.Name) -> $DistDir"

Set-Content -LiteralPath $stateFile -Value $sha -Encoding ASCII -NoNewline
Write-Log 'done: pri smene CFE - install-mcp.ps1 po proektam (s soglasiya)'
Write-Log "log: $logFile"
