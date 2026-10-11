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

Everything else is identical to the standard US layout.

Firmware example: Epomaker Galaxy100 keymap
[`nardkey`](https://github.com/leohilbert/qmk_firmware/tree/master/keyboards/epomaker/galaxy100/keymaps/nardkey)
— left Ctrl + left Alt or right Alt + A/O/U/S → umlauts, Shift for capitals.

## Install (Windows x64)

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

Asks for admin once, copies the prebuilt DLLs from `dist\` to System32/SysWOW64,
registers the layout and makes **NardKey the only input method** of the current
user (language list = English (United States) with NardKey). Open apps are
switched over immediately; sign out/in if one still uses the old layout.
Re-run it after rebuilding to update.

## Build

Needs Microsoft Keyboard Layout Creator 1.4 (for `kbdutool`).

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

Rebuilds `dist\amd64` and `dist\wow64` from `nardkey.klc`. Commit the result so
other machines can install without MSKLC.

`nardkey.klc` must stay UTF-16 LE — kbdutool silently produces nothing from
UTF-8. `.gitattributes` handles that on checkout.
