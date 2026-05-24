# Reverse of install.ps1. Keeps Rust/BuildTools/AHK installed.

$ErrorActionPreference = 'SilentlyContinue'
$ToolsDir = "$env:USERPROFILE\Tools\asdbctl"
$BinDir   = "$ToolsDir\target\release"

Write-Host "Stopping AHK daemon..."
Get-Process -Name 'AutoHotkey*' | Stop-Process -Force

Write-Host "Removing shortcuts..."
Remove-Item "$([Environment]::GetFolderPath('Desktop'))\ASD Brightness.lnk" -Force
Remove-Item "$([Environment]::GetFolderPath('Startup'))\ASD Brightness Hotkeys.lnk" -Force

Write-Host "Removing $ToolsDir..."
Remove-Item -Recurse -Force $ToolsDir

Write-Host "Reverting PATH..."
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = ($userPath -split ';' | Where-Object { $_ -and ($_ -ne $BinDir) }) -join ';'
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host "Done. Rust, VS Build Tools, and AutoHotkey are left installed." -ForegroundColor Green
