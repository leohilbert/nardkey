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

## Install

1. Install Microsoft Keyboard Layout Creator 1.4 (Microsoft Download Center).
2. Open `nardkey.klc` (File → Load Source File).
3. Project → Build DLL and Setup Package.
4. Run the generated `setup.exe`, then sign out/in.
5. Settings → Time & language → Language & region → English (United States) →
   Keyboards → add **NardKey - US with German umlauts**.

`nardkey.klc` must stay UTF-16 LE — MSKLC silently fails on UTF-8.
`.gitattributes` handles that on checkout.
