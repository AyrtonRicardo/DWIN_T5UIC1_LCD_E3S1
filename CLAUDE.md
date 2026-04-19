# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A Python driver for the DWIN T5UIC1 LCD (the stock Ender 3 V2 / S1 display) running under Klipper + Moonraker on a Raspberry Pi. The display communicates over UART; the rotary encoder is read via GPIO. The code is a near-direct port of the Marlin DWIN LCD firmware into Python.

## Installation / running

There are no build steps. The entry point is `run.py`, which reads config from environment variables (set by `install.sh` into `/etc/simpleLCD.env`).

```bash
# First-time install — sets up /etc/simpleLCD.env, symlinks the service, creates the /usr/local/bin/simpleLCD shim
chmod +x install.sh && ./install.sh

# Run manually (requires env vars to be loaded)
source /etc/simpleLCD.env && python3 run.py

# Service management
sudo systemctl start simpleLCD.service
journalctl -u simpleLCD.service -f
```

There are no tests, no linter config, and no type annotations.

## Environment variables (`/etc/simpleLCD.env`)

| Variable | Purpose |
|---|---|
| `INSTALL_DIR` | Absolute path to the repo (used by the systemd shim) |
| `LCD_SERIAL_PORT` | UART device, e.g. `/dev/ttyAMA0` |
| `MOONRAKER_URL` | IP/hostname of Moonraker, default `127.0.0.1` |
| `MOONRAKER_API_KEY` | Moonraker API key (may be empty) |
| `KLIPPY_SOCKET` | Absolute path to the Klipper Unix socket |
| `ENCODER_REVERSED` | `true` to swap encoder pins (Voxelab Aquila) |

## Architecture

### Module responsibilities

| File | Role |
|---|---|
| `DWIN_Screen.py` | Low-level DWIN serial protocol — wraps every display command (draw rectangle, draw string, show icon, etc.) into Python methods. Colors are RGB565 16-bit. |
| `encoder.py` | GPIO interrupt-based rotary encoder reader. Fires a callback and updates `self.value`. |
| `printerInterface.py` | Two sockets: `MoonrakerSocket` (HTTP REST via `requests`) and `KlippySocket` (Unix domain socket, async). `PrinterData` owns both and holds all printer state. |
| `dwinlcd.py` | Main application class `DWIN_LCD`. All menu logic, screen drawing, and input handling lives here. |
| `run.py` | Entry point — reads env vars, instantiates `DWIN_LCD`. |

### Input / event loop

There is no `while True` poll loop. Everything is interrupt-driven:

- **Encoder rotation / button press** → GPIO interrupt → `encoder_has_data(val)` → dispatches to the current screen's `HMI_*` handler via `self.checkkey`.
- **Periodic updates** (temperatures, print progress) → `multitimer.MultiTimer(interval=2)` → `EachMomentUpdate()`.
- **Klipper socket data** → background thread via `asyncio` event loop in `printerInterface.py`.

### Screen / state machine

`self.checkkey` is an integer constant that identifies the active screen. Setting it and calling the matching `Draw_*` method is how screen transitions work — there is no stack. Pattern for every transition:

```python
self.checkkey = self.SomeScreen   # switch state
self.select_foo.reset()           # reset cursor for new screen
self.Draw_SomeScreen()            # render
```

`select_t` is a small cursor class (`now`, `last`, `inc(max)`, `dec()`). Each menu has its own `select_*` instance.

### Menu layout constants

```
MBASE(L) = 49 + 53 * L   # pixel Y of menu row L (MLINE=53px)
STATUS_Y = 360            # menu area ends here; status bar below
DWIN_WIDTH = 272, DWIN_HEIGHT = 480
Title bar: y=0–30 (Color_Bg_Blue)
Menu area: y=31–360
Status area: y=360–480
```

- `Draw_Menu_Line(row, icon, label)` — draws icon + label + separator at `MBASE(row)`.
- `Draw_Menu_Cursor(row)` / `Erase_Menu_Cursor(row)` — highlight rectangle at `MBASE(row)`.
- `Clear_Main_Window()` — clears title bar + menu area (y=0–360).
- `Clear_Popup_Area()` — clears title bar + everything (y=0–480). Use this for full-screen custom views.

### The Info menu is a hybrid layout

The Info menu mixes hardcoded pixel positions (icons at y=99, 172, 245; spacing 73px) with the standard MBASE grid. The three static info items do **not** use `Draw_Menu_Line`. Interactive items added to this menu must use `INFO_BEDMESH_LINE = 5` (MBASE(5)=314, below the last separator at y=301) rather than their logical `select_info` index, and cursor movement must call `Erase_Menu_Cursor`/`Draw_Menu_Cursor` directly instead of `Move_Highlight`.

### Adding a new menu item (standard menus)

1. Add a `SCREEN_CASE_FOO` constant and increment `SCREEN_CASE_TOTAL`.
2. Add a `select_foo = select_t()` class variable.
3. In `Draw_Screen_Menu()`: call `Draw_Menu_Line(SCREEN_CASE_FOO, ICON_X, "Label")`.
4. In `HMI_Screen()`: handle CW/CCW with `Move_Highlight`, and ENTER for `SCREEN_CASE_FOO`.
5. Add a new `checkkey` constant and wire `encoder_has_data` → `HMI_NewScreen()`.

### Adding a new full-screen view (non-menu)

1. Add a `checkkey` constant (next integer after `Popup_Window = 34`).
2. `Draw_FooScreen()`: call `Clear_Popup_Area()`, draw title string at y=8 in `Color_Bg_Blue`, draw content from y=40 downward.
3. `HMI_Foo()`: read encoder, on ENTER restore `self.checkkey` + redraw previous screen.
4. Wire in `encoder_has_data`.

### Hardcoded URLs in `dwinlcd.py`

`PrinterStatusURL`, `PrinterOnURL`, etc. at the top of `dwinlcd.py` are placeholders (`REPLACEYOURURL`) for local power-control endpoints. These are not read from the env file and must be edited manually if used.

## Hardware: the actual display on this machine

The display installed on this Ender 3 S1 is a **TJC4827X243_011_P04** — not a DWIN T5UIC1.

| Property | Value |
|---|---|
| Manufacturer | TJC (Taojin Cai / 淘晶驰) |
| Model | TJC4827X243_011_P04 |
| Size | 4.3" |
| Resolution | 480 × 272 (same as DWIN) |
| Touch | Resistive |
| Color | 16-bit RGB565 |
| UART baud | 115200 |
| Frame header | `0xAA` (same as DWIN) |
| Frame terminator | `0xCC 0x33 0xC3 0x3C` (same as DWIN) |

### TJC vs DWIN compatibility

TJC partially emulates the DWIN binary serial protocol — header, terminator, baud rate, and the core drawing commands (`Draw_Rectangle`, `Draw_String`, `ICON_Show`, etc.) are all wire-compatible. **Basic rendering works.** Known limitations:

- **Incomplete command set**: some advanced DWIN commands cause the TJC display to crash or produce garbage. If a new command is added and the display locks up, this is the likely cause.
- **Small fonts unreliable**: `font6x12` (0x00) may not render correctly or at all; prefer `font8x16` (0x01) and larger.
- **Line/curve drawing is slower**: `Draw_Line` and circle-drawing commands execute noticeably slower than on DWIN. Avoid drawing many lines in rapid succession.
- **Icon library format differs**: the `.icl` icon library compiled for DWIN is loaded into TJC flash but icon rendering may differ for some icon IDs. If an icon looks wrong, try a neighbouring ID.
- **No Nextion/ASCII mode**: this codebase uses the binary DWIN protocol exclusively; do not add Nextion-style `0xFF 0xFF 0xFF` terminators.

### Full-screen content must stay within y=31–359

`EachMomentUpdate` redraws the status bar (y=360–480) every 2 seconds regardless of the active screen. Any custom full-screen view (e.g. bed mesh heatmap) must keep all drawn content above `STATUS_Y = 360` or it will be corrupted by the periodic status redraw.

## Commit convention

Conventional Commits (`feat:`, `fix:`, `chore:`, etc.). All commits do not include attribution.
