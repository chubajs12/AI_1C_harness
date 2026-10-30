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
    return $vals
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
        Channel      = if ($Cfg['DB_CHANNEL']) { $Cfg['DB_CHANNEL'].ToLower() } else { 'mcp1c' }
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
