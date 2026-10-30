# Публикует HTTP-сервис MCP (расширение MCP_Сервер, github.com/vladimir-kharin/1c_mcp) базы проекта на IIS.
#   publish-mcp.ps1            # сайт MCP1C_SITE только на 127.0.0.1:MCP1C_PORT, приложение /MCP1C_APP, свой пул
# Адрес: http://127.0.0.1:<MCP1C_PORT>/<MCP1C_APP>/hs/mcp. Повторный запуск обновляет публикацию.
#
# - Сайт слушает только 127.0.0.1: из сети сервис недоступен (он выполняет произвольный код под пользователем базы).
# - Пул — свой у проекта на версию платформы (MCP1C_POOL, по умолчанию 1c_mcp_<PROJECT>_<версия>): модули wsisapi разных
#   версий в одном процессе не держим, а остановка пула перед UpdateDB (mcp-pool.ps1 -Stop) не задевает публикации
#   других проектов на том же сайте.
# - В default.vrd — только сервис mcp_APIBackend (rootUrl mcp), без пользователя: вход — Basic-авторизация 1С
#   (USER/PASS из параметров; у клиента — заголовок Authorization). Веб-сервисы, OData, прочие HTTP-сервисы — выключены.
# - reuseSessions (MCP1C_REUSE_SESSIONS): autouse — сеансы публикации переиспользуются (вызов ~0,1–1 с), но сеанс держит
#   кэш (~20 с): чтение «через точку» от ссылки сразу после действия в интерфейсе дает старые данные, запись такого
#   объекта — «несоответствие версии». Лечится чтением запросами и паузой ~25 с перед записью или dontuse — новый сеанс
#   на каждый вызов (старт сеанса 10–20 с на большой конфигурации).
# Нужны права администратора Windows (appcmd) и установленный компонент IIS «Расширения ISAPI».
param([string]$EnvFile = '')

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$m = Get-KitMcp $cfg
$appcmd = Join-Path $env:windir 'system32\inetsrv\appcmd.exe'
if (-not (Test-Path -LiteralPath $appcmd)) { throw 'Нет IIS (appcmd.exe): установить роль Web Server с «Расширения ISAPI»' }
$isapi = Join-Path $m.PlatformBin 'wsisapi.dll'
if (-not (Test-Path -LiteralPath $isapi)) { throw "Нет $isapi — модуль веб-расширения 1С (компонент «Модули расширения веб-сервера» установщика платформы)" }
if ($m.Reuse -notin @('autouse', 'use', 'dontuse')) { throw "MCP1C_REUSE_SESSIONS: autouse | use | dontuse, а не $($m.Reuse)" }

function Invoke-AppCmd([string[]]$ArgList, [switch]$IgnoreError) {
    $out = & $appcmd @ArgList 2>&1
    if ($LASTEXITCODE -ne 0 -and -not $IgnoreError) { throw "appcmd $($ArgList -join ' '): $out" }
    $out
}

# Есть ли объект IIS с точно таким именем: «appcmd list app <путь>» отдает и родительское приложение по URL
function Test-AppCmd([string]$Kind, [string]$Identifier) {
    $out = & $appcmd list $Kind 2>&1
    return [bool]($out | Where-Object { $_ -like "* `"$Identifier`" *" })
}

# Пул проекта; простой без запросов не завершает рабочий процесс (иначе первый вызов после паузы ждет загрузки модуля 1С)
if (-not (Test-AppCmd 'apppool' $m.Pool)) {
    Invoke-AppCmd @('add', 'apppool', "/name:$($m.Pool)", '/managedRuntimeVersion:', '/managedPipelineMode:Integrated') | Out-Null
    "Пул $($m.Pool) создан"
}
Invoke-AppCmd @('set', 'apppool', $m.Pool, '/processModel.idleTimeout:00:00:00', '/recycling.periodicRestart.time:00:00:00') | Out-Null

# Сайт только на 127.0.0.1 (может быть уже создан публикацией другого проекта — тогда только добавляем приложение)
New-Item -ItemType Directory -Force -Path $m.IisRoot | Out-Null
if (-not (Test-AppCmd 'site' $m.Site)) {
    Invoke-AppCmd @('add', 'site', "/name:$($m.Site)", "/bindings:http/127.0.0.1:$($m.Port):", "/physicalPath:$($m.IisRoot)") | Out-Null
    Invoke-AppCmd @('set', 'app', "$($m.Site)/", "/applicationPool:$($m.Pool)") | Out-Null
    "Сайт $($m.Site) создан: http://127.0.0.1:$($m.Port)"
}

# Строка соединения с базой: кластер (Srvr/Ref) или файловая (File)
if ($cfg['INFOBASE_FILE']) {
    $ib = "File=&quot;$($cfg['INFOBASE_FILE'])&quot;;"
} else {
    $ib = "Srvr=&quot;$($cfg['INFOBASE_SERVER'])&quot;;Ref=&quot;$($cfg['INFOBASE_REF'])&quot;;"
}

# Каталог публикации: web.config (модуль 1С) и default.vrd (только MCP)
$dir = Join-Path $m.IisRoot $m.App
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$webConfig = @"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <system.webServer>
        <handlers>
            <add name="1C Web-service Extension" path="*" verb="*" modules="IsapiModule" scriptProcessor="$isapi" resourceType="Unspecified" requireAccess="None" />
        </handlers>
    </system.webServer>
</configuration>
"@
$vrd = @"
<?xml version="1.0" encoding="UTF-8"?>
<point xmlns="http://v8.1c.ru/8.2/virtual-resource-system"
		xmlns:xs="http://www.w3.org/2001/XMLSchema"
		xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
		base="/$($m.App)"
		ib="$ib">
	<ws pointEnableCommon="false" publishExtensionsByDefault="false"/>
	<httpServices publishByDefault="false" publishExtensionsByDefault="false">
		<service name="mcp_APIBackend"
				rootUrl="mcp"
				enable="true"
				reuseSessions="$($m.Reuse)"
				sessionMaxAge="20"
				poolSize="10"
				poolTimeout="5"/>
	</httpServices>
	<standardOdata enable="false"/>
</point>
"@
$utf8 = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $dir 'web.config'), $webConfig, $utf8)
[IO.File]::WriteAllText((Join-Path $dir 'default.vrd'), $vrd, $utf8)

# Приложение /<MCP1C_APP> в пуле проекта
if (Test-AppCmd 'app' "$($m.Site)/$($m.App)") {
    Invoke-AppCmd @('set', 'app', "$($m.Site)/$($m.App)", "/applicationPool:$($m.Pool)") | Out-Null
} else {
    Invoke-AppCmd @('add', 'app', "/site.name:$($m.Site)", "/path:/$($m.App)", "/physicalPath:$dir", "/applicationPool:$($m.Pool)") | Out-Null
}
# Модуль 1С как ISAPI-расширение должен быть разрешен на сервере
Invoke-AppCmd @('set', 'config', '/section:isapiCgiRestriction', "/+[path='$isapi',allowed='True',description='1C $($m.PlatformVer)']") -IgnoreError | Out-Null
Invoke-AppCmd @('set', 'config', '/section:isapiCgiRestriction', "/[path='$isapi'].allowed:True") -IgnoreError | Out-Null
Invoke-AppCmd @('start', 'site', $m.Site) -IgnoreError | Out-Null
"Опубликовано: $($m.Url) (пул $($m.Pool), reuseSessions=$($m.Reuse))"
