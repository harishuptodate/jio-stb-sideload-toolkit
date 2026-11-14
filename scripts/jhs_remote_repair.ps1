[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)] [string] $Target,
    [Parameter(Mandatory)] [ValidateSet('Diagnose', 'Apply', 'Rollback')] [string] $Action,
    [switch] $Reboot
)

$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$adb = Join-Path $source 'adb.exe'
if (-not (Test-Path -LiteralPath $adb)) { throw "Missing adb.exe in $source" }
if ((& $adb -s $Target get-state 2>$null) -ne 'device') {
    throw "ADB device $Target is not connected and authorized."
}

$fingerprint = ((& $adb -s $Target shell getprop ro.build.fingerprint) -join '').Trim()
$verified = $fingerprint -match '^Jio/UHDHybridSTB/franklin:11/11\.3\.46/'
$stateDir = Join-Path (Split-Path $PSScriptRoot -Parent) '.state'
$backupPath = Join-Path $stateDir 'jhs-remote-power-backup.json'
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Show-Diagnosis {
    Write-Host "Fingerprint: $fingerprint"
    Write-Host "Verified firmware: $verified"
    foreach ($package in 'com.jio.remote.btserver', 'com.iwedia.bluetoothconnectionservice', 'com.iwedia.comedia.service') {
        $disabled = & $adb -s $Target shell pm list packages -d $package
        $enabled = & $adb -s $Target shell pm list packages -e $package
        $state = if ($disabled) { 'disabled' } elseif ($enabled) { 'enabled' } else { 'not present' }
        Write-Host "$package`: $state"
    }
    Write-Host "stay_on_while_plugged_in=$(((& $adb -s $Target shell settings get global stay_on_while_plugged_in) -join '').Trim())"
    Write-Host "screen_off_timeout=$(((& $adb -s $Target shell settings get system screen_off_timeout) -join '').Trim())"
    $bluetooth = & $adb -s $Target shell dumpsys bluetooth_manager
    $bluetooth | Select-String -Pattern 'enabled:|ConnectionState:|JIO BLE Remote|appName: com.jio.remote.btserver' | Select-Object -First 15
    $logs = & $adb -s $Target shell logcat -d -t 2500
    $crashes = @($logs | Select-String -Pattern '>>> com\.iwedia\.comedia\.service <<<|Fatal signal.*comedia|libcomedias\.so' -CaseSensitive:$false)
    Write-Host "Matching comedia crash lines in recent log: $($crashes.Count)"
    & $adb -s $Target shell top -b -n 1 -m 10
}

if ($Action -eq 'Diagnose') {
    Show-Diagnosis
    exit 0
}

if (-not $verified) {
    throw 'This repair is limited to the verified JHSC200 11.3.46 fingerprint. Diagnose only on other firmware.'
}

if ($Action -eq 'Apply') {
    if (-not (Test-Path -LiteralPath $backupPath)) {
        [pscustomobject]@{
            target = $Target
            fingerprint = $fingerprint
            screen_off_timeout = ((& $adb -s $Target shell settings get system screen_off_timeout) -join '').Trim()
            stay_on_while_plugged_in = ((& $adb -s $Target shell settings get global stay_on_while_plugged_in) -join '').Trim()
            saved_at = (Get-Date).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $backupPath -Encoding UTF8
    }
    if ($PSCmdlet.ShouldProcess($Target, 'Apply verified JHS remote-performance workaround')) {
        & $adb -s $Target shell pm disable-user --user 0 com.iwedia.comedia.service
        if (& $adb -s $Target shell pm path io.gh.reisxd.tizentube.cobalt) {
            & $adb -s $Target shell am force-stop io.gh.reisxd.tizentube.cobalt
        }
        & $adb -s $Target shell settings put global stay_on_while_plugged_in 3
        & $adb -s $Target shell settings put system screen_off_timeout 2147483647
    }
}

if ($Action -eq 'Rollback') {
    if (-not (Test-Path -LiteralPath $backupPath)) {
        throw "Rollback backup not found: $backupPath"
    }
    $backup = Get-Content -LiteralPath $backupPath -Raw | ConvertFrom-Json
    if ($PSCmdlet.ShouldProcess($Target, 'Roll back JHS remote-performance workaround')) {
        & $adb -s $Target shell pm enable com.iwedia.comedia.service
        & $adb -s $Target shell settings put global stay_on_while_plugged_in $backup.stay_on_while_plugged_in
        & $adb -s $Target shell settings put system screen_off_timeout $backup.screen_off_timeout
    }
}

if ($Reboot -and $PSCmdlet.ShouldProcess($Target, 'Reboot STB')) {
    & $adb -s $Target reboot
} else {
    Write-Host 'Reboot is required for the persistent vendor-service state to settle.'
}
Write-Host "Rollback state: $backupPath"
