# Параметры проекта для скриптов комплекта: config\project.env.local (из project.env.example).
# Использование в скрипте:  . (Join-Path $PSScriptRoot '..\kitenv.ps1'); $cfg = Get-KitEnv
# Get-KitEnv -EnvFile <путь> — другой файл (например, вторая база). Пароль в вывод не печатать: Hide-KitSecrets.

function Get-KitRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Get-KitEnv {
    param([string]$EnvFile = '')
    # KIT_ENV_FILE — другой файл параметров (вторая база, проверки комплекта)
    if (-not $EnvFile) { $EnvFile = $env:KIT_ENV_FILE }
    if (-not $EnvFile) { $EnvFile = Join-Path (Get-KitRoot) 'config\project.env.local' }
    if (-not (Test-Path -LiteralPath $EnvFile)) {
        throw "Нет файла параметров $EnvFile — скопируйте config\project.env.example в project.env.local и заполните"
    }
    $vals = @{}
    # UTF-8 (с BOM или без): кириллица в имени расширения и префиксе
    foreach ($line in [IO.File]::ReadAllLines($EnvFile, [Text.Encoding]::UTF8)) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k, $v = $line -split '=', 2
        $vals[$k.Trim().TrimStart([char]0xFEFF)] = $v.Trim()
    }
    $vals['ENV_FILE'] = $EnvFile
    return Merge-KitPortsFromRegistry $vals
}

function Get-KitPortsRegistryPath {
    param([hashtable]$Cfg)
    if ($Cfg['HARNESS_PORTS_REGISTRY']) { return $Cfg['HARNESS_PORTS_REGISTRY'] }
    $root = if ($Cfg['HARNESS_ROOT']) { $Cfg['HARNESS_ROOT'] } else { Get-KitRoot }
    return Join-Path $root 'config\ports-registry.json'
}

function Merge-KitPortsFromRegistry {
    # Числовые порты и graph/mcp1c app — из config/ports-registry.json по ключу PROJECT (не дублировать в project.env.local).
    param([hashtable]$Cfg)
    $path = Get-KitPortsRegistryPath $Cfg
    if (-not (Test-Path -LiteralPath $path)) { return $Cfg }
    try {
        $reg = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        Write-Warning "ports-registry: не прочитан $path — $($_.Exception.Message)"
        return $Cfg
    }
    $proj = $Cfg['PROJECT']
    if (-not $proj -or -not $reg.projects.PSObject.Properties[$proj]) { return $Cfg }
    $p = $reg.projects.$proj
    $map = [ordered]@{
        VANESSA_MCP_PORT     = 'vanessa_mcp_port'
        VANESSA_TC_PORT      = 'vanessa_tc_port'
        CODE_INDEX_PORT      = 'code_index_port'
        MCP1C_APP            = 'mcp1c_app'
        GRAPH_PROJECT_CONF   = 'graph_project_conf'
        GRAPH_PROJECT_EXT    = 'graph_project_ext'
    }
    foreach ($envKey in $map.Keys) {
        $regKey = $map[$envKey]
        if ($null -ne $p.$regKey) { $Cfg[$envKey] = [string]$p.$regKey }
    }
    if ($reg.shared.mcp1c_iis.port) { $Cfg['MCP1C_PORT'] = [string]$reg.shared.mcp1c_iis.port }
    if ($reg.shared.mcp_host -and -not $Cfg['MCP_HOST']) { $Cfg['MCP_HOST'] = $reg.shared.mcp_host }
    $Cfg['HARNESS_PORTS_REGISTRY'] = $path
    $Cfg['HARNESS_PORTS_REGISTRY_PROJECT'] = $proj
    return $Cfg
}

function Get-KitIbArgs {
    # Строка подключения к базе для командной строки 1С: /S"сервер/база" или /F"каталог"
    param([hashtable]$Cfg)
    if ($Cfg['INFOBASE_FILE']) { return "/F`"$($Cfg['INFOBASE_FILE'])`"" }
    return "/S`"$($Cfg['INFOBASE_SERVER'])/$($Cfg['INFOBASE_REF'])`""
}

function Get-KitIbPattern {
    # Регулярное выражение «эта база в командной строке процесса 1С» — останавливать только свои процессы.
    # С закрывающей кавычкой /S"сервер/база": база myproj не должна совпасть с myproj_t1.
    param([hashtable]$Cfg)
    if ($Cfg['INFOBASE_FILE']) { return [regex]::Escape($Cfg['INFOBASE_FILE']) + '"' }
    return [regex]::Escape("$($Cfg['INFOBASE_SERVER'])/$($Cfg['INFOBASE_REF'])") + '"'
}

function Get-KitMcp {
    # Параметры MCP 1С (публикация HTTP-сервиса MCP_Сервер на IIS) со значениями по умолчанию
    param([hashtable]$Cfg)
    $bin = Split-Path $Cfg['PLATFORM']
    $ver = Split-Path (Split-Path $bin) -Leaf   # ...\1cv8\8.3.27.1936\bin -> 8.3.27.1936
    $app = if ($Cfg['MCP1C_APP']) { $Cfg['MCP1C_APP'] } elseif ($Cfg['INFOBASE_REF']) { $Cfg['INFOBASE_REF'] } else { $Cfg['PROJECT'] }
    $port = if ($Cfg['MCP1C_PORT']) { [int]$Cfg['MCP1C_PORT'] } else { 8095 }
    $m = [ordered]@{
        Port         = $port
        App          = $app
        Site         = if ($Cfg['MCP1C_SITE']) { $Cfg['MCP1C_SITE'] } else { '1c_mcp' }
        IisRoot      = if ($Cfg['MCP1C_IIS_ROOT']) { $Cfg['MCP1C_IIS_ROOT'] } else { 'C:\inetpub\1c_mcp' }
        # Свой пул у проекта на версию платформы: модули wsisapi разных версий в одном процессе не уживаются, а
        # остановка пула перед UpdateDB не задевает публикации других проектов
        Pool         = if ($Cfg['MCP1C_POOL']) { $Cfg['MCP1C_POOL'] } else { "1c_mcp_$($Cfg['PROJECT'])_$ver" }
        Reuse        = if ($Cfg['MCP1C_REUSE_SESSIONS']) { $Cfg['MCP1C_REUSE_SESSIONS'] } else { 'autouse' }
        Dist         = if ($Cfg['MCP1C_DIST']) { $Cfg['MCP1C_DIST'] } else { Join-Path (Get-KitRoot) 'tools\mcp1c' }
        PlatformBin  = $bin
        PlatformVer  = $ver
        RasPort      = if ($Cfg['RAS_PORT']) { [int]$Cfg['RAS_PORT'] } else { 1545 }
        Cluster      = if ($Cfg['CLUSTER']) { $Cfg['CLUSTER'] } else { 'localhost:1540' }
        Channel      = 'mcp1c'
    }
    $m['Url'] = if ($Cfg['MCP1C_URL']) { $Cfg['MCP1C_URL'] } else { "http://127.0.0.1:$port/$app/hs/mcp" }
    return $m
}

function Hide-KitSecrets {
    param([string]$Text, [hashtable]$Cfg)
    $Text = $Text -replace '/P"[^"]*"', '/P"***"'
    foreach ($key in @('PASS')) {
        if ($Cfg -and $Cfg[$key]) { $Text = $Text.Replace($Cfg[$key], '***') }
    }
    return $Text
}
