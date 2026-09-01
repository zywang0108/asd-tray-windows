$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$ahk = Get-Content (Join-Path $repo 'brightness.ahk') -Raw

function Assert-Matches {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

$quotedCapture = "cmd ' > `"' tmp '`" 2>&1`"'"
Assert-Matches $ahk ([regex]::Escape($quotedCapture)) `
    'RunSilentCapture should quote its temporary output path.'
Assert-Matches $ahk '(?m)^\s*return RunWait\(' `
    'RunSilent should return the child process exit code.'
Assert-Matches $ahk 'RunSilent\(Format\(.+\)\) = 0 \? v : -1' `
    'SetBrightness should convert a non-zero exit code to failure.'
Assert-Matches $ahk 'echo !errorlevel!' `
    'The asynchronous slider command should persist its exit code.'
Assert-Matches $ahk 'if \(exitCode != 0\)' `
    'The slider watcher should handle a failed brightness update.'
Assert-Matches $ahk 'if \(SetBrightness\(v\) < 0\)' `
    'QuickSet should not display success after a failed update.'

$statusFile = Join-Path $env:TEMP "asd tray status $([guid]::NewGuid()).txt"
try {
    $wrapped = 'cmd /c exit 7 & > "' + $statusFile + '" echo !errorlevel!'
    & $env:ComSpec /D /V:ON /S /C $wrapped
    if (-not (Test-Path -LiteralPath $statusFile)) {
        throw 'The asynchronous status command did not create its quoted status file.'
    }
    if ((Get-Content -LiteralPath $statusFile -Raw).Trim() -ne '7') {
        throw 'The asynchronous status command did not preserve the child exit code.'
    }
} finally {
    if (Test-Path -LiteralPath $statusFile) {
        Remove-Item -LiteralPath $statusFile -Force
    }
}

Write-Host 'brightness runtime checks passed'
