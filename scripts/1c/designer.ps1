# Конфигуратор в пакетном режиме: выгрузка/загрузка XML и обновление базы. Логи — в %TEMP%, хвост печатается.
#
#   designer.ps1 -Action Dump                 # расширение -> EXT_DIR (Full)
#   designer.ps1 -Action Dump -Target conf    # основная конфигурация -> CONF_DIR (часы на больших базах)
#   designer.ps1 -Action Load                 # EXT_DIR -> расширение (только Full; перед загрузкой сортировка + UUID)
#   designer.ps1 -Action UpdateDB             # обновление базы для расширения (отдельной командой после Load)
#
# Правила (AGENTS.md п. 1.3, 1.7): Load только Full, UpdateDB отдельно и без лимита времени, основную конфигурацию
# не загружать без явного разрешения пользователя (-AllowConfLoad). UpdateDB требует монопольного доступа: пул IIS
# публикации MCP 1С проекта останавливается (сеансы публикации держат базу, mcp-pool.ps1) и после запускается снова;
# при запасном канале DB_CHANNEL=onebridge так же останавливается и поднимается OneBridge. Спящие сеансы убитых
# клиентов тоже мешают (docs/05, cluster-sessions.ps1).
param(
    [Parameter(Mandatory)]
    [ValidateSet('Dump', 'Load', 'UpdateDB')]
    [string]$Action,

    [ValidateSet('ext', 'conf')]
    [string]$Target = 'ext',

    # Каталог выгрузки; по умолчанию EXT_DIR / CONF_DIR из параметров
    [string]$ConfigDir = '',

    # Dump: только изменения относительно прошлой выгрузки (-update -force, нужен ConfigDumpInfo.xml)
    [switch]$Changes,

    # UpdateDB: динамическое обновление (-Dynamic+)
    [switch]$Dynamic,

    # Разрешение пользователя загружать/обновлять основную конфигурацию
    [switch]$AllowConfLoad,

    # Не трогать MCP 1С (пул публикации) / OneBridge перед UpdateDB
    [Alias('KeepOneBridge')]
    [switch]$KeepMcp,

    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile

$isExt = $Target -eq 'ext'
if (-not $ConfigDir) { $ConfigDir = if ($isExt) { $cfg['EXT_DIR'] } else { $cfg['CONF_DIR'] } }
$Extension = if ($isExt) { $cfg['EXTENSION_NAME'] } else { '' }
if ($isExt -and -not $Extension) { throw 'EXTENSION_NAME не задан в параметрах проекта' }
if (-not $isExt -and $Action -ne 'Dump' -and -not $AllowConfLoad) {
    throw 'Загрузка/обновление основной конфигурации — только с явного разрешения пользователя (-AllowConfLoad)'
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Log = Join-Path $env:TEMP "$($cfg['PROJECT'])_designer_${Action}_${Target}_$stamp.log"
$PidFile = Join-Path $PSScriptRoot '.designer-pid'
$mcp = Get-KitMcp $cfg
$mcpPool = Join-Path $PSScriptRoot '..\mcp1c\mcp-pool.ps1'
$onebridge = Join-Path $PSScriptRoot '..\onebridge\start-onebridge.ps1'
$restartMcp = $false
$restartOneBridge = $false

if ($Action -eq 'Load') {
    if (-not (Test-Path -LiteralPath (Join-Path $ConfigDir 'Configuration.xml'))) { throw "Нет $ConfigDir\Configuration.xml" }
    if ($isExt) {
        # состав расширения — по имени по возрастанию (как «Сортировка метаданных»), подсистемы — как есть
        $env:PYTHONIOENCODING = 'utf-8'
        & python (Join-Path $PSScriptRoot 'sort-configuration-objects.py') $ConfigDir
        if ($LASTEXITCODE -ne 0) { throw 'sort-configuration-objects.py завершился с ошибкой' }
        & python (Join-Path $PSScriptRoot 'uuid-check.py') $ConfigDir
        if ($LASTEXITCODE -ne 0) { throw 'Проверка UUID не пройдена — загрузка остановлена (uuid-check.py --fix исправит фиктивные)' }
    }
}

if ($Action -eq 'UpdateDB' -and -not $KeepMcp -and $mcp.Channel -eq 'mcp1c' -and (Test-Path $mcpPool)) {
    Write-Host "[designer] останавливаю пул публикации MCP 1С ($($mcp.Pool)) на время UpdateDB" -ForegroundColor Yellow
    & $mcpPool -Stop -EnvFile $cfg['ENV_FILE']
    $restartMcp = $true
}
if ($Action -in @('Load', 'UpdateDB') -and -not $KeepMcp -and $mcp.Channel -eq 'onebridge' -and (Test-Path $onebridge)) {
    & $onebridge -Status -EnvFile $cfg['ENV_FILE'] | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host '[designer] OneBridge проекта запущен — останавливаю на время операции' -ForegroundColor Yellow
        & $onebridge -Stop -EnvFile $cfg['ENV_FILE']
        $restartOneBridge = $true
        Start-Sleep -Seconds 5
    }
}

if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
$argsList = @('DESIGNER', (Get-KitIbArgs $cfg), "/N`"$($cfg['USER'])`"", "/P`"$($cfg['PASS'])`"",
    '/DisableStartupDialogs', '/DisableStartupMessages')
switch ($Action) {
    'Dump' {
        $argsList += '/DumpConfigToFiles', "`"$ConfigDir`"", '-Format', 'Hierarchical'
        if ($Changes) { $argsList += '-update', '-force' }
    }
    'Load' { $argsList += '/LoadConfigFromFiles', "`"$ConfigDir`"", '-Format', 'Hierarchical' }
    'UpdateDB' {
        $argsList += '/UpdateDBCfg'
        if ($Dynamic) { $argsList += '-Dynamic+' }
    }
}
if ($Extension) { $argsList += '-Extension', $Extension }
$argsList += '/Out', "`"$Log`""

Write-Host ("[designer] {0} {1} {2}" -f $Action, $Target, $ConfigDir) -ForegroundColor Cyan
Write-Host ("[designer] {0}" -f (Hide-KitSecrets ($argsList -join ' ') $cfg))
Write-Host "[designer] лог: $Log"

$p = Start-Process -FilePath $cfg['PLATFORM'] -ArgumentList $argsList -PassThru
Set-Content -Path $PidFile -Value $p.Id -Encoding ASCII -NoNewline
$p.WaitForExit()
$ec = $p.ExitCode
Remove-Item $PidFile -Force -ErrorAction SilentlyContinue

Write-Host "[designer] exit=$ec"
if (Test-Path $Log) {
    Write-Host '--- лог (хвост) ---'
    Get-Content $Log -Encoding Default -ErrorAction SilentlyContinue | Select-Object -Last 40
}
if ($restartMcp) {
    Write-Host '[designer] запускаю пул публикации MCP 1С' -ForegroundColor Cyan
    & $mcpPool -Start -EnvFile $cfg['ENV_FILE']
}
if ($restartOneBridge) {
    Write-Host '[designer] поднимаю OneBridge обратно' -ForegroundColor Cyan
    & $onebridge -EnvFile $cfg['ENV_FILE']
}
exit $ec
