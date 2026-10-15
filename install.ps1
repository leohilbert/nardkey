# Installs NardKey from dist\ for the current user (asks for admin once).
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1 [-Mode Ask|Add|Only]
#   Add  = add NardKey next to your existing layouts (switch with Win+Space)
#   Only = make NardKey the ONLY layout (removes all other input languages/layouts)
#   Ask  = prompt (default, answer defaults to Add)
param(
    [ValidateSet('Ask', 'Add', 'Only')][string]$Mode = 'Ask',
    [switch]$MachinePart
)
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
    # Same values MSKLC's installer custom action (KbdMsi.dll) writes
    Set-ItemProperty "$layouts\$key" 'Layout File' 'nardkey.dll'
    Set-ItemProperty "$layouts\$key" 'Layout Text' 'NardKey - US with German umlauts'
    Set-ItemProperty "$layouts\$key" 'Layout Display Name' '@%SystemRoot%\system32\nardkey.dll,-1000' -Type ExpandString
    Set-ItemProperty "$layouts\$key" 'Layout Locale Name' 'en-US'
    Set-ItemProperty "$layouts\$key" 'Custom Language Name' 'English (United States)'
    Set-ItemProperty "$layouts\$key" 'Custom Language Display Name' '@%SystemRoot%\system32\nardkey.dll,-1100' -Type ExpandString
    if (-not (Get-ItemProperty "$layouts\$key").'Layout Product Code') {
        Set-ItemProperty "$layouts\$key" 'Layout Product Code' ('{' + [guid]::NewGuid().ToString().ToUpper() + '}')
    }
    return
}

# --- as the user: ask, run the machine part elevated, then set up this user ---
if ($Mode -eq 'Ask') {
    Write-Host ''
    Write-Host 'Should NardKey be your ONLY keyboard layout?'
    Write-Host '  y = remove ALL other input languages and layouts; only English (US) + NardKey remains'
    Write-Host '  n = keep everything, just add NardKey (switch layouts with Win+Space)'
    $Mode = if ((Read-Host 'Only NardKey? [y/N]') -match '^\s*[yj]') { 'Only' } else { 'Add' }
}

$p = Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList `
    "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -MachinePart"
if ($p.ExitCode -ne 0) { throw "Machine part failed (exit $($p.ExitCode))" }

$key = Get-NardKeyKey
if (-not $key) { throw 'NardKey not registered - did the admin prompt get declined?' }
$tip = '0409:' + $key.ToUpper()

Add-Type -Namespace NardKey -Name Win32 -MemberDefinition @'
[DllImport("input.dll", CharSet = CharSet.Unicode)] public static extern bool InstallLayoutOrTip(string psz, uint flags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr LoadKeyboardLayout(string id, uint flags);
[DllImport("user32.dll")] public static extern bool PostMessage(System.IntPtr h, uint msg, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, System.IntPtr l);
public delegate bool EnumProc(System.IntPtr h, System.IntPtr l);
'@

if ($Mode -eq 'Only') {
    # One language (en-US) with one keyboard - other languages would drag their default
    # layouts back in. Regional format and display language are separate settings.
    $list = New-WinUserLanguageList en-US
    $list[0].InputMethodTips.Clear()
} else {
    $list = Get-WinUserLanguageList
    if (-not ($list | Where-Object LanguageTag -eq 'en-US')) { $list.Add('en-US') }
}
# Drop layouts whose registry key is gone (e.g. an older NardKey install). Windows shows them
# as "invalid" in Settings and fell back to plain US at sign-in while one was in the list.
foreach ($lang in $list) {
    foreach ($t in @($lang.InputMethodTips)) {
        if ($t -match '^[0-9A-F]{4}:([0-9A-F]{8})$' -and -not (Test-Path "$layouts\$($Matches[1])")) {
            "Removing invalid layout $t ($($lang.LanguageTag))"
            [void]$lang.InputMethodTips.Remove($t)
        }
    }
}
$en = $list | Where-Object LanguageTag -eq 'en-US'
if ($en.InputMethodTips -notcontains $tip) { $en.InputMethodTips.Add($tip) }
Set-WinUserLanguageList $list -Force -WarningAction SilentlyContinue

# Register the profile the way MSKLC's installer (KbdMsi.dll) and Settings do. With only
# Set-WinUserLanguageList the layout worked in the running session, but Windows loaded
# plain US instead at the next sign-in.
$ILOT_DEFPROFILE = 0x2
$flags = if ($Mode -eq 'Only') { $ILOT_DEFPROFILE } else { 0 }
if (-not [NardKey.Win32]::InstallLayoutOrTip($tip, $flags)) { throw "InstallLayoutOrTip($tip) failed" }
if ($Mode -eq 'Only') { Set-WinDefaultInputMethodOverride -InputTip $tip }

# Running apps keep their old layout until sign-out; switch every open window now.
$hkl = [NardKey.Win32]::LoadKeyboardLayout($key, 1)  # KLF_ACTIVATE
[NardKey.Win32]::EnumWindows({ param($h, $l) [NardKey.Win32]::PostMessage($h, 0x50, [IntPtr]::Zero, $hkl) | Out-Null; $true }, [IntPtr]::Zero) | Out-Null  # WM_INPUTLANGCHANGEREQUEST

"NardKey installed ($key, mode: $Mode) and active. Sign out/in if an app still uses the old layout."
