# Removes NardKey for the current user and from the system (asks for admin once).
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1
param([switch]$MachinePart)
$ErrorActionPreference = 'Stop'
$layouts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'
$key = Get-ChildItem $layouts | Where-Object { (Get-ItemProperty $_.PSPath).'Layout File' -eq 'nardkey.dll' } |
    Select-Object -First 1 -ExpandProperty PSChildName

if ($MachinePart) {
    # --- elevated: layout registration + DLLs ---
    if ($key) {
        $code = (Get-ItemProperty "$layouts\$key").'Layout Product Code'
        if ($code -and (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$code")) {
            # Installed with an MSKLC setup package
            $p = Start-Process msiexec.exe -Wait -PassThru -ArgumentList "/x $code /qn /norestart"
            if ($p.ExitCode -notin 0, 3010) { throw "msiexec /x failed (exit $($p.ExitCode))" }
        }
        Remove-Item "$layouts\$key" -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach ($dir in "$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64") {
        Get-ChildItem $dir -Filter 'nardkey.dll*' | ForEach-Object {
            # Loaded by running apps -> locked; a renamed copy is cleaned up by the next install
            try { Remove-Item $_.FullName -Force } catch { Rename-Item $_.FullName ("nardkey.dll.{0:yyyyMMddHHmmss}.old" -f (Get-Date)) }
        }
    }
    return
}

# --- as the user: take NardKey out of the language list, then run the machine part elevated ---
if ($key) {
    $tip = '0409:' + $key.ToUpper()
    $list = Get-WinUserLanguageList
    foreach ($lang in $list) { [void]$lang.InputMethodTips.Remove($tip) }
    $en = $list | Where-Object LanguageTag -eq 'en-US'
    if ($en -and $en.InputMethodTips.Count -eq 0) { $en.InputMethodTips.Add('0409:00000409') }  # plain US
    Set-WinUserLanguageList $list -Force -WarningAction SilentlyContinue
    if ((Get-WinDefaultInputMethodOverride).InputMethodTip -eq $tip) {
        Remove-ItemProperty 'HKCU:\Control Panel\International\User Profile' InputMethodOverride  # no Clear- cmdlet
    }
}

$p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList `
    "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -MachinePart"
if ($p.ExitCode -ne 0) { throw "Machine part failed (exit $($p.ExitCode))" }
'NardKey removed. Sign out/in so running apps drop it.'
