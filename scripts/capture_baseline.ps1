[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $SourceRepo,
    [Parameter(Mandatory)] [string] $Target
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceRepo).Path
$adb = Join-Path $source 'adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "Missing adb.exe in $source" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$output = Join-Path (Split-Path $PSScriptRoot -Parent) ".state\baseline-$stamp"
New-Item -ItemType Directory -Force -Path $output | Out-Null

if ((& $adb -s $Target get-state 2>$null) -ne 'device') {
    throw "ADB device $Target is not connected and authorized."
}

& $adb -s $Target shell getprop | Set-Content (Join-Path $output 'properties.txt')
& $adb -s $Target shell pm list packages -f | Set-Content (Join-Path $output 'packages.txt')
& $adb -s $Target shell pm list packages -d | Set-Content (Join-Path $output 'disabled-packages.txt')
& $adb -s $Target shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME |
    Set-Content (Join-Path $output 'home-activity.txt')
& $adb -s $Target shell settings get global development_settings_enabled |
    Set-Content (Join-Path $output 'development-settings.txt')
& $adb -s $Target shell settings get global adb_enabled |
    Set-Content (Join-Path $output 'adb-setting.txt')

Write-Host "Baseline saved at $output"
Write-Host 'This directory may contain a device serial or private configuration. Do not publish it.'
