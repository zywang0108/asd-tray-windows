# asd-tray-windows installer
# Idempotent: safe to re-run.

$ErrorActionPreference = 'Stop'
$ToolsDir   = "$env:USERPROFILE\Tools\asdbctl"
$RepoUrl    = 'https://github.com/juliuszint/asdbctl'
$ScriptDir  = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function EnsureWinget {
    if (-not (Have winget)) {
        throw "winget not found. Install 'App Installer' from Microsoft Store and re-run."
    }
}

function WingetInstall($id, $extra = $null) {
    $listed = winget list --id $id --exact --disable-interactivity 2>&1 | Out-String
    if ($listed -match [regex]::Escape($id)) {
        Write-Host "  already installed: $id"
        return
    }
    $args = @('install', '--id', $id, '--exact', '--source', 'winget',
              '--disable-interactivity', '--accept-source-agreements', '--accept-package-agreements')
    if ($extra) { $args += @('--override', $extra) }
    & winget @args | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "winget install $id failed (exit $LASTEXITCODE)" }
}

Step 'Check winget'
EnsureWinget

Step 'Install Rust (rustup)'
WingetInstall 'Rustlang.Rustup'
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
if (Have rustup) { & rustup default stable | Out-Null }

Step 'Install VS Build Tools 2022 (C++ workload, ~2GB - may take a while)'
WingetInstall 'Microsoft.VisualStudio.2022.BuildTools' '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'

Step 'Install AutoHotkey v2'
WingetInstall 'AutoHotkey.AutoHotkey'

Step "Clone/update asdbctl into $ToolsDir"
if (Test-Path "$ToolsDir\.git") {
    Push-Location $ToolsDir
    git pull --ff-only | Out-Null
    Pop-Location
} else {
    New-Item -ItemType Directory -Path (Split-Path $ToolsDir) -Force | Out-Null
    git clone --depth=1 $RepoUrl $ToolsDir 2>&1 | Out-Null
}

Step 'Build asdbctl (cargo build --release)'
Push-Location $ToolsDir
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release
if ($LASTEXITCODE -ne 0) { Pop-Location; throw 'cargo build failed' }
Pop-Location

$BinDir  = "$ToolsDir\target\release"
$Asdbctl = "$BinDir\asdbctl.exe"
if (-not (Test-Path $Asdbctl)) { throw "Build did not produce $Asdbctl" }

Step "Add $BinDir to User PATH"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
}

Step 'Copy brightness.ahk daemon'
Copy-Item "$ScriptDir\brightness.ahk" "$ToolsDir\" -Force

# Clean up files from previous (pre-unified) install if present
foreach ($old in 'brightness-ui.ps1', 'brightness-ui.bat', 'brightness-hotkeys.ahk') {
    $p = "$ToolsDir\$old"
    if (Test-Path $p) { Remove-Item $p -Force }
}
$desktop = [Environment]::GetFolderPath('Desktop')
if (Test-Path "$desktop\ASD Brightness.lnk") { Remove-Item "$desktop\ASD Brightness.lnk" -Force }

Step 'Register tray daemon for autostart'
$ahkExe = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $ahkExe)) { throw "AHK exe not found at $ahkExe" }
$startup = [Environment]::GetFolderPath('Startup')
foreach ($oldLnk in 'ASD Brightness Hotkeys.lnk') {
    if (Test-Path "$startup\$oldLnk") { Remove-Item "$startup\$oldLnk" -Force }
}
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$startup\ASD Brightness Tray.lnk")
$lnk.TargetPath = $ahkExe
$lnk.Arguments  = "`"$ToolsDir\brightness.ahk`""
$lnk.WorkingDirectory = $ToolsDir
$lnk.Save()

Step 'Launch tray daemon now'
Get-Process -Name 'AutoHotkey64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $ahkExe -ArgumentList "`"$ToolsDir\brightness.ahk`""

Step 'Done'
Write-Host ""
Write-Host "Look for the brightness tray icon in the system tray (bottom-right corner)." -ForegroundColor Green
Write-Host ""
Write-Host "Try it:" -ForegroundColor Green
Write-Host "  Single-click the tray icon       - slider popup"
Write-Host "  Right-click the tray icon        - quick presets 0/25/50/75/100"
Write-Host "  Ctrl+Alt+Up / Ctrl+Alt+Down      - brightness +-5% with OSD"
Write-Host "  Ctrl+Alt+B                       - open slider popup"
Write-Host "  asdbctl get / asdbctl set 70     - CLI (open a new shell first)"
