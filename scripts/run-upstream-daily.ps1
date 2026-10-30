# Оболочка для планировщика: PATH пользователя + gh keyring (не SYSTEM).
param([switch]$SkipGh)
$ErrorActionPreference = 'Continue'
$machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$env:Path = "$userPath;$machinePath"
$env:LOCALAPPDATA = [Environment]::GetEnvironmentVariable('LOCALAPPDATA', 'User')
$env:APPDATA = [Environment]::GetEnvironmentVariable('APPDATA', 'User')
$env:USERPROFILE = [Environment]::GetEnvironmentVariable('USERPROFILE', 'User')

$harnessRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $harnessRoot
$check = Join-Path $PSScriptRoot 'check-upstream-releases.ps1'
$params = @{}
if ($SkipGh) { $params.SkipGh = $true }
& $check @params
exit $LASTEXITCODE
