# NardKey

US keyboard layout for Windows with German umlauts on scancodes that a regular
ANSI keyboard doesn't physically have. Pair it with keyboard firmware (QMK etc.)
that sends those scancodes for a chord, and you type ä/ö/ü/ß **without any
modifier reaching the application** — so apps and games can't swallow the
shortcut (unlike AltGr/Ctrl+Alt layouts such as EurKEY), and no background
software (AutoHotkey) is needed.

| Scancode | HID usage | QMK keycode | Char | Shift |
|---|---|---|---|---|
| `0x56` | `0x64` Non-US `\|` | `KC_NUBS` | ä | Ä |
| `0x73` | `0x87` International1 | `KC_INT1` | ö | Ö |
| `0x7D` | `0x89` International3 | `KC_INT3` | ü | Ü |
| `0x7E` | `0x85` Keypad Comma | `KC_KP_COMMA` | ß | ẞ |
| `0x70` | `0x88` International2 | `KC_INT2` | € | € |

Without such firmware, AltGr + A/O/U/S/E types the same characters.
Everything else is identical to the standard US layout.

Firmware example: Epomaker Galaxy100 keymap
[`nardkey`](https://github.com/leohilbert/qmk_firmware/tree/master/keyboards/epomaker/galaxy100/keymaps/nardkey)
— left Ctrl + left Alt or right Alt + A/O/U/S → umlauts, Shift for capitals.

## Install (Windows x64)

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Asks for admin once, copies the prebuilt DLLs from `dist\` to System32/SysWOW64
and registers the layout. Then it asks whether NardKey should be your **only**
layout:

- **n** (default, `-Mode Add`): NardKey is added under English (United States),
  everything else stays. Switch with Win+Space.
- **y** (`-Mode Only`): removes **all** other input languages and layouts; only
  English (United States) + NardKey remains.

Either way it removes layouts from the list whose registry entry no longer
exists (Settings shows them as invalid). Windows silently fell back to plain US
at sign-in while such an entry was in the list.

Open apps are switched to NardKey immediately; sign out/in if one still uses the
old layout. Re-run it after rebuilding to update.

Uninstall: `powershell -ExecutionPolicy Bypass -File uninstall.ps1`

Keyboard randomly dead or dropping off until replugged? Windows suspends idle
USB devices during normal use and some keyboards (e.g. the WB32-based Galaxy100)
miss the wake-up. `disable-usb-suspend.ps1` turns USB selective suspend off in
the active power plan.

## Build

Needs Microsoft Keyboard Layout Creator 1.4 (for `kbdutool`).

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

Rebuilds `dist\amd64` and `dist\wow64` from `nardkey.klc`. Commit the result so
other machines can install without MSKLC.

`nardkey.klc` must stay UTF-16 LE — kbdutool silently produces nothing from
UTF-8. `.gitattributes` handles that on checkout.

Don't use the MSKLC GUI's "Build DLL and Setup Package": MSKLC 1.4 crashes
whenever kbdutool prints a warning, and the ü scancode `0x7D` always warns
("new scancode"). The DLL itself is fine.
