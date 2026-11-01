# Выгрузка расширения из базы в CFE: BUILD_DIR\<EXT_FILE_NAME>\<PROJECT>_<EXT_FILE_NAME>_vX_Y_Z.cfe.
# Версия — из <Version> EXT_DIR\Configuration.xml (или -Version). Прошлый CFE переносится в old\, VERSION обновляется.
# Запускать после Full Load + CheckModules + UpdateDB: CFE — то, что реально стоит в базе.
# Копия на диск обмена (Energy G:\): только scripts\1c\copy-cfe-release.ps1 — не Copy-Item -Force (rules/cfe-version-g-drive.md).
param(
    [string]$Version = '',
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile

if (-not $Version) {
    $xml = Join-Path $cfg['EXT_DIR'] 'Configuration.xml'
    $m = Select-String -LiteralPath $xml -Pattern '<Version>([^<]+)</Version>' | Select-Object -First 1
    if (-not $m) { throw "Версия не найдена в $xml" }
    $Version = $m.Matches[0].Groups[1].Value
}
$name = "$($cfg['PROJECT'])_$($cfg['EXT_FILE_NAME'])"
$buildRoot = Join-Path $cfg['BUILD_DIR'] $cfg['EXT_FILE_NAME']
$oldDir = Join-Path $buildRoot 'old'
New-Item -ItemType Directory -Force -Path $buildRoot, $oldDir | Out-Null

Get-ChildItem $buildRoot -Filter "${name}_v*.cfe" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Move-Item $_.FullName (Join-Path $oldDir $_.Name) -Force
    Write-Host "[cfe] прошлый $($_.Name) -> old\"
}

$cfe = Join-Path $buildRoot ("{0}_v{1}.cfe" -f $name, ($Version -replace '\.', '_'))
$log = Join-Path $env:TEMP "$($cfg['PROJECT'])_dumpcfg_$($Version -replace '\.', '_').log"
$argsList = @('DESIGNER', (Get-KitIbArgs $cfg), "/N`"$($cfg['USER'])`"", "/P`"$($cfg['PASS'])`"",
    '/DisableStartupDialogs', '/DisableStartupMessages', '/DumpCfg', "`"$cfe`"",
    '-Extension', $cfg['EXTENSION_NAME'], '/Out', "`"$log`"")
Write-Host "[cfe] DumpCfg $Version -> $cfe" -ForegroundColor Cyan
$p = Start-Process -FilePath $cfg['PLATFORM'] -ArgumentList $argsList -PassThru -Wait
if ($p.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $cfe)) {
    Get-Content $log -Encoding Default -ErrorAction SilentlyContinue | Select-Object -Last 40
    throw "DumpCfg не выполнен (exit=$($p.ExitCode))"
}
Set-Content -Path (Join-Path $buildRoot 'VERSION') -Value $Version -Encoding ASCII -NoNewline
Write-Host ("[cfe] OK {0} байт, версия {1}" -f (Get-Item -LiteralPath $cfe).Length, $Version) -ForegroundColor Green
Write-Output $cfe
