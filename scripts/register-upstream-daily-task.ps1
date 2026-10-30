# Регистрация / обновление задачи AI_1C_upstream_daily с рабочим gh auth (интерактивный пользователь).
param(
    [switch]$SkipGh,
    [string]$Time = '07:00',
    [string]$TaskName = 'AI_1C_upstream_daily'
)
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'check-upstream-releases.ps1'
$wrapperPath = Join-Path $PSScriptRoot 'run-upstream-daily.ps1'
if (-not (Test-Path -LiteralPath $scriptPath)) { throw "нет $scriptPath" }

$skipArg = if ($SkipGh) { ' -SkipGh' } else { '' }
$tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`"$skipArg"

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`"$skipArg"
$trigger = New-ScheduledTaskTrigger -Daily -At $Time
$principal = New-ScheduledTaskPrincipal -UserId $currentUser -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host "[task] $TaskName user=$currentUser time=$Time SkipGh=$([bool]$SkipGh)"
Write-Host "[task] TR: $tr"
