[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)] [string] $SourceRepo,
    [Parameter(Mandatory)] [string] $Target,
    [Parameter(Mandatory)] [ValidateSet('JhsCore', 'JhsOptional', 'Explicit')] [string] $Profile,
    [string[]] $Packages
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path -LiteralPath $SourceRepo).Path
$adb = Join-Path $source 'adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "Missing adb.exe in $source" }
if ((& $adb -s $Target get-state 2>$null) -ne 'device') {
    throw "ADB device $Target is not connected and authorized."
}

$core = @(
    'com.jio.tr069client',
    'com.rjil.jio.stb.commandreceiver',
    'com.jio.stbadservice',
    'com.iwedia.httpupdate',
    'com.iwedia.updateservice',
    'com.iwedia.pvodupdateservice',
    'com.iwedia.updatercuotaservice'
)

$optional = @(
    'com.jio.media.livetv',
    'com.jio.stb.bot',
    'com.jio.media.jionewsstb',
    'com.discoveryplus.tv.jiotv',
    'com.jiostb.jiogames',
    'com.jio.media.jiobeats',
    'com.jio.jiocall',
    'com.jio.web',
    'com.jio.jiocloudpc',
    'com.jiotv.sonyliv',
    'com.jio.screensaver',
    'com.jio.myhome.mediasharedmp',
    'com.jio.yt',
    'com.jio.myjiotv',
    'com.android.app.jio.voiceassist',
    'com.jio.media.jiotvplus',
    'com.jio.jiopay',
    'com.etvwin.androidtv',
    'com.hoichoi.mitv',
    'com.suntv.sunnxt',
    'com.amazon.amazonvideo.livingroom',
    'com.netflix.partnertoken',
    'com.zee5.aosp',
    'com.inn.nvengineer',
    'com.jio.dialserver'
)

$targets = switch ($Profile) {
    'JhsCore' { $core }
    'JhsOptional' { $optional }
    'Explicit' {
        if (-not $Packages) { throw '-Packages is required with -Profile Explicit.' }
        $Packages
    }
}

$installed = @(& $adb -s $Target shell pm list packages -u) | ForEach-Object { $_.Trim() }
$disabled = @(& $adb -s $Target shell pm list packages -d) | ForEach-Object { $_.Trim() }
$results = foreach ($package in $targets) {
    if ($installed -notcontains "package:$package") {
        [pscustomobject]@{ Package = $package; Result = 'not present' }
        continue
    }
    if ($disabled -contains "package:$package") {
        [pscustomobject]@{ Package = $package; Result = 'already disabled' }
        continue
    }
    if ($PSCmdlet.ShouldProcess("$Target/$package", 'Disable package for user 0')) {
        $output = @(& $adb -s $Target shell pm disable-user --user 0 $package 2>&1)
        $check = @(& $adb -s $Target shell pm list packages -d $package) | ForEach-Object { $_.Trim() }
        $status = if ($check -contains "package:$package") { 'disabled' } else { "failed: $($output -join ' ')" }
        [pscustomobject]@{ Package = $package; Result = $status }
    } else {
        [pscustomobject]@{ Package = $package; Result = 'previewed' }
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = Join-Path (Split-Path $PSScriptRoot -Parent) ".state\package-change-$stamp.json"
$results | ConvertTo-Json | Set-Content -LiteralPath $report -Encoding UTF8
$results | Format-Table -AutoSize
Write-Host "Report: $report"
Write-Host 'Re-enable a changed package with: adb -s TARGET shell pm enable PACKAGE.NAME'
