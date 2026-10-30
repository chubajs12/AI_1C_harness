# Проверка модулей расширения в базе по всем контекстам, включая мобильный клиент. Запускать после Full Load, до
# UpdateDB. Ветки #Если МобильныйКлиент тонкий клиент и тесты Vanessa не компилируют (в Energy так прошла ошибка:
# ТекущаяДатаСеанса() в клиентской ветке МК — АРМ не открывался на телефоне). Код возврата 0 — ошибок нет.
param(
    [ValidateSet('ext', 'conf')]
    [string]$Target = 'ext',
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$log = Join-Path $env:TEMP "$($cfg['PROJECT'])_checkmodules_$Target.log"
Remove-Item $log -ErrorAction SilentlyContinue
$argsList = @('DESIGNER', (Get-KitIbArgs $cfg), "/N`"$($cfg['USER'])`"", "/P`"$($cfg['PASS'])`"",
    '/DisableStartupDialogs', '/DisableStartupMessages',
    '/CheckModules', '-ThinClient', '-WebClient', '-Server', '-MobileClient')
if ($Target -eq 'ext') { $argsList += '-Extension', $cfg['EXTENSION_NAME'] }
$argsList += '/Out', "`"$log`""
Write-Host "[checkmodules] $Target : ThinClient WebClient Server MobileClient"
$p = Start-Process -FilePath $cfg['PLATFORM'] -ArgumentList $argsList -PassThru -Wait -WindowStyle Hidden
Write-Host "[checkmodules] exit=$($p.ExitCode)"
if (Test-Path $log) { Get-Content $log -Encoding UTF8 | Select-Object -Last 40 }
exit $p.ExitCode
