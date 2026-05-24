# asd-tray-windows

Tray-resident brightness control for **Apple Studio Display** on **Windows**, including the newer firmware (USB PID `0x1118`) that breaks every other open-source tool.

A single AutoHotkey daemon wrapping [`juliuszint/asdbctl`](https://github.com/juliuszint/asdbctl). Zero driver replacement, no Zadig, no admin once installed.

## Why this exists

If you bought a Studio Display in 2024+, Apple shipped it with a new firmware exposing USB PID `0x1118`. Every popular Windows brightness tool fails on it:

| Tool | Result |
|------|--------|
| Twinkle Tray | "No compatible display found" (does not speak Apple's USB protocol) |
| Monitorian | Same |
| sfjohnson/studio-brightness | PID whitelist outdated |
| Chris-Poland/SDBC | LibUSB cannot claim interface (Apple driver locks it) |
| LitteRabbit-37/Studio-Brightness-PlusPlus | Same outdated PID whitelist |

The fix is trivial: `juliuszint/asdbctl` upstream already added `0x1118` to its PID list, but no one shipped a Windows GUI build of it. This repo is that build, plus a tray daemon for native-feeling brightness control.

## Install

Run in PowerShell (no admin needed for daily use; you may get one UAC prompt for VS Build Tools if it's not already installed):

```powershell
irm https://raw.githubusercontent.com/zywang0108/asd-tray-windows/main/install.ps1 | iex
```

Or clone and run:

```powershell
git clone https://github.com/zywang0108/asd-tray-windows
cd asd-tray-windows
.\install.ps1
```

The script:
1. Installs Rust, VS Build Tools 2022 (C++ workload), AutoHotkey v2 via `winget` (skips if present)
2. Clones `juliuszint/asdbctl` and runs `cargo build --release`
3. Copies the tray daemon (`brightness.ahk`) into `~\Tools\asdbctl\`
4. Adds the asdbctl directory to your User PATH
5. Creates a Startup-folder shortcut so the tray daemon launches at login
6. Launches the daemon immediately

Total time: ~5 min on a fast connection (most of it is Build Tools download).

## Usage

After install, look for the brightness icon in the system tray (bottom-right corner — may be hidden behind the small arrow).

| Action | How |
|--------|-----|
| Open slider popup | Single-click the tray icon, or hotkey `Ctrl+Alt+B` |
| Brightness up 5% | `Ctrl+Alt+↑` (OSD shows new value) |
| Brightness down 5% | `Ctrl+Alt+↓` |
| Wheel adjust | Hover the popup → mouse wheel ±5% |
| Quick presets | Right-click tray icon → pick 0/25/50/75/100 |
| Auto-close popup | Click elsewhere, or wait ~4s |
| CLI | `asdbctl get` / `asdbctl set 70` / `asdbctl up -s 10` |

Popup is anchored above the taskbar in the bottom-right, like the Windows audio flyout.

## Customize

Edit `C:\Users\<You>\Tools\asdbctl\brightness.ahk`:

- `STEP := 5` — step per hotkey press
- `OSD_DURATION_MS := 900` — how long the centered OSD stays visible
- `POPUP_AUTOHIDE_MS := 4000` — how long the slider popup stays before auto-hiding
- `^!Up` / `^!Down` / `^!b` — hotkeys (`^`=Ctrl, `!`=Alt, `+`=Shift, `#`=Win)
- `TRAY_ICON_INDEX := 110` — change the tray icon (any index from `imageres.dll`)

Then kill `AutoHotkey64.exe` and re-launch via the Startup folder shortcut (or log out and back in).

## Uninstall

```powershell
.\uninstall.ps1
```

Removes the tray daemon, shortcuts, the `Tools\asdbctl` directory, and the PATH entry. Leaves Rust / Build Tools / AutoHotkey installed (you may want them for other things).

## Supported hardware

- Apple Studio Display, PID `0x1114` (2022 model) — works
- Apple Studio Display, PID `0x1118` (2024+ firmware) — works, **this is the reason this repo exists**
- Apple Pro Display XDR, PID `0x1116` — should work, untested

VID is always `0x05ac`.

## Architecture

```
brightness.ahk (AutoHotkey v2)
   |  reads/writes  ↓
asdbctl.exe (Rust, built from juliuszint/asdbctl)
   |  HID feature reports  ↓
Apple Studio Display (USB HID, vendor 0x05ac)
```

One daemon process. asdbctl is invoked per action via `cmd /S /C` with a temp-file capture for the `get` reply.

## Credits

- [`juliuszint/asdbctl`](https://github.com/juliuszint/asdbctl) — the actual brightness engine. All the hard work is there.
- This repo adds: tray icon, slider popup, OSD, global hotkeys, install/uninstall automation.

## License

MIT. Same as `asdbctl`.
