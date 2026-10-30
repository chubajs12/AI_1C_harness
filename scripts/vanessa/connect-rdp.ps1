# Открыть RDP-сессию пользователя VANESSA_RDP_USER на этой же машине (окна TM/TC живут в ней).
# После входа окно RDP можно свернуть или отключить (Disconnect) — сессия и окна 1С продолжают жить.
# mstsc на «localhost/127.0.0.1» не подключается — нужен псевдоним в hosts: «127.0.0.1 vanessa-rdp» (так в Energy).
# Отключенная (Disconnected) сессия годится: задача запуска находит ее по имени пользователя и стартует TM/TC в ней.
# Пароль спрашивает mstsc (или сохранен заранее: cmdkey /add:TERMSRV/vanessa-rdp /user:<ПК>\vanessa /pass:...).
param(
    [string]$ComputerName = 'vanessa-rdp',
    [string]$EnvFile = ''
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$rdp = Join-Path $env:TEMP "$($cfg['PROJECT'])-vanessa.rdp"
@(
    "full address:s:$ComputerName"
    "username:s:.\$($cfg['VANESSA_RDP_USER'])"
    'prompt for credentials:i:1'
    'screen mode id:i:1'
    'desktopwidth:i:1440'
    'desktopheight:i:900'
    'session bpp:i:32'
    'audiomode:i:2'
    'displayconnectionbar:i:1'
    'disable wallpaper:i:1'
) | Set-Content -LiteralPath $rdp -Encoding ASCII
Start-Process mstsc.exe -ArgumentList "`"$rdp`""
Write-Host "[rdp] mstsc -> $ComputerName как $($cfg['VANESSA_RDP_USER']); после входа окно можно свернуть" -ForegroundColor Cyan
