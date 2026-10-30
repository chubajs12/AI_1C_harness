# Ставит MCP 1С в базу проекта: расширения MCP_Сервер (github.com/vladimir-kharin/1c_mcp, MIT — не меняем, обновляем
# только новой версией upstream) и MCP_ВыполнениеКода (инструменты execute_code / execute_query), публикация на IIS и
# проверка. Дистрибутив — MCP1C_DIST (по умолчанию tools\mcp1c): MCP_Сервер_v*.cfe, MCP_ВыполнениеКода_v*.cfe,
# MCP_Установщик_v*.epf (берется последняя версия каждого).
#
#   install-mcp.ps1               # установить/обновить расширения, опубликовать, проверить
#   install-mcp.ps1 -NoPublish    # только расширения
#
# 1. Служебная обработка MCP_Установщик в тонком клиенте под USER записывает оба CFE как расширения без безопасного
#    режима и завершает сеанс. Конфигуратор не нужен; и Конфигуратор, и форма «Расширения» БСП ставят НОВОЕ расширение
#    в безопасном режиме, а в нем execute_code не работает с файлами, внешними обработками и привилегированным режимом.
#    Журнал — %TEMP%\<PROJECT>_mcp_install.json.log. USER должен иметь право «Администрирование».
# 2. publish-mcp.ps1; пул перезапускается, чтобы сеансы публикации начались заново с новыми расширениями.
# 3. Проверка: список инструментов и execute_code («безопасный режим Нет»).
# Это изменение базы — только с согласия пользователя. Расширения применяются в новых сеансах; UpdateDB не нужен.
# Не ставится в базу мобильной платформы: «Назначения использования» коробки — PlatformApplication.
param(
    [int]$WaitMinutes = 5,
    [switch]$NoPublish,
    [string]$EnvFile = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$m = Get-KitMcp $cfg
if (-not (Test-Path -LiteralPath $cfg['PLATFORM_THIN'])) { throw "Нет тонкого клиента $($cfg['PLATFORM_THIN'])" }

function Get-LatestBuild([string]$Pattern) {
    $f = Get-ChildItem -LiteralPath $m.Dist -File -Filter $Pattern -ErrorAction SilentlyContinue |
        Sort-Object { [version](($_.BaseName -replace '^.*_v', '') -replace '_', '.') } | Select-Object -Last 1
    if (-not $f) { throw "Нет $Pattern в $($m.Dist)" }
    $f.FullName
}
$extensions = @(
    @{ name = 'MCP_Сервер'; cfe = (Get-LatestBuild 'MCP_Сервер_v*.cfe') },
    @{ name = 'MCP_ВыполнениеКода'; cfe = (Get-LatestBuild 'MCP_ВыполнениеКода_v*.cfe') }
)
$epf = Get-LatestBuild '*MCP_Установщик_v*.epf'
$extensions | ForEach-Object { "$($_.name): $($_.cfe)" }

# 1. Установка расширений служебной обработкой (файлы задания и журнала читает и пишет сервер 1С — тот же компьютер)
$task = Join-Path $env:TEMP "$($cfg['PROJECT'])_mcp_install.json"
$log = "$task.log"
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($task, (@{ extensions = $extensions } | ConvertTo-Json -Depth 4), $utf8)

$argString = "ENTERPRISE $(Get-KitIbArgs $cfg) /N`"$($cfg['USER'])`" /P`"$($cfg['PASS'])`" /Execute `"$epf`" " +
    "/C `"$task`" /DisableStartupDialogs /DisableStartupMessages"
$p = Start-Process -FilePath $cfg['PLATFORM_THIN'] -ArgumentList $argString -PassThru
"Установщик: 1cv8c PID=$($p.Id) ($($m.PlatformVer))"
if (-not $p.WaitForExit($WaitMinutes * 60000)) {
    Stop-Process -Id $p.Id -Force
    throw "Установщик не завершился за $WaitMinutes мин (PID $($p.Id) остановлен) — вероятно, в клиенте открыт диалог (вход, предупреждение безопасности EPF); сеанс на кластере — cluster-sessions.ps1"
}
if (-not (Test-Path -LiteralPath $log)) { throw "Нет журнала установщика $log (код клиента $($p.ExitCode))" }
$text = Get-Content -LiteralPath $log -Encoding UTF8
$text | ForEach-Object { "  $_" }
if (-not ($text -contains 'ГОТОВО')) { throw 'Установка расширений не удалась' }
Remove-Item -LiteralPath $task -ErrorAction SilentlyContinue

if ($NoPublish) { return }

# 2. Публикация и новые сеансы публикации
& (Join-Path $PSScriptRoot 'publish-mcp.ps1') -EnvFile $cfg['ENV_FILE']
& (Join-Path $env:windir 'system32\inetsrv\appcmd.exe') recycle apppool $m.Pool | Out-Null

# 3. Проверка (вывод python — UTF-8)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
$client = Join-Path $PSScriptRoot 'mcp1c.py'
& python $client --list
if ($LASTEXITCODE -ne 0) { throw "MCP не отвечает: $($m.Url)" }
# код — файлом: PowerShell 5.1 теряет кавычки внутри аргументов внешней программы
$check = Join-Path $env:TEMP "$($cfg['PROJECT'])_mcp_check.bsl"
[IO.File]::WriteAllText($check, 'Результат = "безопасный режим " + БезопасныйРежим() + ", пользователь " + ИмяПользователя();', $utf8)
$res = & python $client $check
Remove-Item -LiteralPath $check -ErrorAction SilentlyContinue
$res
if ("$res" -notmatch 'безопасный режим Нет') { throw "execute_code работает в безопасном режиме: $res" }
"MCP готов: $($m.Url)"
