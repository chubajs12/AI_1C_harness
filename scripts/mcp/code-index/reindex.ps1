# Переиндексация индексатора кода после выгрузки/загрузки/крупных правок: демон в контейнере НЕ получает событий об
# изменении файлов с диска Windows (bind mount), поэтому изменения подхватываются командой bsl-indexer index — сверка по
# хешам, переразбираются только измененные файлы (ext — секунды-минуты, conf ERP — до часа).
# Признак устаревшего индекса: grep_code не находит текст, который точно есть в файле.
#   reindex.ps1                 # ext
#   reindex.ps1 -Repos ext,conf
param(
    [string[]]$Repos = @('ext'),
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '..\..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$name = $cfg['CODE_INDEX_CONTAINER']
foreach ($r in $Repos) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host "[reindex] /repos/$r ..." -ForegroundColor Cyan
    docker exec $name bsl-indexer index "/repos/$r" 2>&1 | ForEach-Object { "$_" -replace "\x1b\[[0-9;]*m", '' } |
        Select-Object -Last 8
    Write-Host ("[reindex] /repos/{0} код {1}, {2:hh\:mm\:ss}" -f $r, $LASTEXITCODE, $sw.Elapsed)
}
