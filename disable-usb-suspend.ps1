# Turns off "USB selective suspend" in the active Windows power plan (plugged in and on battery).
# Windows otherwise suspends idle USB devices during normal use; the Epomaker Galaxy100 (WB32 chip)
# sometimes misses the wake-up and stays dead or drops off until replugged.
# Usage: powershell -ExecutionPolicy Bypass -File disable-usb-suspend.ps1
$ErrorActionPreference = 'Stop'
$usb = '2a737441-1930-4402-8d77-b2bebba308a3'      # power setting group "USB settings"
$suspend = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'  # "USB selective suspend setting"

powercfg /setacvalueindex SCHEME_CURRENT $usb $suspend 0
powercfg /setdcvalueindex SCHEME_CURRENT $usb $suspend 0
powercfg /setactive SCHEME_CURRENT
if ($LASTEXITCODE -ne 0) { throw "powercfg failed (exit $LASTEXITCODE)" }
'USB selective suspend disabled for the active power plan. Switching plans later needs a re-run.'
