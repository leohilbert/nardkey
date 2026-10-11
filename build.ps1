# Rebuilds dist\ from nardkey.klc. Needs Microsoft Keyboard Layout Creator 1.4 (kbdutool).
# Usage: powershell -ExecutionPolicy Bypass -File build.ps1
$ErrorActionPreference = 'Stop'

$kbdutool = "${env:ProgramFiles(x86)}\Microsoft Keyboard Layout Creator 1.4\bin\i386\kbdutool.exe"
if (-not (Test-Path $kbdutool)) { throw "kbdutool not found ($kbdutool) - install MSKLC 1.4" }

# amd64 -> System32, wow64 -> SysWOW64 (32-bit apps on 64-bit Windows)
foreach ($arch in @{ amd64 = '-m'; wow64 = '-o' }.GetEnumerator()) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "nardkey-$($arch.Key)"
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    Copy-Item "$PSScriptRoot\nardkey.klc" $tmp

    Push-Location $tmp
    try { $out = & $kbdutool -u $arch.Value nardkey.klc 2>&1 | Out-String } finally { Pop-Location }
    # kbdutool prints nothing at all for a UTF-8 .klc, so check for the success line
    if ($out -notmatch 'All tasks completed successfully') { throw "kbdutool $($arch.Key) failed:`n$out" }

    $dest = "$PSScriptRoot\dist\$($arch.Key)"
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item "$tmp\nardkey.dll" $dest -Force
    "$($arch.Key): $dest\nardkey.dll"
}
