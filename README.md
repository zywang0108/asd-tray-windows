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

If you landed here from searching any of: *Twinkle Tray Studio Display not detected*, *Monitorian Apple display brightness*, *asdbctl Windows GUI*, *Studio Display brightness Windows 11*, *Apple Studio Display brightness slider Windows*, *Studio Display 2024 firmware brightness fix*, *Apple HID brightness control Windows*, *adjust Apple monitor brightness from Windows PC*, *Pro Display XDR brightness Windows*, *USB PID 0x1118 brightness*, this is what you want.

## Install

Run in PowerShell (no admin, no toolchain, no `winget`):

```powershell
irm https://raw.githubusercontent.com/zywang0108/asd-tray-windows/main/install.ps1 | iex
```

The script downloads the latest prebuilt zip from GitHub Releases and:

1. Extracts `asdbctl.exe` and `brightness.exe` into `~\Tools\asdbctl\`
2. Adds that directory to your User PATH so `asdbctl` works in any shell
3. Creates a Startup-folder shortcut so the tray launches at login
4. Launches the tray immediately

Total time: ~10 s. Nothing is compiled on your machine.

If you'd rather build from source (need to customize the AHK script first, or just don't trust the binary), see [Build from source](#build-from-source) below.

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

The release zip includes the source `brightness.ahk` alongside the compiled `brightness.exe` (which embeds the AHK v2 runtime). Constants worth tweaking in the .ahk file:

- `STEP := 5` step per hotkey press
- `OSD_DURATION_MS := 900` how long the centered OSD stays visible
- `POPUP_AUTOHIDE_MS := 4000` how long the slider popup stays before auto-hiding
- `^!Up` / `^!Down` / `^!b` hotkeys (`^`=Ctrl, `!`=Alt, `+`=Shift, `#`=Win)
- `TRAY_ICON_INDEX := 110` change the tray icon (any index from `imageres.dll`)

To apply edits:

1. `winget install AutoHotkey.AutoHotkey`
2. Edit `~\Tools\asdbctl\brightness.ahk`
3. Either point the Startup shortcut at `AutoHotkey64.exe brightness.ahk` instead of `brightness.exe`, or recompile with `Ahk2Exe.exe /in brightness.ahk /out brightness.exe /base AutoHotkey64.exe`
4. Kill the running daemon (`brightness.exe` or `AutoHotkey64.exe`) and re-launch via the Startup shortcut

## Build from source

If you don't want the prebuilt binary, see [`.github/workflows/release.yml`](.github/workflows/release.yml) for the exact build steps (cargo build asdbctl + Ahk2Exe brightness.ahk). The pre-binary install flow is preserved in the git history at the tag `legacy-source-install`.

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

- [`juliuszint/asdbctl`](https://github.com/juliuszint/asdbctl) the actual brightness engine. All the hard work is there.
- This repo adds: tray icon, slider popup, OSD, global hotkeys, install/uninstall automation.

### Prior art

Other Windows brightness tools that informed the design or that we tested against. None of their code is used in this repo, but they shaped what "good" looks like and why a wrapper around `asdbctl` was the right path:

- [Twinkle Tray](https://github.com/xanderfrangos/twinkle-tray) and [Monitorian](https://github.com/emoacht/Monitorian) tray-resident brightness UX reference. Both rely on DDC/CI, which Apple's HID-based protocol does not speak.
- [`sfjohnson/studio-brightness`](https://github.com/sfjohnson/studio-brightness), [`Chris-Poland/SDBC`](https://github.com/Chris-Poland/SDBC), [`LitteRabbit-37/Studio-Brightness-PlusPlus`](https://github.com/LitteRabbit-37/Studio-Brightness-PlusPlus) earlier Studio Display Windows tools. They fail on the 2024+ `0x1118` firmware (outdated PID whitelist, or LibUSB cannot claim the interface Apple's driver locks).

## License

MIT. Same as `asdbctl`.
