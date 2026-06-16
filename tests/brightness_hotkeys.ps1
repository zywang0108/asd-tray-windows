$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$ahk = Get-Content (Join-Path $repo 'brightness.ahk') -Raw
$readme = Get-Content (Join-Path $repo 'README.md') -Raw
$install = Get-Content (Join-Path $repo 'install.ps1') -Raw

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

Assert-Matches $ahk '(?m)^VOLUME_STEP := 1$' 'brightness.ahk should define VOLUME_STEP as 1.'
Assert-Matches $ahk '(?m)^\^!Right::VolumeBump\(VOLUME_STEP\)$' 'Ctrl+Alt+Right should raise system volume.'
Assert-Matches $ahk '(?m)^\^!Left::VolumeBump\(-VOLUME_STEP\)$' 'Ctrl+Alt+Left should lower system volume.'
Assert-Matches $ahk '(?m)^VolumeBump\(delta\) \{$' 'brightness.ahk should define VolumeBump(delta).'
Assert-Matches $ahk 'SoundGetVolume\(' 'VolumeBump should read current Windows volume.'
Assert-Matches $ahk 'SoundSetVolume\(newV\)' 'VolumeBump should set the clamped Windows volume.'

Assert-Matches $readme 'System volume up 1%' 'README usage should document volume up.'
Assert-Matches $readme 'System volume down 1%' 'README usage should document volume down.'
Assert-Matches $install 'Ctrl\+Alt\+Left / Ctrl\+Alt\+Right' 'Installer help should document volume hotkeys.'

Write-Host 'brightness hotkey checks passed'
