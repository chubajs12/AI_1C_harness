# Сверка локальных клонов upstream с GitHub (dry-run по умолчанию).
# Дизайн: docs/11_Upstream_релизы.md. Ничего не pull/copy без -Apply и whitelist.
#   .\check-upstream-releases.ps1
#   .\check-upstream-releases.ps1 -Apply   # только fetch для id из autoPullWhitelist (после «да» на политику)
param(
    [string]$Watchlist = '',
    [switch]$Apply,
    [switch]$SkipGh
)
$ErrorActionPreference = 'Continue'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $PSScriptRoot '..\VERSION'))) {
    $root = Split-Path $PSScriptRoot -Parent
} else {
    $root = Split-Path $PSScriptRoot -Parent
}
if (-not $Watchlist) { $Watchlist = Join-Path $PSScriptRoot 'upstream-watchlist.json' }
if (-not (Test-Path -LiteralPath $Watchlist)) { Write-Error "нет watchlist: $Watchlist"; exit 1 }

$wl = Get-Content -LiteralPath $Watchlist -Raw -Encoding UTF8 | ConvertFrom-Json
$tempDir = Join-Path $root 'temp'
if (-not (Test-Path -LiteralPath $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$reportPath = Join-Path $tempDir "upstream-check-$stamp.md"

function Get-LocalPin([string]$Path) {
    $o = [ordered]@{ ok = $false; head = ''; tag = ''; branch = ''; err = '' }
    if (-not (Test-Path -LiteralPath $Path)) { $o.err = 'нет папки'; return [pscustomobject]$o }
    Push-Location -LiteralPath $Path
    try {
        $o.head = (git rev-parse --short HEAD 2>$null)
        $o.branch = (git rev-parse --abbrev-ref HEAD 2>$null)
        $o.tag = (git describe --tags --abbrev=0 2>$null)
        $o.ok = [bool]$o.head
        if (-not $o.ok) { $o.err = 'не git / нет HEAD' }
    } finally { Pop-Location }
    return [pscustomobject]$o
}

function Get-RemoteLatest([string]$Github, [string]$Prefer) {
    $o = [ordered]@{ ok = $false; kind = ''; value = ''; url = ''; err = '' }
    if (-not $Github) { $o.err = 'github не задан'; return [pscustomobject]$o }
    if ($SkipGh) { $o.err = 'SkipGh'; return [pscustomobject]$o }
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) { $o.err = 'gh не найден'; return [pscustomobject]$o }

    if ($Prefer -eq 'release' -or $Prefer -eq 'tag' -or $Prefer -eq 'tag-or-commit') {
        $json = gh release view -R $Github --json tagName,publishedAt,url 2>$null
        if ($LASTEXITCODE -eq 0 -and $json) {
            $r = $json | ConvertFrom-Json
            $o.ok = $true; $o.kind = 'release'; $o.value = $r.tagName; $o.url = $r.url
            return [pscustomobject]$o
        }
    }
    if ($Prefer -ne 'release') {
        $tagsJson = gh api "repos/$Github/tags?per_page=1" 2>$null
        if ($LASTEXITCODE -eq 0 -and $tagsJson -and $tagsJson -ne '[]') {
            $t = ($tagsJson | ConvertFrom-Json)[0]
            $o.ok = $true; $o.kind = 'tag'; $o.value = $t.name
            $o.url = "https://github.com/$Github/releases/tag/$($t.name)"
            return [pscustomobject]$o
        }
        $meta = gh api "repos/$Github" --jq ".default_branch" 2>$null
        if ($LASTEXITCODE -eq 0 -and $meta) {
            $sha = gh api "repos/$Github/commits/$meta" --jq ".sha" 2>$null
            if ($LASTEXITCODE -eq 0 -and $sha) {
                $o.ok = $true; $o.kind = 'commit'; $o.value = $sha.Substring(0, [Math]::Min(7, $sha.Length))
                $o.url = "https://github.com/$Github/commit/$sha"
                return [pscustomobject]$o
            }
        }
    }
    $o.err = 'нет release/tag/commit (или нет auth)'
    return [pscustomobject]$o
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Upstream check $stamp")
$lines.Add('')
$lines.Add("Mode: $(if ($Apply) { 'APPLY (whitelist fetch only)' } else { 'dry-run / notify-only' })")
$lines.Add("Policy: $($wl.policy.defaultMode)")
$lines.Add('')
$lines.Add('| id | local | remote | status |')
$lines.Add('|----|--------|--------|--------|')

$newer = 0
foreach ($repo in $wl.repos) {
    $local = Get-LocalPin $repo.localPath
    $remote = Get-RemoteLatest $repo.github $repo.prefer
    $localLabel = if ($local.ok) { "$(if ($local.tag) { $local.tag } else { $local.head }) @$($local.branch)" } else { $local.err }
    $remoteLabel = if ($remote.ok) { "$($remote.kind):$($remote.value)" } else { $remote.err }

    $status = 'unknown'
    if (-not $local.ok) { $status = 'local-missing' }
    elseif (-not $remote.ok) { $status = 'remote-skip' }
    elseif ($remote.kind -eq 'release' -or $remote.kind -eq 'tag') {
        if ($local.tag -and ($local.tag -eq $remote.value -or $local.tag -eq ($remote.value -replace '^v',''))) {
            $status = 'ok'
        } else {
            $status = 'newer-remote'; $newer++
        }
    } elseif ($remote.kind -eq 'commit') {
        if ($local.head -and $remote.value.StartsWith($local.head)) { $status = 'ok' }
        elseif ($local.head -eq $remote.value) { $status = 'ok' }
        else { $status = 'newer-or-diverged'; $newer++ }
    }

    $lines.Add("| $($repo.id) | $localLabel | $remoteLabel | $status |")
    if ($remote.url) { $lines.Add("|  |  | $($remote.url) |  |") }

    if ($Apply -and $repo.github -and $wl.policy.autoPullWhitelist -contains $repo.id) {
        if (Test-Path -LiteralPath $repo.localPath) {
            Push-Location -LiteralPath $repo.localPath
            try {
                Write-Host "fetch $($repo.id)..." -ForegroundColor Cyan
                git fetch --tags --prune 2>&1 | Out-Host
            } finally { Pop-Location }
        }
    } elseif ($Apply) {
        Write-Host "skip apply $($repo.id) (не в autoPullWhitelist)" -ForegroundColor DarkYellow
    }
}

$lines.Add('')
$lines.Add('## MCP package sources (local)')
$lines.Add('')
$lines.Add('| id | path/url | newest artifact | note |')
$lines.Add('|----|----------|-----------------|------|')

foreach ($src in @($wl.mcpPackageSources)) {
    $note = ''
    $newest = '-'
    if ($src.kind -eq 'local-folder' -and $src.path) {
        $p = $src.path -replace '/', '\'
        if (Test-Path -LiteralPath $p) {
            $files = Get-ChildItem -LiteralPath $p -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($files) { $newest = "$($files.Name) ($($files.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" }
            else { $newest = 'empty'; $note = 'no files' }
        } else {
            $newest = 'missing'; $note = 'path missing'
        }
    } else {
        $newest = 'manual'; $note = "$($src.kind) $($src.url)"
    }
    $loc = if ($src.path) { $src.path } else { $src.url }
    $lines.Add(('| {0} | {1} | {2} | {3} |' -f $src.id, $loc, $newest, $note))
}

$lines.Add('')
$lines.Add('## Docker images (compose groups, digest local)')
$lines.Add('')
$composeImages = @(
    @{ g = '1c'; f = 'F:\MCP_Distr\compose-1c\docker-compose.yml' },
    @{ g = '2graph'; f = 'F:\MCP_Distr\graph\docker-compose.yml' },
    @{ g = '3codeindex'; f = 'F:\MCP_Distr\compose-codeindex\docker-compose.yml' }
)
foreach ($c in $composeImages) {
    if (-not (Test-Path -LiteralPath $c.f)) { continue }
    $yml = Get-Content -LiteralPath $c.f -Raw -Encoding UTF8
    $imgs = [regex]::Matches($yml, '(?m)^\s*image:\s*(.+)$') | ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object -Unique
    foreach ($img in $imgs) {
        $id = (docker image inspect $img --format '{{.Id}}' 2>$null)
        if (-not $id) { $id = 'not-local' }
        else { $id = $id.Substring(7, 12) }
        $lines.Add(('| {0} | {1} | {2} |' -f $c.g, $img, $id))
    }
}

$lines.Add('')
$lines.Add("Итого потенциально свежее/расхождение (git): $newer")
$lines.Add('')
$lines.Add('Schedule: Windows Task AI_1C_upstream_daily (notify dry-run). Apply/auto-pull: docs/11_Upstream_релизы.md')

$report = ($lines -join "`n") + "`n"
Set-Content -LiteralPath $reportPath -Value $report -Encoding UTF8
Write-Host $report
Write-Host "Report: $reportPath" -ForegroundColor Green
if ($newer -gt 0) { exit 2 } else { exit 0 }
