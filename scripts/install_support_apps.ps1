[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)] [string] $Target
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $root 'adb.exe'
$assets = Join-Path $root 'assets\apps'
$apps = Get-Content -LiteralPath (Join-Path $assets 'manifest.json') -Raw | ConvertFrom-Json

# Check every artifact before installing either app.
foreach ($app in $apps) {
    $path = Join-Path $assets $app.file
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $app.sha256) {
        throw "Bundled APK checksum mismatch: $path"
    }
}
if ((& $adb -s $Target get-state 2>$null) -ne 'device') {
    throw "ADB device $Target is not connected and authorized."
}

$stateDir = Join-Path $root '.state'
$report = [ordered]@{ target = $Target; apps = @() }
foreach ($app in $apps) {
    $path = Join-Path $assets $app.file
    if ($PSCmdlet.ShouldProcess($Target, "Install/update $($app.package); do not launch or select Home")) {
        New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
        $before = (& $adb -s $Target shell dumpsys package $app.package) -join "`n"
        & $adb -s $Target install -r $path
        if ($LASTEXITCODE -ne 0) {
            throw "Install failed for $($app.package). Do not uninstall existing app data or force a downgrade."
        }
        $installed = (& $adb -s $Target shell pm list packages --user 0 $app.package) -join "`n"
        if ($LASTEXITCODE -ne 0 -or $installed -notmatch ('(?m)^package:' + [regex]::Escape($app.package) + '\s*$')) {
            throw "Package installation could not be verified: $($app.package)"
        }
        $report.apps += @{ package = $app.package; before = $before; bundledSha256 = $app.sha256 }
        $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $stateDir 'support-apps-last-install.json') -Encoding UTF8
    }
}

Write-Host 'Support apps processed. Monet is a backup; no Home, accessibility, permission, or service-start commands were issued.'
