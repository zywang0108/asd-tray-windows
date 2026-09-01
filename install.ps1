# asd-tray-windows installer (prebuilt binary release)
# Idempotent: safe to re-run.

$ErrorActionPreference = 'Stop'
$ToolsDir = "$env:USERPROFILE\Tools\asdbctl"
$LegacyBin = "$ToolsDir\target\release"
$Repo     = 'zywang0108/asd-tray-windows'

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }

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

Step 'Look up latest release'
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" `
                         -Headers @{ 'User-Agent' = 'asd-tray-windows-installer' }
$asset = $rel.assets | Where-Object { $_.name -like 'asd-tray-windows-*.zip' } | Select-Object -First 1
if (-not $asset) { throw "No zip asset found in release $($rel.tag_name)" }
Write-Host "  $($rel.tag_name) -> $($asset.name) ($([math]::Round($asset.size/1KB)) KB)"

Step 'Stop running daemon (if any)'
Stop-AsdTrayProcesses $ToolsDir

Step "Download and extract to $ToolsDir"
New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
$zip = Join-Path $env:TEMP "asd-tray-windows-$([guid]::NewGuid()).zip"
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $ToolsDir -Force
Remove-Item $zip -Force

Step 'Add asdbctl to User PATH'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = @($userPath -split ';' | Where-Object { $_ })
$pathEntries = @($pathEntries | Where-Object { -not (Test-PathEntryEqual $_ $LegacyBin) })
if (-not ($pathEntries | Where-Object { Test-PathEntryEqual $_ $ToolsDir })) {
    $pathEntries += $ToolsDir
}
$newUserPath = $pathEntries -join ';'
if ($newUserPath -ne $userPath) {
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
}

Step 'Register tray daemon for autostart'
$startup = [Environment]::GetFolderPath('Startup')
$shell   = New-Object -ComObject WScript.Shell
$lnk     = $shell.CreateShortcut("$startup\ASD Brightness Tray.lnk")
$lnk.TargetPath       = "$ToolsDir\brightness.exe"
$lnk.WorkingDirectory = $ToolsDir
$lnk.Save()

# Clean up artifacts from older (source-build) installs
foreach ($old in 'brightness-ui.ps1','brightness-ui.bat','brightness-hotkeys.ahk','target','.git','Cargo.toml','Cargo.lock','src') {
    $p = Join-Path $ToolsDir $old
    if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue }
}
foreach ($oldLnk in 'ASD Brightness Hotkeys.lnk') {
    $p = "$startup\$oldLnk"
    if (Test-Path $p) { Remove-Item $p -Force }
}
$desktop = [Environment]::GetFolderPath('Desktop')
if (Test-Path "$desktop\ASD Brightness.lnk") { Remove-Item "$desktop\ASD Brightness.lnk" -Force }

Step 'Launch tray daemon now'
Start-Process -FilePath "$ToolsDir\brightness.exe"

Step 'Done'
Write-Host ""
Write-Host "Look for the brightness tray icon in the system tray (bottom-right corner)." -ForegroundColor Green
Write-Host ""
Write-Host "Try it:" -ForegroundColor Green
Write-Host "  Single-click the tray icon       - slider popup"
Write-Host "  Right-click the tray icon        - quick presets 0/25/50/75/100"
Write-Host "  Ctrl+Alt+Up / Ctrl+Alt+Down      - brightness +-5% with OSD"
Write-Host "  Ctrl+Alt+Left / Ctrl+Alt+Right   - system volume -/+1% with OSD"
Write-Host "  Ctrl+Alt+B                       - open slider popup"
Write-Host "  asdbctl get / asdbctl set 70     - CLI (open a new shell first)"
