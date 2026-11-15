# Manual setup for JHS and JMS

This is the detailed human-operated procedure. No AI agent is required. Commands use **Windows PowerShell from the standalone repository root**, including commands that invoke Python, Docker, and Android's shell. Do not paste them into Git Bash. Keep this guide available locally before disconnecting WAN. Values below are examples; the scripts do not discover the correct physical box for you.

Contents: [identify and prepare](#1-identify-and-prepare), [PC services](#2-prepare-pc-services-online), [offline boots](#3-discover-the-box-during-an-offline-boot), [ADB](#5-authorize-adb-and-save-a-baseline), [launcher](#6-install-the-bundled-launcher-online), [JMS redirect](#7-jms-only-configure-the-home-redirect), [packages](#8-review-model-specific-package-changes), [verification](#9-verify-before-calling-it-complete), [cleanup](#10-restore-normal-networking), [rollback](#11-rollback), [failure decisions](#12-mistakes-and-failure-decisions).

## 1. Identify and prepare

Record model, hardware revision, and firmware from the TV. The tested paths are **JHSC200 / STB-JHSC200-11.3.46** and **JMSC200A / 25.1.9**. JMSC200Av2 is not the same model as base JMSC200A; other builds remain provisional. An earlier conversation label of 24.1.39 is not evidence that the tested JMS was running that firmware.

Install the prerequisites listed in the README: Python 3, Git, Docker Desktop with a working Linux-container engine, and Technitium DNS Server. Technitium is a separate Windows service; Compose starts GenieACS and MongoDB, **not Technitium**. The launcher also uses Docker to build; Docker is not needed on the TV or permanently on the PC afterward. No pendrive is used or formatted in this procedure. This installs apps and configuration on Jio's Android firmware; it does not replace it with certified Google TV or add Google Play certification.

Download/extract the complete standalone repository. In File Explorer, open its folder in an administrator PowerShell window. Confirm the directory contains `adb.exe`, `SKILL.md`, `scripts`, `tls`, and `launcher`. Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Get-Location
python --version
docker version
ipconfig
$PcIp = '192.168.1.5'
$StbIp = '192.168.1.128'
$Target = "${StbIp}:5555"
$Model = 'JHS' # Use JMS for the tested JMS path
```

Replace both IP values with yours. `docker version` must show a Server section, not only Client. Start Docker Desktop if it does not. Open `http://127.0.0.1:5380` and ensure the Technitium administrator login works. An unreachable page is a service problem; opening a URL does not start DNS.

Keep PC and STB on the same ordinary LAN, not isolated guest Wi-Fi. Reserve the STB address or choose an unused address outside the DHCP pool. On the TV set static IP to `$StbIp`, subnet mask to your LAN mask (example `255.255.255.0`, or prefix length `24` if requested), gateway to the router (example `192.168.1.1`), DNS 1 to `$PcIp`, and DNS 2 blank/`0.0.0.0` if accepted. Avoid a public secondary DNS that can bypass interception. Keep **PC DNS and router DNS unchanged**. Leave a Jio login screen alone; the verified JHS ADB path did not require account login. Do not infer app subscription/account access from ADB success.

Keep the PC on this adapter/address, awake, powered, and without a network-changing VPN during preparation and interception. If its Wi-Fi/address changes, stop and update the STB DNS, PC bindings, and scoped firewall configuration before retrying. Each PowerShell window has separate variables; repeat the assignments above in a new window.

## 2. Prepare PC services online

With WAN connected:

```powershell
.\scripts\prepare.ps1 -PcIp $PcIp -StbIp $StbIp -Model $Model
nslookup acs.oss.jio.com $PcIp
```

Enter Technitium credentials when prompted. Preparation backs up its listeners, configures the exact zone, creates scoped firewall rules, starts Compose, and starts the selected TLS proxy. The lookup must return the PC LAN IP. The zone is **`acs.oss.jio.com`**, with its root A record pointing to the PC; do not create a broad `jio.com` zone. Do not disable Windows Defender Firewall or manually repeat the rule creation printed by preflight: preparation already replaces those named rules.

| Service | PC port | What it proves |
| --- | --- | --- |
| Technitium DNS | UDP/TCP 53 | PC can answer the STB's DNS requests |
| Technitium administrator UI | TCP 5380 | DNS administration only |
| GenieACS UI / API | TCP 3000 / 7557 | Device inventory / task queue |
| GenieACS CWMP / file server | TCP 7547 / 7567 | Local ACS backend |
| TLS proxy | TCP 8443 and 9443 | Interception listeners; both required by readiness |
| STB ADB | STB TCP 5555 | Android debugger, opened later |

Resolve any error before proceeding. The preflight output is an inventory, not a guarantee that a port is usable. Windows excluded-port ranges must be checked for containment, not just an exact printed number. Do not kill arbitrary processes, stop ICS blindly, or delete Docker networks to free a port. See [troubleshooting](troubleshooting.md). JHS selects `forged_chain.pem`; JMS selects `acs_chain.pem`. A local DNS/proxy test does not establish that the STB trusts that certificate.

Do not rerun `start_proxy.ps1` over an existing tracked proxy. If switching models, restore the old STB's DHCP/DNS, run cleanup, and prepare the new model. Keep backups until the old setup is restored; do not overwrite them with a second box's state.

## 3. Discover the box during an offline boot

In a second PowerShell window, with the actual IP substituted:

```powershell
python .\scripts\offline_watch.py --stb-ip 192.168.1.128
```

Wait for **READY**. Then disconnect only the router WAN/uplink, leaving router power, Wi-Fi, PC, and local services running. Power off the STB, wait five seconds, and reconnect power. Do not reconnect WAN immediately after plugging in STB power: allow the offline boot/check-in first.

Watch for **NEW/UPDATED INFORM**. An initial device snapshot is historical data, not a new connection. `Local services reachable` proves only a PC-side check. If the TV reaches an offline error screen without a check-in, reconnect WAN and diagnose; do not treat the screen as success. There is no need to wait ten minutes after the relevant result. `Ctrl+C` saves the recorder report. A short dry run before reboot proves only that recording starts.

Reconnect WAN after the check-in, or after the failed boot attempt so you can diagnose online. An online AI assistant may become unreachable during WAN disconnection; follow the saved instructions locally and restore WAN before requesting analysis. Open `http://localhost:3000`, sign in to the bundled local UI (defaults `admin` / `admin`), and copy the exact device `_id` whose last-inform time just changed. Preserve private device IDs in local state, not public issues.

## 4. Queue ADB online, then deliver it offline

Back in PowerShell, WAN connected:

```powershell
python .\scripts\queue_adb.py --device-id 'EXACT-DEVICE-ID-FROM-THIS-CHECK-IN'
```

This requests only USB debugging and its validity date. HTTP acceptance/queued output is **not** a successful device write. Do not run the original `stage1.sh` afterward: it also queues downgrade/FOTA settings and applies a different installation/removal policy.

Start a new recorder. Wait for READY; disconnect WAN; cold-boot the STB again. Wait for a new check-in, both SetParameterValues responses with **status 0**, and ideally `STB TCP 5555: OPEN`. Reconnect WAN. The proxy log is `.state/pass_front.log`; the recorder prints its report location. If only an INFORM appears, inspect task responses/faults instead of repeating blind boots. Ordinary ADB, app installation, and launcher tests can now use WAN normally.

JMS-specific failures: the observed date fault was **9007**, not 9003. The bundled proxy converts `.000Z` to numeric `+00:00` on the wire. A cached true debugging value can suppress a repeated RPC even when 5555 is closed; use the narrowly scoped cache recovery in [troubleshooting](troubleshooting.md#genieacs-skips-queued-setparametervalues-tasks). Do not delete the Mongo database. ACS Connection Request failure on port 7547 is unrelated to physical-remote wake; the tested JMS needed a cold boot to initiate check-in.

## 5. Authorize ADB and save a baseline

```powershell
.\adb.exe connect $Target
.\adb.exe -s $Target get-state
.\adb.exe -s $Target shell getprop ro.product.model
.\adb.exe -s $Target shell getprop ro.build.display.id
.\adb.exe -s $Target shell getprop ro.product.cpu.abilist
.\scripts\capture_baseline.ps1 -Target $Target
```

Accept the RSA prompt on the TV if shown. `get-state` must print `device`; `unauthorized` is not ready. `10061`/actively refused means the address answered but no ADB listener accepted the connection; it does not prove authorization failure. A timeout may be wrong IP, LAN isolation, or connectivity. Always use `.\adb.exe` from this root or its absolute path. A second old ADB on PATH previously restarted the server and created misleading transport errors; do not delete keys or reset the STB to address that host-side conflict.

Check the reported model matches the selected path before changing packages. Both tested devices advertise 32-bit `armeabi-v7a` apps despite hardware names that suggest 64-bit: select the ARMv7 APK or a compatible universal APK, not ARM64/x86 by assumption. To install an optional APK you obtained:

```powershell
.\adb.exe -s $Target install -r 'C:\full\path\to\compatible.apk'
```

Baseline files under `.state` can contain identifiers and accounts. Keep them private. A baseline captured after previous changes cannot reconstruct a factory state or fully deleted apps. For a fuller read-only capture use `python .\scripts\audit_stb.py --target $Target --label jhs` (use `jms` for JMS); `--reboot` additionally reboots, so omit it until you intend that test.

### Bundled support apps: Monet backup and Shevery

The standard launcher installer in step 6 now installs both pinned APKs from `assets/apps` before installing/selecting CleanYourTV. Monet 1.1.0 is a backup launcher; Shevery 14.5.0 is an optional privileged-API management helper. Neither is selected, launched, or granted extra privileges by setup. Existing Shevery removals in historical audits remain historical facts; new setups now install it by explicit user preference.

For an existing setup, or to install these separately after your baseline without changing Home:

```powershell
.\scripts\install_support_apps.ps1 -Target $Target -WhatIf
.\scripts\install_support_apps.ps1 -Target $Target
.\adb.exe -s $Target shell pm list packages --user 0 com.klevico.monet
.\adb.exe -s $Target shell pm list packages --user 0 com.hamondev.shevery
```

Each query must print the exact expected `package:...` line. The script verifies both APK hashes before installing either, uses `install -r`, and saves prior package dumps to `.state/support-apps-last-install.json`. Keep that report privately with this device's baseline before switching boxes or rerunning it, because the last-install report is overwritten. A signature mismatch or bundled version older than the installed version may fail: stop, preserve the installed app/data, and use a compatible signed artifact rather than adding `-d` or uninstalling to force it.

Shevery is not an app store. Installing it does not start its privileged service, grant its requested permissions, or prove it can recover lost ADB. CleanYourTV and its HomeKeyService work independently of it. Enable/configure Shevery only for an actual compatible-app use case; do not copy the original repo's blanket permission/AppOps grants or ignore failed grants.

To deliberately test Monet as a backup screen, use:

```powershell
.\adb.exe -s $Target shell am start -W -n com.klevico.monet/.HomeActivity
```

Check its rendering and navigation, then start `com.gathin.tvhome/.MainActivity` again through the same `am start -W -n` command. The fallback test is optional, not an automatic primary-Home change. On JMS, the existing CleanYourTV helper can still consume Home; making Monet the persistent primary is a separate recovery operation requiring the saved helper/config rollback first. Never point Home to Monet as part of ordinary setup.

To remove an app newly added by this setup, use `adb shell pm uninstall --user 0 PACKAGE` through the bundled ADB and current target, substituting only `com.klevico.monet` or `com.hamondev.shevery`. This deletes that user's app data; do not use removal to resolve a failed update or remove a pre-existing app without intending that loss. If setup updated a pre-existing installation, uninstalling is not restoration of its earlier version/data. Do not uninstall CleanYourTV or alter the JMS helper while removing these optional apps.

## 6. Install the bundled launcher online

```powershell
.\scripts\build_install_launcher.ps1 -Target $Target
```

The script builds with tests/lint, installs the APK, grants location for SSID display, and attempts to select Home. If it reports that CleanYourTV is installed but not resolved Home, inspect the actual screen and package state: on JMS this can be the known routing policy, not a failed APK installation. Start it explicitly for the rendering test:

```powershell
.\adb.exe -s $Target shell am start -W -n com.gathin.tvhome/.MainActivity
```

Verify rendering and remote navigation before any stock-launcher change. Preserve the Docker build signing key/volume when updating an installed launcher; a signing mismatch requires using the original key, not casually uninstalling the launcher and losing configuration.

**JHS:** after a working rendering test, use:

```powershell
.\scripts\build_install_launcher.ps1 -Target $Target -SkipBuild -DisableStockLauncher
```

The observed JHS retained this disabled state after reboot and resolved CleanYourTV as Home. Do not enable the JMS helper on JHS just to make the configurations look identical.

**JMSC200A 25.1.9:** go to step 7. Its JioService restores Jio Home at startup. Disable-only, uninstall-for-user, suspend-plus-disable, and Home selection did not persist; disabling an individual protected component returned SecurityException. The original repo explicitly proposes suspension, but our test showed it cleared at reboot. Do not disable all of JioService: it also handles hardware. The helper below is a **workaround**, not removal of the firmware policy. The three updater disables in step 8 do not fix this root cause.

The customized UI provides Android Settings/Network/Bluetooth shortcuts, Native Jio settings through long-press Settings, normal animations, default-on CPU/RAM/storage statistics with a RAM/storage toggle, and expanding Wi-Fi/Bluetooth names. It remains an app launcher on Jio firmware. Installing it does not make every Android settings page, voice API, or app supported.

## 7. JMS only: configure the Home redirect

Use only after the installed launcher opens correctly. These PowerShell blocks back up and merge an existing JSON overlay, preserve other accessibility helpers, and enable the bundled HomeKeyService. Run them in order in one window. Do not reuse a backup from another box.

First capture the existing state; stop for unexpected content-provider errors:

```powershell
$ErrorActionPreference = 'Stop'
$Backup = Join-Path $PWD ('.state\jms-home-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $Backup | Out-Null
$RawConfig = ((.\adb.exe -s $Target shell content read --uri content://com.gathin.tvhome.theme/config.json 2>&1) -join "`n").Trim()
$HadConfig = $RawConfig -notmatch 'ENOENT|No such file'
if ($HadConfig) { $Config = $RawConfig | ConvertFrom-Json } else { $Config = [pscustomobject]@{} }
$Services = ((.\adb.exe -s $Target shell settings get secure enabled_accessibility_services) -join '').Trim()
$Accessibility = ((.\adb.exe -s $Target shell settings get secure accessibility_enabled) -join '').Trim()
$PackageDump = (.\adb.exe -s $Target shell dumpsys package com.gathin.tvhome) -join "`n"
$HadGrant = $PackageDump -match 'android.permission.WRITE_SECURE_SETTINGS: granted=true'
@{ target=$Target; hadConfig=$HadConfig; config=$RawConfig; services=$Services; accessibility=$Accessibility; hadGrant=$HadGrant } |
    ConvertTo-Json -Depth 30 | Set-Content -LiteralPath "$Backup\before.json" -Encoding UTF8
$Config | Add-Member -NotePropertyName stock_home_redirect -NotePropertyValue 'com.iwedia.ui.rjio.launcher.reliance' -Force
$Config | Add-Member -NotePropertyName restore_key_services -NotePropertyValue $true -Force
$Merged = $Config | ConvertTo-Json -Depth 30
[IO.File]::WriteAllText("$Backup\config.json", $Merged, [Text.UTF8Encoding]::new($false))
```

If JSON parsing fails, do not proceed or overwrite the overlay. Inspect the captured text and resolve the error. The expected absent-overlay case is ENOENT. The saved overlay must be a JSON object, not an array/null; stop if it is not. Before continuing, inspect `before.json` and confirm the services and accessibility fields are valid settings rather than ADB errors. Next push and apply the merged config; Android redirection happens inside the quoted remote shell, not in PowerShell:

```powershell
.\adb.exe -s $Target push "$Backup\config.json" /data/local/tmp/jms-home-redirect.json
if ($LASTEXITCODE) { throw 'Push failed' }
.\adb.exe -s $Target shell 'content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/jms-home-redirect.json'
if ($LASTEXITCODE) { throw 'Provider write failed' }
.\adb.exe -s $Target shell pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS
.\adb.exe -s $Target shell pm unsuspend --user 0 com.iwedia.ui.rjio.launcher.reliance
.\adb.exe -s $Target shell pm enable --user 0 com.iwedia.ui.rjio.launcher.reliance
.\adb.exe -s $Target shell am force-stop com.gathin.tvhome
.\adb.exe -s $Target shell am start -W -n com.gathin.tvhome/.MainActivity
$Helper = 'com.gathin.tvhome/.HomeKeyService'
$Existing = @($Services -split ':' | Where-Object { $_ -and $_ -ne 'null' })
$Equivalent = 'com.gathin.tvhome/com.gathin.tvhome.HomeKeyService'
if ($Helper -notin $Existing -and $Equivalent -notin $Existing) { $Existing += $Helper }
$Joined = $Existing -join ':'
.\adb.exe -s $Target shell settings put secure enabled_accessibility_services $Joined
.\adb.exe -s $Target shell settings put secure accessibility_enabled 1
.\adb.exe -s $Target shell dumpsys accessibility
.\adb.exe -s $Target shell content read --uri content://com.gathin.tvhome.theme/config.json
```

Inspect command output for permission/provider errors even when exit code is zero. Accessibility must show the Home button service **bound**, with no crashed services, and the overlay must contain both keys. If the stock launcher was previously uninstalled for user 0, first restore it with `cmd package install-existing --user 0 com.iwedia.ui.rjio.launcher.reliance` through ADB; do not uninstall it as part of this procedure.

Force-stop is used once above, before enabling/rebinding the helper. Later force-stopping CleanYourTV can remove its accessibility binding. If that happens, start CleanYourTV and re-enable its Home button accessibility service, preserving other services. Do not repeatedly force-stop it to troubleshoot a boot redirect.

After reboot Android's **resolved Home may still be Jio**, while the actual foreground automatically becomes CleanYourTV. Check both separately in step 9. A brief initial Jio screen is possible. This workaround was observed across software reboots and an owner power-cycle/Home test; extended idle remains unverified. It needs no running PC-side ACS/proxy after setup.

## 8. Review model-specific package changes

Read [package policy](package-policy.md) before applying any profile. In PowerShell choose the correct model's core list, preview, then apply only if you accept the listed functions being disabled:

```powershell
$Core = if ($Model -eq 'JHS') { 'JhsCore' } else { 'JmsCore' }
.\scripts\disable_packages.ps1 -Target $Target -Profile $Core -WhatIf
.\scripts\disable_packages.ps1 -Target $Target -Profile $Core
```

JMS core includes the HTTP updater, USB updater, and background scheduler omitted from the early standalone version; this intentionally disables their update/scheduling functions. JHS uses different updater packages. Absent packages should be reported, not replaced by guessed similar names. Disabling `com.jio.tr069client` does not prove all management traffic is gone: JHS also has `insight.tr069.client`.

Optional cleanup is a separate choice. Preview `JhsOptional` or `JmsOptional`, read every entry, and apply that profile only if desired. Keep JioStore/MyMusic, account/SSO, Settings, Bluetooth/remote services, and hardware services when required. Disabled packages are still installed and can be re-enabled; they are not removed APKs. A launcher tile can be stale or belong to a different package; identify the actual package rather than disabling by display-name guess.

For JHS lag/batched keys/failed wake, run `jhs_remote_repair.ps1 -Action Diagnose -Target $Target` and follow [the remote guide](jhs-remote-performance.md). Apply its comedia/power workaround only for the matching crash signature and when LiveTV/tuner functions are not needed. Do not copy those changes to JMS or treat stay-awake as proof of all standby paths being disabled. Preserve normal animations unless the user requests reduced motion.

Voice is a separate compatibility issue: the stock Jio capture UI can listen without delivering results to SmartTube/TizenTube. A visible microphone icon or working Bluetooth navigation does not establish an Android speech-recognition provider. Do not promise universal STT, add Play Store frameworks blindly, or keep failed voice experiments enabled.

## 9. Verify before calling it complete

Keep WAN connected. For each box, run two deliberate software reboot checks and one physical cold boot. Reconnect ADB after each. During the initial boot observation **do not launch CleanYourTV or inject Home**: that would mask whether it appears automatically. The collector provides a sampled two-minute timeline:

```powershell
python .\scripts\audit_stb.py --target $Target --label jhs --reboot
# For JMS use --label jms instead
```

The command itself performs one reboot. Repeat only for the planned second test; do not stack an extra `adb reboot` on top. During manual checks use:

```powershell
.\adb.exe connect $Target
.\adb.exe -s $Target get-state
.\adb.exe -s $Target shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME
.\adb.exe -s $Target shell dumpsys activity activities | Select-String 'mResumedActivity'
.\adb.exe -s $Target shell pm list packages -d --user 0
.\adb.exe -s $Target shell dumpsys accessibility
.\adb.exe -s $Target shell logcat -d -b crash
```

Compare package states with your own baseline/change reports, not another owner's package count. JHS should retain disabled stock Home and resolve CleanYourTV in the tested configuration. JMS may resolve Jio but must automatically foreground CleanYourTV with the helper bound. Empty crash output is a snapshot, not proof that no future crash can occur.

Then test Home from Android Settings, Network, Bluetooth pairing, Jio Native Settings, SmartTube/TizenTube if installed, Downloader if installed, JioStore, and MyMusic if retained. Test the physical remote, volume, Wi-Fi/Bluetooth names and shortcuts, stats toggle, normal animations, and your required playback/audio functions. ADB-injected keys and app launch success cannot verify physical input latency, microphone, DRM, login, or playback.

Leave it idle for the intended normal interval and test wake/Home with the real remote, including overnight if that is the intended usage. Record elapsed time and the result. The existing audit does **not** establish overnight reliability for either model. If Home fails after idle, collect foreground, helper binding, package states, crash/power logs before repairing it; distinguish helper loss from stock re-enable. Never call the JMS redirect a firmware/root-cause fix.

## 10. Restore normal networking

On the TV restore automatic IP/DHCP and automatic DNS, confirm internet works, and note the new IP from its Network screen/router leases. Reassign `$StbIp` and `$Target` before later ADB commands; `.128`, `.8`, and `.7` are historical/example addresses, not fixed device identities.

Only then run elevated:

```powershell
.\scripts\cleanup_pc.ps1 -StbDhcpRestored
```

This stops the tracked proxy/Compose, removes the named temporary firewall rules, restores saved DNS listeners, and removes the exact zone only if created by this setup. It does not roll back STB packages or the launcher. Do not run Compose `down -v`: that deletes Mongo data. Keep private rollback files. Once DHCP/DNS is restored, normal launcher operation and authorized LAN ADB do not require the interception services.

## 11. Rollback

For an ordinary disabled package use `.\adb.exe -s $Target shell pm enable --user 0 PACKAGE.NAME`, selecting only packages changed by your run. This enables the package; restore its original default/disabled state from the baseline if it was not originally enabled. Do not globally enable every package. For a suspended stock launcher unsuspend first; restore user installation with `install-existing` if an earlier attempt removed it.

For JMS redirect rollback, set `$Backup` to this box's saved directory and `$Target` to its current address. Review `before.json` before executing:

```powershell
$Before = Get-Content -LiteralPath "$Backup\before.json" -Raw | ConvertFrom-Json
if ($Before.hadConfig) {
    [IO.File]::WriteAllText("$Backup\restore.json", [string]$Before.config, [Text.UTF8Encoding]::new($false))
    .\adb.exe -s $Target push "$Backup\restore.json" /data/local/tmp/jms-home-restore.json
    .\adb.exe -s $Target shell 'content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/jms-home-restore.json'
} else {
    .\adb.exe -s $Target shell content delete --uri content://com.gathin.tvhome.theme/config.json
}
if ($Before.services -eq 'null') {
    .\adb.exe -s $Target shell settings delete secure enabled_accessibility_services
} elseif ($Before.services -eq '') {
    .\adb.exe -s $Target shell "settings put secure enabled_accessibility_services ''"
} else {
    .\adb.exe -s $Target shell settings put secure enabled_accessibility_services $Before.services
}
if ($Before.accessibility -eq 'null') {
    .\adb.exe -s $Target shell settings delete secure accessibility_enabled
} else {
    .\adb.exe -s $Target shell settings put secure accessibility_enabled $Before.accessibility
}
if (-not $Before.hadGrant) {
    .\adb.exe -s $Target shell pm revoke com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS
}
.\adb.exe -s $Target shell am force-stop com.gathin.tvhome
.\adb.exe -s $Target shell am start -W -n com.gathin.tvhome/.MainActivity
```

That restores only the overlay/helper/grant, not package changes or Home selection. If returning to stock Home on either model:

```powershell
.\adb.exe -s $Target shell pm unsuspend --user 0 com.iwedia.ui.rjio.launcher.reliance
.\adb.exe -s $Target shell pm enable --user 0 com.iwedia.ui.rjio.launcher.reliance
.\adb.exe -s $Target shell cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME
```

Copy the stock launcher's actual component from the last output, then run `cmd package set-home-activity --user 0 COMPONENT` through ADB and press Home. Do not guess the component name. Keep the replacement installed until stock navigation is verified. Use the remote-repair script's Rollback only if its original backup exists. PC cleanup and STB rollback are separate operations.

## 12. Mistakes and failure decisions

| Symptom/mistake | Interpretation and next action |
| --- | --- |
| Laptop internet fails | Restore PC/router DNS; remove accidental broad zone after reviewing its use. Do not disable the firewall. |
| READY missing 8443/9443 | Proxy listeners are absent; stale log existence is not readiness. Repair online first. |
| TLS unknown_ca | Wrong/rejected chain. Use the documented model chain; stop if it too fails. |
| No new INFORM | Check IP/DNS, client isolation, listeners, scoped rules, and boot order; a historical record proves nothing new. |
| INFORM but 5555 closed | Check actual parameter RPCs/status, date fault and cache; another INFORM is not ADB success. |
| ADB offline/server version mismatch | Use only bundled ADB, current DHCP IP, reconnect; do not reset keys/device as the first action. |
| Home works until reboot | Compare resolved Home, foreground, stock user state, helper binding. Apply the model-specific path, not another disable loop. |
| JMS updater packages disabled but Jio still restores Home | Expected distinction: updater omissions and JioService boot routing are separate issues. |
| Remote bonded but disconnected | Pairing record alone is not active HID; test a real press and recovery before resetting pairing. |
| LiveTV stops after vendor-service disable | Roll back that exact change if LiveTV is required; do not disable more TV services. |
| Mic UI listens but app gets no text | Capture and Android STT result delivery differ; revert failed experiments rather than claim universal support. |
| System partition says 100% | Read-only firmware partition fullness is not writable data storage exhaustion. Inspect `/data` separately. |
| Agent says fully verified after one launch | Require recorded reboot, physical Home/wake, and idle results; list remaining limits explicitly. |

For the detailed reconstruction and original-repo differences see [the forensic report](device-audit-2026-11-15.md). This guide records observed failures and practical decisions, not a promise that every firmware variant or hidden future behavior has been tested. Documentation commands should be reviewed against the actual box; never run the whole guide on an already configured box just to update documentation.
