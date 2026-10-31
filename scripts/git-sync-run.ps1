# Fetch/pull upstream git clones and related repos (notify-only helper).
# P1: F:\AI_1C\upstream\git\* from upstream-watchlist.
$ErrorActionPreference = 'Continue'
$HarnessRoot = Split-Path $PSScriptRoot -Parent
$results = @()

function Sync-Repo {
    param(
        [string]$Path,
        [string]$CloneUrl = $null,
        [string]$Priority = ''
    )
    $row = [ordered]@{
        path     = $Path
        remote   = ''
        branch   = ''
        before   = ''
        after    = ''
        status   = 'skipped'
        priority = $Priority
        note     = ''
    }

    if (-not (Test-Path $Path)) {
        if ($CloneUrl) {
            $parent = Split-Path $Path -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            $name = Split-Path $Path -Leaf
            Push-Location $parent
            try {
                git clone $CloneUrl $name 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    $row.status = 'FAIL'
                    $row.note = 'clone failed'
                    Pop-Location
                    return [pscustomobject]$row
                }
            } finally { Pop-Location }
        } else {
            $row.status = 'skipped'
            $row.note = 'path missing, no clone URL'
            return [pscustomobject]$row
        }
    }

    if (-not (Test-Path (Join-Path $Path '.git'))) {
        $row.status = 'skipped'
        $row.note = 'not a git repo'
        return [pscustomobject]$row
    }

    Push-Location $Path
    try {
        $dirty = git status --porcelain 2>&1
        if ($dirty) {
            $row.status = 'dirty'
            $row.note = 'uncommitted changes'
        }

        $row.remote = (git remote get-url origin 2>&1) -join '; '
        if ($LASTEXITCODE -ne 0) { $row.remote = '(no origin)' }

        $row.branch = (git rev-parse --abbrev-ref HEAD 2>&1) -join ''
        $row.before = (git rev-parse HEAD 2>&1) -join ''

        git fetch --all --prune 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $row.status = 'FAIL'
            $row.note = 'fetch failed'
            $row.after = $row.before
            return [pscustomobject]$row
        }

        if ($row.status -ne 'dirty') {
            $pullOut = git pull --ff-only 2>&1
            if ($LASTEXITCODE -ne 0) {
                $row.status = 'FAIL'
                $row.note = ($pullOut | Select-Object -Last 3) -join ' '
            } else {
                $row.status = 'OK'
            }
        }

        $row.after = (git rev-parse HEAD 2>&1) -join ''
    } finally {
        Pop-Location
    }
    return [pscustomobject]$row
}

$gitRoot = 'F:\AI_1C\upstream\git'
$upstreamMap = @{
    '1c_mcp'               = 'https://github.com/vladimir-kharin/1c_mcp.git'
    '1c-formsserver'       = 'https://github.com/desko77/1c-formsserver.git'
    'ai_rules_1c'          = 'https://github.com/comol/ai_rules_1c.git'
    'cc-1c-skills'         = 'https://github.com/Nikolay-Shirokov/cc-1c-skills.git'
    'code-index-mcp'       = 'https://github.com/Regsorm/code-index-mcp.git'
    'v8std'                = 'https://github.com/zeegin/v8std.git'
    'vanessa-automation'   = 'https://github.com/Pr-Mex/vanessa-automation.git'
    'MCP_VypolnenieKoda'   = 'https://github.com/chubajs12/MCP_VypolnenieKoda.git'
}

foreach ($name in $upstreamMap.Keys | Sort-Object) {
    $p = Join-Path $gitRoot $name
    $results += Sync-Repo -Path $p -CloneUrl $upstreamMap[$name] -Priority 'P1'
}

$p2 = @(
    @{ Path = 'F:\AI_1C\harness'; Clone = 'https://github.com/chubajs12/AI_1C_harness.git' }
    @{ Path = 'F:\AI_Apps\harness'; Clone = 'https://github.com/chubajs12/AI_Apps_harness.git' }
)
foreach ($item in $p2) {
    $results += Sync-Repo -Path $item.Path -CloneUrl $item.Clone -Priority 'P2'
}

$projectRoots = @('F:\AI_1C\projects', 'F:\AI_Apps\projects')
$seen = @{}
foreach ($root in $projectRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($sub in @($_.FullName, ($_.FullName + '_src'))) {
            if ($seen[$sub]) { continue }
            if (Test-Path (Join-Path $sub '.git')) {
                $seen[$sub] = $true
                $results += Sync-Repo -Path $sub -Priority 'P3'
            }
        }
    }
}

$p4Skip = @('upstream', 'harness', 'projects', 'temp')
Get-ChildItem 'F:\AI_1C' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($p4Skip -contains $_.Name) { return }
    $git = Join-Path $_.FullName '.git'
    if ((Test-Path $git) -and -not $seen[$_.FullName]) {
        $seen[$_.FullName] = $true
        $results += Sync-Repo -Path $_.FullName -Priority 'P4'
    }
}

$outJson = Join-Path $HarnessRoot 'temp\git-sync-results.json'
if (-not (Test-Path (Split-Path $outJson -Parent))) { New-Item -ItemType Directory -Path (Split-Path $outJson -Parent) | Out-Null }
$results | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $outJson
$results | Format-Table -AutoSize
