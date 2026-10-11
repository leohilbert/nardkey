# Installs NardKey from dist\ and makes it the only input method of the current user.
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1   (asks for admin once)
# Same result as MSKLC's setup.exe, plus switching the user over.
param([switch]$MachinePart)
$ErrorActionPreference = 'Stop'
$layouts = 'HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts'

function Get-NardKeyKey {
    Get-ChildItem $layouts | Where-Object { (Get-ItemProperty $_.PSPath).'Layout File' -eq 'nardkey.dll' } |
        Select-Object -First 1 -ExpandProperty PSChildName
}

function Install-Dll($src, $dir) {
    $dst = Join-Path $dir 'nardkey.dll'
    try {
        Copy-Item $src $dst -Force
    } catch {
        # Loaded by running apps -> locked. Renaming a loaded DLL is allowed; old copy goes away on next reinstall.
        Rename-Item $dst ("nardkey.dll.{0:yyyyMMddHHmmss}.old" -f (Get-Date))
        Copy-Item $src $dst
    }
    Get-ChildItem $dir -Filter 'nardkey.dll.*.old' | Remove-Item -ErrorAction SilentlyContinue
}

if ($MachinePart) {
    # --- elevated: DLLs + layout registration ---
    Install-Dll "$PSScriptRoot\dist\amd64\nardkey.dll" "$env:SystemRoot\System32"
    Install-Dll "$PSScriptRoot\dist\wow64\nardkey.dll" "$env:SystemRoot\SysWOW64"

    $key = Get-NardKeyKey
    if (-not $key) {
        $all = Get-ChildItem $layouts | ForEach-Object { Get-ItemProperty $_.PSPath }
        $names = $all | ForEach-Object { $_.PSChildName.ToLower() }
        $ids = $all | Where-Object { $_.'Layout Id' } | ForEach-Object { [Convert]::ToInt32($_.'Layout Id', 16) }
        $key = 0..4095 | ForEach-Object { 'a{0:x3}0409' -f $_ } | Where-Object { $names -notcontains $_ } | Select-Object -First 1
        $id = 0xc0; while ($ids -contains $id) { $id++ }
        New-Item "$layouts\$key" | Out-Null
        Set-ItemProperty "$layouts\$key" 'Layout Id' ('{0:x4}' -f $id)
    }
    Set-ItemProperty "$layouts\$key" 'Layout File' 'nardkey.dll'
    Set-ItemProperty "$layouts\$key" 'Layout Text' 'NardKey - US with German umlauts'
    Set-ItemProperty "$layouts\$key" 'Layout Display Name' '@%SystemRoot%\system32\nardkey.dll,-1000' -Type ExpandString
    return
}

# --- as the user: run the machine part elevated, then switch this user over ---
$p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList `
    "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -MachinePart"
if ($p.ExitCode -ne 0) { throw "Machine part failed (exit $($p.ExitCode))" }

$key = Get-NardKeyKey
if (-not $key) { throw 'NardKey not registered - did the admin prompt get declined?' }
$tip = '0409:' + $key.ToUpper()

# Only NardKey: one language (en-US) with one keyboard. Other languages would drag their
# default layouts back in. Regional format and display language are separate settings.
$list = New-WinUserLanguageList en-US
$list[0].InputMethodTips.Clear()
$list[0].InputMethodTips.Add($tip)
Set-WinUserLanguageList $list -Force -WarningAction SilentlyContinue
Set-WinDefaultInputMethodOverride -InputTip $tip

# Running apps keep their old layout until sign-out; switch every open window now.
Add-Type -Namespace NardKey -Name Win32 -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr LoadKeyboardLayout(string id, uint flags);
[DllImport("user32.dll")] public static extern bool PostMessage(System.IntPtr h, uint msg, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, System.IntPtr l);
public delegate bool EnumProc(System.IntPtr h, System.IntPtr l);
'@
$hkl = [NardKey.Win32]::LoadKeyboardLayout($key, 1)  # KLF_ACTIVATE
[NardKey.Win32]::EnumWindows({ param($h, $l) [NardKey.Win32]::PostMessage($h, 0x50, [IntPtr]::Zero, $hkl) | Out-Null; $true }, [IntPtr]::Zero) | Out-Null  # WM_INPUTLANGCHANGEREQUEST

"NardKey installed ($key) and active. Sign out/in if an app still uses the old layout."
