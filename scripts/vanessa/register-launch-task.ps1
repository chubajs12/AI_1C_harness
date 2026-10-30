# Разовая настройка (администратор, с согласия пользователя): задача планировщика VANESSA_LAUNCH_TASK от SYSTEM с
# наивысшими правами, которая запускает wts-launch.ps1 — так агент без прав администратора поднимает пару Vanessa
# в RDP-сессии командой «schtasks /Run» (restart-vanessa.ps1). Триггеров нет: задача запускается только по требованию.
param([string]$EnvFile = '')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$name = $cfg['VANESSA_LAUNCH_TASK']
$script = Join-Path $PSScriptRoot 'wts-launch.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -EnvFile `"$($cfg['ENV_FILE'])`""
$principal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
Register-ScheduledTask -TaskName $name -Action $action -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "[task] задача $name зарегистрирована: $script" -ForegroundColor Green
