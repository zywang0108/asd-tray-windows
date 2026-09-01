$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$install = Get-Content (Join-Path $repo 'install.ps1') -Raw
$uninstall = Get-Content (Join-Path $repo 'uninstall.ps1') -Raw
$setup = Get-Content (Join-Path $repo 'setup.iss') -Raw

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

Assert-True ($install -notmatch 'Get-Process\s+-Name\s+[''"]AutoHotkey64') `
    'install.ps1 must not stop every AutoHotkey64 process.'
Assert-True ($uninstall -notmatch 'Get-Process\s+-Name\s+[''"]AutoHotkey64') `
    'uninstall.ps1 must not stop every AutoHotkey64 process.'
Assert-True ($setup -notmatch 'taskkill.*AutoHotkey64\.exe') `
    'setup.iss must not stop every AutoHotkey64 process.'
Assert-True ($setup -match '(?m)^CloseApplicationsFilter=brightness\.exe\r?$') `
    'setup.iss should let Restart Manager close only the packaged executable.'
Assert-True ($install -match 'Get-CimInstance Win32_Process') `
    'install.ps1 should inspect process paths before stopping the app.'
Assert-True ($uninstall -match 'Get-CimInstance Win32_Process') `
    'uninstall.ps1 should inspect process paths before stopping the app.'

Assert-True ($install -notmatch '-notlike\s+"\*\$ToolsDir\*"') `
    'install.ps1 must not use a substring check for PATH entries.'
Assert-True ($install -match 'Test-PathEntryEqual \$_ \$LegacyBin') `
    'install.ps1 should remove the legacy target\release PATH entry.'
Assert-True ($install -match 'Test-PathEntryEqual \$_ \$ToolsDir') `
    'install.ps1 should test the new PATH entry exactly.'

$tokens = $null
$parseErrors = $null
$installAst = [System.Management.Automation.Language.Parser]::ParseFile(
    (Join-Path $repo 'install.ps1'),
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-True ($parseErrors.Count -eq 0) 'install.ps1 must parse before its helper can be tested.'
$pathHelper = $installAst.Find({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-PathEntryEqual'
}, $true)
Assert-True ($null -ne $pathHelper) 'install.ps1 should define Test-PathEntryEqual.'
Invoke-Expression $pathHelper.Extent.Text

$toolsDir = Join-Path $env:USERPROFILE 'Tools\asdbctl'
$legacyBin = Join-Path $toolsDir 'target\release'
Assert-True (Test-PathEntryEqual "$legacyBin\" $legacyBin) `
    'Legacy PATH comparison should ignore a trailing slash.'
Assert-True (-not (Test-PathEntryEqual $legacyBin $toolsDir)) `
    'Legacy target\release must not count as the new root PATH entry.'
Assert-True (Test-PathEntryEqual '%USERPROFILE%\Tools\asdbctl' $toolsDir) `
    'PATH comparison should expand environment variables.'

Write-Host 'installer safety checks passed'
