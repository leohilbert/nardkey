# Rebuilds dist\ from nardkey.klc. Needs Microsoft Keyboard Layout Creator 1.4 (kbdutool).
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1
$ErrorActionPreference = 'Stop'

$kbdutool = "${env:ProgramFiles(x86)}\Microsoft Keyboard Layout Creator 1.4\bin\i386\kbdutool.exe"
if (-not (Test-Path $kbdutool)) { throw "kbdutool not found ($kbdutool) - install MSKLC 1.4" }

Add-Type -Namespace NardKey -Name ImageHlp -MemberDefinition @'
[DllImport("imagehlp.dll", CharSet = CharSet.Unicode)] public static extern uint MapFileAndCheckSum(string file, out uint headerSum, out uint checkSum);
'@

# kbdutool only accepts a fixed list of VK names, and the free ones misbehave
# (Windows types "00" for VK_ICO_00, nothing for VK_SEPARATOR). So the .klc puts
# the € key (scancode 0x70) on ICO_00 and this rewrites that VK to VK_OEM_AX in
# the scancode->VK table and in the VK->char table, then fixes the PE checksum.
function Set-EuroVk($dll) {
    $b = [IO.File]::ReadAllBytes($dll)
    function Find([byte[]]$pat) {
        @(for ($i = 0; $i -le $b.Length - $pat.Length; $i++) {
            $j = 0; while ($j -lt $pat.Length -and $b[$i + $j] -eq $pat[$j]) { $j++ }
            if ($j -eq $pat.Length) { $i }
        })
    }
    $ausVK = Find ([byte[]](0xFF, 0, 0x1B, 0, 0x31, 0, 0x32, 0))   # T00 none, T01 Esc, T02 '1', T03 '2'
    $row = Find ([byte[]](0xE4, 0, 0xAC, 0x20, 0xAC, 0x20))        # {VK_ICO_00, 0, L'€', L'€'}
    if ($ausVK.Count -ne 1 -or $row.Count -ne 1) { throw "$dll`: VK patch sites found $($ausVK.Count)/$($row.Count), expected 1/1" }
    $sc = $ausVK[0] + 0x70 * 2
    if ($b[$sc] -ne 0xE4) { throw "$dll`: scancode 0x70 is VK 0x$('{0:X2}' -f $b[$sc]), expected ICO_00" }
    $b[$sc] = 0xE1; $b[$row[0]] = 0xE1                                # VK_OEM_AX
    [IO.File]::WriteAllBytes($dll, $b)
    $h = 0; $sum = 0; [void][NardKey.ImageHlp]::MapFileAndCheckSum($dll, [ref]$h, [ref]$sum)
    $pe = [BitConverter]::ToInt32($b, 0x3C)
    [Array]::Copy([BitConverter]::GetBytes($sum), 0, $b, $pe + 24 + 64, 4)  # OptionalHeader.CheckSum
    [IO.File]::WriteAllBytes($dll, $b)
}

# amd64 -> System32, wow64 -> SysWOW64 (32-bit apps on 64-bit Windows)
foreach ($arch in @{ amd64 = '-m'; wow64 = '-o' }.GetEnumerator()) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nardkey-$($arch.Key)"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    Copy-Item "$PSScriptRoot\nardkey.klc" $tmp

    Push-Location $tmp
    try { $out = & $kbdutool -u $arch.Value nardkey.klc 2>&1 | Out-String } finally { Pop-Location }
    # kbdutool prints nothing at all for a UTF-8 .klc, and still prints the success
    # line when the C compile fails (e.g. unknown VK name), so check for the DLL too
    if ($out -notmatch 'All tasks completed successfully' -or -not (Test-Path "$tmp\nardkey.dll")) { throw "kbdutool $($arch.Key) failed:`n$out" }
    Set-EuroVk "$tmp\nardkey.dll"

    $dest = "$PSScriptRoot\dist\$($arch.Key)"
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item "$tmp\nardkey.dll" $dest -Force
    "$($arch.Key): $dest\nardkey.dll"
}
