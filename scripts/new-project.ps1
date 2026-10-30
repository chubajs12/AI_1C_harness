# Создание каркаса проекта линии 1С (без базы, без MCP 1С, без Docker).
# Дизайн: docs/00_Подключить_проект.md
#   .\new-project.ps1 -Name myproj -WhatIf
#   .\new-project.ps1 -Name myproj
#   .\new-project.ps1 -Name energy -SrcRoot F:\AI_1C\projects\energy_ext_src
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z][a-z0-9_]*$')]
    [string]$Name,

    [string]$SrcRoot = '',
    [string]$ProjectsRoot = 'F:\AI_1C\projects',
    [string]$HarnessRoot = 'F:\AI_1C\harness',
    [string]$Prefix = 'пр_',
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = Join-Path $ProjectsRoot $Name
if (-not $SrcRoot) {
    $SrcRoot = Join-Path $ProjectsRoot "${Name}_src"
}

function Write-Plan([string]$Msg) {
    if ($WhatIf) { Write-Host "[plan] $Msg" -ForegroundColor Cyan }
    else { Write-Host $Msg -ForegroundColor Green }
}

function Ensure-Dir([string]$Path) {
    if (Test-Path -LiteralPath $Path) { return }
    if ($WhatIf) { Write-Plan "mkdir $Path" }
    else { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

if ((Test-Path -LiteralPath $projectRoot) -and -not $Force) {
    throw "Уже есть $projectRoot (добавьте -Force для дозаполнения шаблонов)"
}

Write-Plan "PROJECT_ROOT=$projectRoot"
Write-Plan "SRC_ROOT=$SrcRoot"

Ensure-Dir $projectRoot
Ensure-Dir (Join-Path $projectRoot 'config')
Ensure-Dir (Join-Path $projectRoot 'tasks')
Ensure-Dir (Join-Path $projectRoot 'indexes\code-index\home')
Ensure-Dir (Join-Path $projectRoot 'indexes\code-index\conf')
Ensure-Dir (Join-Path $projectRoot 'indexes\code-index\ext')
Ensure-Dir (Join-Path $SrcRoot 'conf')
Ensure-Dir (Join-Path $SrcRoot 'ext')
Ensure-Dir (Join-Path $SrcRoot 'build')

$cap = ($Name.Substring(0, 1).ToUpper() + $Name.Substring(1))
$projectMd = @"
# $Name

Линия 1С. Правила, skills, scripts, MCP: ``$HarnessRoot`` (``docs/00_Подключить_проект.md``).

| Что | Путь |
|-----|------|
| Обвязка / tasks | ``$projectRoot`` |
| Сырцы conf/ext/build | ``$SrcRoot`` |
| Индекс кода | ``$projectRoot\indexes\code-index`` |
| Параметры (секреты) | ``config\project.env.local`` (не в git) |

Создано скриптом ``scripts\new-project.ps1`` $(Get-Date -Format 'yyyy-MM-dd').
"@

$projectMdPath = Join-Path $projectRoot 'PROJECT.md'
if ($WhatIf) { Write-Plan "write $projectMdPath" }
elseif (-not (Test-Path -LiteralPath $projectMdPath) -or $Force) {
    [IO.File]::WriteAllText($projectMdPath, $projectMd, (New-Object Text.UTF8Encoding $false))
}

$template = Join-Path $HarnessRoot 'config\project.env.example'
$envLocal = Join-Path $projectRoot 'config\project.env.local'
if (-not (Test-Path -LiteralPath $template)) { throw "Нет шаблона $template" }

if ($WhatIf) {
    Write-Plan "copy $template -> $envLocal (подстановка PROJECT/SRC_ROOT/GRAPH_*)"
} elseif (-not (Test-Path -LiteralPath $envLocal) -or $Force) {
    $text = Get-Content -LiteralPath $template -Raw -Encoding UTF8
    $text = $text -replace '(?m)^PROJECT=.*', "PROJECT=$Name"
    $text = $text -replace '(?m)^PREFIX=.*', "PREFIX=$Prefix"
    $text = $text -replace '(?m)^PROJECT_ROOT=.*', "PROJECT_ROOT=$projectRoot"
    $text = $text -replace '(?m)^SRC_ROOT=.*', "SRC_ROOT=$SrcRoot"
    $text = $text -replace '(?m)^CONF_DIR=.*', "CONF_DIR=$SrcRoot\conf"
    $text = $text -replace '(?m)^EXT_DIR=.*', "EXT_DIR=$SrcRoot\ext"
    $text = $text -replace '(?m)^BUILD_DIR=.*', "BUILD_DIR=$SrcRoot\build"
    $text = $text -replace '(?m)^INFOBASE_REF=.*', "INFOBASE_REF=$Name"
    $text = $text -replace '(?m)^MCP1C_APP=.*', "MCP1C_APP=$Name"
    $text = $text -replace '(?m)^CODE_INDEX_CONTAINER=.*', "CODE_INDEX_CONTAINER=${Name}_code_index"
    $text = $text -replace '(?m)^CODE_INDEX_IMAGE=.*', "CODE_INDEX_IMAGE=${Name}-code-index:1.8.5"
    $text = $text -replace '(?m)^GRAPH_PROJECT_CONF=.*', "GRAPH_PROJECT_CONF=${cap}Conf"
    $text = $text -replace '(?m)^GRAPH_PROJECT_EXT=.*', "GRAPH_PROJECT_EXT=${cap}Ext"
    $text = $text -replace '(?m)^GIT_EMAIL=.*', "GIT_EMAIL=chubajs12@${Name}.local"
    [IO.File]::WriteAllText($envLocal, $text, (New-Object Text.UTF8Encoding $false))
    Write-Host "Заполните PASS, EXTENSION_NAME, порты и базу в $envLocal" -ForegroundColor Yellow
}

$taskTpl = Join-Path $HarnessRoot 'tasks\_template'
$firstTask = Join-Path $projectRoot "tasks\$(Get-Date -Format 'yyyy-MM-dd')-podklyuchenie"
if ($WhatIf) {
    Write-Plan "copy tasks template -> $firstTask"
} elseif ((Test-Path -LiteralPath $taskTpl) -and -not (Test-Path -LiteralPath $firstTask)) {
    Copy-Item -LiteralPath $taskTpl -Destination $firstTask -Recurse -Force
}

Write-Host ''
Write-Host 'Next: dump conf/ext, graph layer (with approval), 3codeindex, MCP 1C, Vanessa.' -ForegroundColor DarkGray
if ($WhatIf) { Write-Host 'Dry-run finished.' -ForegroundColor Cyan }
