# Разовая настройка (администратор, с согласия пользователя): локальный Windows-пользователь VANESSA_RDP_USER для
# отдельной RDP-сессии, где живут окна TestManager/TestClient (они не должны мешать рабочему столу пользователя).
# Если пользователь и его RDP-сессия уже есть на машине (их делят проекты), этот скрипт не нужен — только права на
# каталоги проекта (-OnlyAcl).
# Пароль спрашивается интерактивно и нигде не сохраняется.
param(
    [switch]$EnableRdp,
    [switch]$OnlyAcl,
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$user = $cfg['VANESSA_RDP_USER']

$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Нужны права администратора' }

if (-not $OnlyAcl) {
    if (-not (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)) {
        $pwd = Read-Host -AsSecureString "Пароль для локального пользователя $user"
        New-LocalUser -Name $user -Password $pwd -FullName 'Vanessa Automation' -PasswordNeverExpires | Out-Null
        Write-Host "[setup] создан пользователь $user" -ForegroundColor Green
    }
    $rdpGroup = (Get-LocalGroup | Where-Object { $_.SID -eq 'S-1-5-32-555' }).Name  # «Пользователи удаленного рабочего стола»
    if (-not (Get-LocalGroupMember -Group $rdpGroup -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*\$user" })) {
        Add-LocalGroupMember -Group $rdpGroup -Member $user
    }
    if ($EnableRdp) {
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
        Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue
        Enable-NetFirewallRule -DisplayGroup 'Удаленный рабочий стол' -ErrorAction SilentlyContinue
    }
}

# чтение проекта (скрипты, фичи, параметры), запись — каталог Vanessa (pid, отчеты, скриншоты)
icacls $cfg['PROJECT_ROOT'] /grant "${user}:(OI)(CI)RX" /T /C /Q | Out-Null
New-Item -ItemType Directory -Force -Path $cfg['VANESSA_ROOT'], $cfg['VANESSA_REPORTS'] | Out-Null
icacls $cfg['VANESSA_ROOT'] /grant "${user}:(OI)(CI)M" /T /C /Q | Out-Null
icacls $cfg['VANESSA_REPORTS'] /grant "${user}:(OI)(CI)M" /T /C /Q | Out-Null
Write-Host "[setup] права $user на каталоги проекта выданы" -ForegroundColor Green
