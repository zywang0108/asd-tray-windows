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

$BinDir = "$ToolsDir\target\release"
$Asdbctl = "$BinDir\asdbctl.exe"
if (-not (Test-Path $Asdbctl)) { throw "Build did not produce $Asdbctl" }

Step "Add $BinDir to User PATH"
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$BinDir", 'User')
}

Step 'Copy UI + hotkey scripts'
Copy-Item "$ScriptDir\brightness-ui.ps1"      "$ToolsDir\" -Force
Copy-Item "$ScriptDir\brightness-hotkeys.ahk" "$ToolsDir\" -Force

Step 'Create desktop shortcut for UI'
$shell = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$uiLnk = $shell.CreateShortcut("$desktop\ASD Brightness.lnk")
$uiLnk.TargetPath = 'powershell.exe'
$uiLnk.Arguments  = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ToolsDir\brightness-ui.ps1`""
$uiLnk.WorkingDirectory = $ToolsDir
$uiLnk.IconLocation = 'C:\Windows\System32\imageres.dll,109'
$uiLnk.Save()

Step 'Register hotkey daemon for autostart'
$ahkExe = "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $ahkExe)) { throw "AHK exe not found at $ahkExe" }
$startup = [Environment]::GetFolderPath('Startup')
$hkLnk = $shell.CreateShortcut("$startup\ASD Brightness Hotkeys.lnk")
$hkLnk.TargetPath = $ahkExe
$hkLnk.Arguments  = "`"$ToolsDir\brightness-hotkeys.ahk`""
$hkLnk.WorkingDirectory = $ToolsDir
$hkLnk.Save()

Step 'Launch hotkey daemon now'
Get-Process -Name 'AutoHotkey*' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $ahkExe -ArgumentList "`"$ToolsDir\brightness-hotkeys.ahk`""

Step 'Done'
Write-Host ""
Write-Host "Try it:" -ForegroundColor Green
Write-Host "  Ctrl+Alt+Up / Ctrl+Alt+Down  - brightness +-5%"
Write-Host "  Ctrl+Alt+B                   - open slider UI"
Write-Host "  Desktop shortcut 'ASD Brightness' - same UI"
Write-Host "  asdbctl get / asdbctl set 70 - CLI"
