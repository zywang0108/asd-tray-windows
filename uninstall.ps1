# Reverse of install.ps1. Keeps Rust/BuildTools/AHK installed.

$ErrorActionPreference = 'SilentlyContinue'
$ToolsDir = "$env:USERPROFILE\Tools\asdbctl"
$BinDir   = "$ToolsDir\target\release"

Write-Host "Stopping tray daemon..."
Get-Process -Name 'AutoHotkey64' | Stop-Process -Force

Write-Host "Removing shortcuts..."
$desktop = [Environment]::GetFolderPath('Desktop')
$startup = [Environment]::GetFolderPath('Startup')
foreach ($p in @(
    "$desktop\ASD Brightness.lnk",
    "$startup\ASD Brightness Tray.lnk",
    "$startup\ASD Brightness Hotkeys.lnk"
)) {
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "  removed $p" }
}

Write-Host "Removing $ToolsDir..."
Remove-Item -Recurse -Force $ToolsDir

Write-Host "Reverting PATH..."
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = ($userPath -split ';' | Where-Object { $_ -and ($_ -ne $BinDir) }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host "Done. Rust, VS Build Tools, and AutoHotkey are left installed." -ForegroundColor Green
