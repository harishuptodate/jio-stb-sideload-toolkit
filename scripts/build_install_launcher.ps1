[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)] [string] $Target,
    [switch] $SkipBuild,
    [switch] $DisableStockLauncher
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $root 'adb.exe'
$builder = Join-Path $root 'tools\docker-build.ps1'
$apk = Join-Path $root 'launcher\app\build\outputs\apk\release\app-release.apk'
$stateDir = Join-Path $root '.state'

if (-not (Test-Path -LiteralPath $adb)) { throw "Missing bundled adb.exe: $adb" }
if ((& $adb -s $Target get-state 2>$null) -ne 'device') {
    throw "ADB device $Target is not connected and authorized."
}

if (-not $SkipBuild) {
    if (-not (Test-Path -LiteralPath $builder)) { throw "Missing launcher builder: $builder" }
    & $builder -Project launcher -Tasks @('testReleaseUnitTest', 'lintRelease', 'assembleRelease')
    if ($LASTEXITCODE -ne 0) { throw 'CleanYourTV build failed.' }
}
if (-not (Test-Path -LiteralPath $apk)) { throw "Launcher APK is missing: $apk" }
if ((Get-Item -LiteralPath $apk).Length -ge 589824) {
    throw 'Launcher APK exceeds the CleanYourTV 576 KiB size gate.'
}

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $stateDir "launcher-before-$stamp.json"
$home = ((& $adb -s $Target shell cmd package resolve-activity --brief `
    -a android.intent.action.MAIN -c android.intent.category.HOME) -join "`n").Trim()
$stockDisabled = [bool]((& $adb -s $Target shell pm list packages -d com.iwedia.ui.rjio.launcher.reliance) -join '')
[pscustomobject]@{
    target = $Target
    home = $home
    stockLauncherDisabled = $stockDisabled
    savedAt = (Get-Date).ToString('o')
} | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8

if ($PSCmdlet.ShouldProcess($Target, 'Install CleanYourTV and select it as Home')) {
    & $adb -s $Target install -r $apk
    if ($LASTEXITCODE -ne 0) { throw 'ADB failed to install CleanYourTV.' }
    & $adb -s $Target shell am start -W -n com.gathin.tvhome/.MainActivity
    if ($LASTEXITCODE -ne 0) { throw 'CleanYourTV did not launch.' }
    if ($DisableStockLauncher) {
        & $adb -s $Target shell pm disable-user --user 0 com.iwedia.ui.rjio.launcher.reliance
        if ($LASTEXITCODE -ne 0) { throw 'Could not disable the Jio stock launcher for user 0.' }
    }
    & $adb -s $Target shell cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity
    if ($LASTEXITCODE -ne 0) { throw 'Could not set CleanYourTV as Home.' }
    & $adb -s $Target shell input keyevent HOME
}

$resolved = ((& $adb -s $Target shell cmd package resolve-activity --brief `
    -a android.intent.action.MAIN -c android.intent.category.HOME) -join "`n").Trim()
if ($resolved -notmatch 'com\.gathin\.tvhome/\.MainActivity') {
    throw "CleanYourTV is installed but is not the resolved Home: $resolved"
}

Write-Host "CleanYourTV is Home: $resolved"
Write-Host "Rollback state: $backup"
Write-Host 'Rollback: enable com.iwedia.ui.rjio.launcher.reliance, set it as Home, then press Home.'
