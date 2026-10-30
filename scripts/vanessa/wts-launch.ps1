# Запуск start-tm-tc.ps1 в уже открытой RDP-сессии пользователя VANESSA_RDP_USER, без его пароля.
# Нужны права SYSTEM/администратора (WTSQueryUserToken): вызывается задачей планировщика VANESSA_LAUNCH_TASK
# (создает register-launch-task.ps1), которую restart-vanessa.ps1 запускает через schtasks /Run.
# Сессия ищется по имени пользователя в «query user», не по номеру: номер RDP-сессии меняется (в Energy был 9, стал 3).
param([Parameter(Mandatory)][string]$EnvFile)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\kitenv.ps1')
$cfg = Get-KitEnv -EnvFile $EnvFile
$user = $cfg['VANESSA_RDP_USER']

$sid = $null
foreach ($line in @(& query.exe user 2>&1)) {
    $text = "$line"
    if ($text -match "\b$([regex]::Escape($user))\b") {
        foreach ($part in (($text -replace '^\s>', '' -replace '\s+', ' ').Trim() -split ' ')) {
            if ($part -match '^\d+$') { $sid = [uint32]$part; break }
        }
    }
    if ($sid) { break }
}
if (-not $sid) { throw "Нет RDP-сессии пользователя $user — войти по RDP (connect-rdp.ps1), окно можно свернуть/отключить" }

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class KitWtsLaunch {
  [DllImport("wtsapi32.dll", SetLastError=true)] public static extern bool WTSQueryUserToken(uint sessionId, out IntPtr phToken);
  [DllImport("advapi32.dll", SetLastError=true)] public static extern bool DuplicateTokenEx(IntPtr h, uint access, IntPtr attrs, int level, int type, out IntPtr ph);
  [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
  public static extern bool CreateProcessAsUser(IntPtr hToken, string app, string cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("userenv.dll", SetLastError=true)] public static extern bool CreateEnvironmentBlock(out IntPtr env, IntPtr hToken, bool inherit);
  [DllImport("userenv.dll", SetLastError=true)] public static extern bool DestroyEnvironmentBlock(IntPtr env);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct STARTUPINFO {
    public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
    public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
    public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
  }
  [StructLayout(LayoutKind.Sequential)]
  public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
  public static string Start(uint sessionId, string cmd, string dir) {
    IntPtr tok; if (!WTSQueryUserToken(sessionId, out tok)) return "WTSQueryUserToken err=" + Marshal.GetLastWin32Error();
    IntPtr prim; if (!DuplicateTokenEx(tok, 0x10000000, IntPtr.Zero, 2, 1, out prim)) { CloseHandle(tok); return "DuplicateTokenEx err=" + Marshal.GetLastWin32Error(); }
    IntPtr env; if (!CreateEnvironmentBlock(out env, prim, false)) { CloseHandle(prim); CloseHandle(tok); return "CreateEnvironmentBlock err=" + Marshal.GetLastWin32Error(); }
    var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(typeof(STARTUPINFO)); si.lpDesktop = "winsta0\\default";
    PROCESS_INFORMATION pi;
    bool ok = CreateProcessAsUser(prim, null, cmd, IntPtr.Zero, IntPtr.Zero, false, 0x00000400 | 0x00000010, env, dir, ref si, out pi);
    int err = Marshal.GetLastWin32Error();
    DestroyEnvironmentBlock(env); CloseHandle(prim); CloseHandle(tok);
    if (!ok) return "CreateProcessAsUser err=" + err;
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
    return "OK pid=" + pi.dwProcessId;
  }
}
"@

$start = Join-Path $PSScriptRoot 'start-tm-tc.ps1'
$log = Join-Path $cfg['VANESSA_ROOT'] 'vanessa-start.log'
$cmd = "cmd.exe /c powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$start`" -EnvFile `"$EnvFile`" > `"$log`" 2>&1"
$result = [KitWtsLaunch]::Start($sid, $cmd, (Get-KitRoot))
Write-Host "[wts] сессия $user id=$sid : $result"
if ($result -notmatch '^OK') { throw $result }
