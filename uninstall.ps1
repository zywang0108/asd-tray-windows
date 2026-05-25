# Reverse of install.ps1.

$ErrorActionPreference = 'SilentlyContinue'
$ToolsDir  = "$env:USERPROFILE\Tools\asdbctl"
$LegacyBin = "$ToolsDir\target\release"

Write-Host "Stopping tray daemon..."
Get-Process -Name 'AutoHotkey64','brightness' | Stop-Process -Force

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
$newPath = ($userPath -split ';' | Where-Object { $_ -and ($_ -ne $ToolsDir) -and ($_ -ne $LegacyBin) }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host "Done." -ForegroundColor Green
