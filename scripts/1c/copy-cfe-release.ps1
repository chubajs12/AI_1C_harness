# Безопасная копия CFE на диск обмена (Energy: G:\).
# Политика: rules/cfe-version-g-drive.md — не перезаписывать уже отданный файл того же имени версии.
param(
    [Parameter(Mandatory)]
    [string]$CfePath,
    [string]$ReleaseRoot = 'G:\'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $CfePath)) { throw "CFE not found: $CfePath" }
if (-not (Test-Path -LiteralPath $ReleaseRoot)) {
    New-Item -ItemType Directory -Force -Path $ReleaseRoot | Out-Null
}
$name = Split-Path -Leaf $CfePath
$dest = Join-Path $ReleaseRoot $name
if (Test-Path -LiteralPath $dest) {
    $hSrc = (Get-FileHash -LiteralPath $CfePath -Algorithm SHA256).Hash
    $hDst = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
    if ($hSrc -eq $hDst) {
        Write-Host "[cfe-g] skip: $name already on $ReleaseRoot (same SHA256)" -ForegroundColor Yellow
        return $dest
    }
    throw @"
[cfe-g] REFUSE: $dest exists with different content.
Policy: each user delivery / G:\ copy = new SemVer patch + new file name.
Do not Copy-Item -Force over an delivered version. Bump ext, DumpCfg, then copy the new file.
See harness/rules/cfe-version-g-drive.md
"@
}
Copy-Item -LiteralPath $CfePath -Destination $dest
Write-Host "[cfe-g] copied -> $dest" -ForegroundColor Green
return $dest
