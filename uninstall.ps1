# Reverse of install.ps1.

$ErrorActionPreference = 'SilentlyContinue'
$ToolsDir  = "$env:USERPROFILE\Tools\asdbctl"
$LegacyBin = "$ToolsDir\target\release"

function Test-PathEntryEqual($Left, $Right) {
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }
    $trimChars = [char[]]@('\', '/')
    $normalizedLeft = [Environment]::ExpandEnvironmentVariables($Left.Trim()).TrimEnd($trimChars)
    $normalizedRight = [Environment]::ExpandEnvironmentVariables($Right.Trim()).TrimEnd($trimChars)
    return [string]::Equals($normalizedLeft, $normalizedRight, [StringComparison]::OrdinalIgnoreCase)
}

function Stop-AsdTrayProcesses($InstallDir) {
    $exePath = [IO.Path]::GetFullPath((Join-Path $InstallDir 'brightness.exe'))
    $scriptPath = [IO.Path]::GetFullPath((Join-Path $InstallDir 'brightness.ahk'))
    Get-CimInstance Win32_Process -Filter "Name = 'brightness.exe' OR Name = 'AutoHotkey64.exe'" `
        -ErrorAction SilentlyContinue |
        Where-Object {
            ($_.Name -ieq 'brightness.exe' -and $_.ExecutablePath -and
                [string]::Equals([IO.Path]::GetFullPath($_.ExecutablePath), $exePath, [StringComparison]::OrdinalIgnoreCase)) -or
            ($_.Name -ieq 'AutoHotkey64.exe' -and $_.CommandLine -and
                $_.CommandLine.IndexOf($scriptPath, [StringComparison]::OrdinalIgnoreCase) -ge 0)
        } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

Write-Host "Stopping tray daemon..."
Stop-AsdTrayProcesses $ToolsDir

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
$newPath = ($userPath -split ';' | Where-Object {
    $_ -and -not (Test-PathEntryEqual $_ $ToolsDir) -and -not (Test-PathEntryEqual $_ $LegacyBin)
}) -join ';'
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

Write-Host "Done." -ForegroundColor Green
