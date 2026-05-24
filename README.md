# asd-tray-windows

Brightness control for **Apple Studio Display** on **Windows**, including the newer firmware (USB PID `0x1118`) that breaks every other open-source tool.

A thin GUI + global hotkey wrapper around [`juliuszint/asdbctl`](https://github.com/juliuszint/asdbctl). Zero driver replacement, no Zadig, no admin once installed.

## Why this exists

If you bought a Studio Display in 2024+, Apple shipped it with a new firmware exposing USB PID `0x1118`. Every popular Windows brightness tool fails on it:

| Tool | Result |
|------|--------|
| Twinkle Tray | "No compatible display found" (no DDC/CI support) |
| Monitorian | Same |
| sfjohnson/studio-brightness | PID whitelist outdated |
| Chris-Poland/SDBC | LibUSB cannot claim interface (driver locked by Apple) |
| LitteRabbit-37/Studio-Brightness-PlusPlus | Same outdated PID whitelist |

The fix is trivial: `juliuszint/asdbctl` upstream already added `0x1118` to its PID list, but no one shipped a Windows GUI build of it. This repo is that build, plus a tiny WinForms slider UI and AutoHotkey global hotkeys.

## Install

Run in PowerShell (no admin needed for most steps; the script will prompt UAC twice for Build Tools and the WinTun-equivalent steps if absent):

```powershell
irm https://raw.githubusercontent.com/<YOUR_GITHUB>/asd-tray-windows/main/install.ps1 | iex
```

Or clone and run:

```powershell
git clone https://github.com/<YOUR_GITHUB>/asd-tray-windows
cd asd-tray-windows
.\install.ps1
```

The script:
1. Installs Rust, VS Build Tools 2022 (C++ workload), AutoHotkey v2 via `winget` (skips if present)
2. Clones `juliuszint/asdbctl` and runs `cargo build --release`
3. Copies the UI script and AHK hotkey script
4. Creates a desktop shortcut and a Startup-folder entry for the hotkey daemon

Total time: ~5 min on a fast connection (most of it is Build Tools download).

## Usage

| Action | How |
|--------|-----|
| Open slider UI | Desktop shortcut **ASD Brightness**, or hotkey `Ctrl+Alt+B` |
| Brightness up 5% | `Ctrl+Alt+↑` |
| Brightness down 5% | `Ctrl+Alt+↓` |
| CLI | `asdbctl get` / `asdbctl set 70` / `asdbctl up -s 10` |

After install, `asdbctl.exe` is on your User PATH.

## Customize

Edit `C:\Users\<You>\Tools\asdbctl\brightness-hotkeys.ahk`:

- `StepSize := 5` — change step per hotkey press
- `^!Up` / `^!Down` / `^!b` — change hotkeys (`^`=Ctrl, `!`=Alt, `+`=Shift, `#`=Win)

Then kill `AutoHotkey64.exe` and re-run the AHK script (or log out and back in).

## Uninstall

```powershell
.\uninstall.ps1
```

Removes the AHK daemon, shortcuts, the `Tools\asdbctl` directory, and reverts PATH. Leaves Rust / Build Tools / AHK installed (you may want them for other things).

## Supported hardware

- Apple Studio Display, PID `0x1114` (2022 model) — works
- Apple Studio Display, PID `0x1118` (2024+ firmware) — works, **this is the reason this repo exists**
- Apple Pro Display XDR, PID `0x1116` — should work, untested

VID is always `0x05ac`.

## Credits

- [`juliuszint/asdbctl`](https://github.com/juliuszint/asdbctl) — the actual brightness engine. All the hard work is there.
- This repo only adds: PowerShell WinForms UI, AutoHotkey hotkey daemon, install/uninstall automation.

## License

MIT. Same as `asdbctl`.
