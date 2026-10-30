# Загрузка в базу проекта служебных расширений тестирования: client_mcp (MCP-сервер Vanessa внутри TestManager,
# без него runMcp не слушает порт) и VAExtension (шаги «выполняю выражение в текущем окне» и др.).
# Это изменение базы — только с согласия пользователя (тестовая база проекта). Нужен монопольный доступ: пул публикации
# MCP 1С останавливается и после запускается снова (mcp-pool.ps1; при DB_CHANNEL=onebridge — останавливается OneBridge,
# поднять его — start-onebridge.ps1); пару Vanessa после — restart-vanessa.ps1.
# LoadCfg и UpdateDBCfg в одной команде на этой платформе дают «Ошибка в параметрах командной строки» — раздельно.
# Проверено на ERP 2.5 / платформе 8.3.27 (режим совместимости «Не использовать»). Если у конфигурации проекта режим
# совместимости расширений ниже, загрузка может не пройти — сообщить пользователю (config_info.bsl покажет режим).
# После загрузки снять у расширений «Безопасный режим» и «Защиту от опасных действий» в Конфигураторе или
# скриптом docs/04 (иначе расширения работают с ограничениями) — проверить в «Все функции -> Расширения».
param(
    [switch]$SkipClientMcp,
    [switch]$SkipVaExtension,
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$tools = Join-Path (Get-KitRoot) 'tools\vanessa'

$mcp = Get-KitMcp $cfg
$mcpPool = Join-Path $PSScriptRoot '..\mcp1c\mcp-pool.ps1'
$onebridge = Join-Path $PSScriptRoot '..\onebridge\start-onebridge.ps1'
if ($mcp.Channel -eq 'onebridge') {
    if (Test-Path $onebridge) { & $onebridge -Stop -EnvFile $cfg['ENV_FILE'] }
} elseif (Test-Path $mcpPool) {
    & $mcpPool -Stop -EnvFile $cfg['ENV_FILE']
}

function Invoke-Designer([string[]]$Tail, [string]$LogName) {
    $log = Join-Path $env:TEMP "$($cfg['PROJECT'])_$LogName.log"
    $argsList = @('DESIGNER', (Get-KitIbArgs $cfg), "/N`"$($cfg['USER'])`"", "/P`"$($cfg['PASS'])`"",
        '/DisableStartupDialogs', '/DisableStartupMessages') + $Tail + @('/Out', "`"$log`"")
    $p = Start-Process -FilePath $cfg['PLATFORM'] -ArgumentList $argsList -PassThru -Wait -WindowStyle Minimized
    if (Test-Path $log) { Get-Content $log -Encoding Default -ErrorAction SilentlyContinue | Select-Object -Last 12 }
    if ($p.ExitCode -ne 0) { throw "$LogName exit=$($p.ExitCode)" }
}

function Install-Extension([string]$Cfe, [string]$Name) {
    if (-not (Test-Path -LiteralPath $Cfe)) { throw "Нет файла $Cfe" }
    Write-Host "[helpers] LoadCfg $Name" -ForegroundColor Cyan
    Invoke-Designer @('/LoadCfg', "`"$Cfe`"", '-Extension', $Name) "load_$Name"
    Write-Host "[helpers] UpdateDBCfg $Name" -ForegroundColor Cyan
    Invoke-Designer @('/UpdateDBCfg', '-Extension', $Name) "updatedb_$Name"
}

try {
    if (-not $SkipClientMcp) { Install-Extension (Join-Path $tools 'client_mcp.cfe') 'client_mcp' }
    if (-not $SkipVaExtension) { Install-Extension (Join-Path $tools 'VAExtension.1.29.cfe') 'VAExtension' }
} finally {
    if ($mcp.Channel -ne 'onebridge' -and (Test-Path $mcpPool)) { & $mcpPool -Start -EnvFile $cfg['ENV_FILE'] }
}
Write-Host '[helpers] готово. Пару Vanessa поднять заново (restart-vanessa.ps1).' -ForegroundColor Green
