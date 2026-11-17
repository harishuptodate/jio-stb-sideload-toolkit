# JMS family: tested setup with model-specific persistence limits

For sequential, copyable PowerShell setup, configuration merge, helper preservation, verification, and rollback, use the [complete manual](manual-setup.md). This reference explains the model-specific evidence.

## Working Home redirect on JMSC200A 25.1.9

Use this path when disable/uninstall/suspend is reset at boot. Inspection of this box's `JioService.apk` found `JioServiceExtendedImpl.initialSetup()` calling `checkAndActivateLauncherIfNeeded()`, which enables the stock launcher for a home product. Do not disable the whole JioService: it also handles hardware functions.

The bundled CleanYourTV already provides `HomeKeyService` for exactly this situation. The normal JMS setup now merges all three keys below after rendering succeeds, rather than waiting for a rapid-Home flash report. The original 25.1.9 redirect used the first two keys; direct Home-key handling was additionally verified on the separate 24.1.39 box as described below. Preserve those evidence limits when validating another firmware:

```json
{"stock_home_redirect":"com.iwedia.ui.rjio.launcher.reliance","restore_key_services":true,"home_long_press_home":true}
```

Before applying, back up an existing theme with `content read --uri content://com.gathin.tvhome.theme/config.json`, the enabled accessibility-service list, accessibility switch, and WRITE_SECURE_SETTINGS grant. Merge these keys into an existing config rather than replacing its other keys. A missing config reports ENOENT; other read failures must be resolved first. Save the JSON locally, push it to `/data/local/tmp/jms-home-redirect.json`, and apply:

```powershell
.\adb.exe -s TARGET shell 'content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/jms-home-redirect.json'
.\adb.exe -s TARGET shell pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS
.\adb.exe -s TARGET shell am force-stop com.gathin.tvhome
.\adb.exe -s TARGET shell am start -W -n com.gathin.tvhome/.MainActivity
```

Then append `com.gathin.tvhome/.HomeKeyService` to `settings secure enabled_accessibility_services` without removing existing services, and set `accessibility_enabled=1`. The tested box had an empty list. Leave the stock launcher enabled for this fallback. Confirm `dumpsys accessibility` shows the Home button helper bound, with no crashed service. Test actual foreground activity after boot before injecting Home or launching CleanYourTV; then test Home from another app.

`home_long_press_home=true` consumes Home and opens CleanYourTV on release instead of letting the firmware open Jio first. Holding Home also opens CleanYourTV rather than the vendor's long-press action. Include this key in the JMS device overlay by default; do not enable it globally for JHS. Read back all three keys and the helper binding after reboot, then physically test short Home, 10–20 rapid presses, held Home, D-pad and volume, including after a cold boot. Injected keys cannot establish physical no-flash behavior. Back up and merge before applying, as in the manual; restore that box's saved overlay/helper state if the new behavior fails.

This is a foreground/Home redirect, not a permanent change to the firmware's resolved Home. Jio's initial logo or screen may appear briefly before Android binds the helper. A PC, ACS, and Docker are not required after configuration. Two ADB reboots passed. On 2026-11-15 the owner also confirmed that unplugging/reconnecting power booted into CleanYourTV and the physical Home button stayed in CleanYourTV. Extended idle behavior remains unverified.

Rollback: restore the previous config through the provider (or delete only `config.json` if none existed), restore the previous enabled-service list and accessibility switch, and restart CleanYourTV. Revoke WRITE_SECURE_SETTINGS only if it was newly granted for this workaround. Keep JioService enabled.

## Persistence regression observed 2026-11-15

### Separate JMSC200Av2 / 24.1.39 investigation

A fresh box labelled **JMSC200Av2** reports Android model `JMSC200A` and build `JioSTB-JMSC200A-24.1.39`. Its own baseline and rollback are separate from the earlier 25.1.9 box. On this firmware, disabling the stock launcher and selecting CleanYourTV worked in the current session, but a software reboot restored stock Home to `enabled=1` and Jio Home resolution. CleanYourTV remained foreground through the existing accessibility redirect. This is a test on the new box, not an inference from 25.1.9.

Inspection of this box's distinct JioService APK confirms the same direct enabling path: `init()` queues `INITIAL_SETUP`; `initialSetup()` calls `checkAndActivateLauncherIfNeeded()`; a non-Hospitality `persist.sys.jio.product.type` causes `setApplicationEnabledSetting(stockLauncher, 1, 0)`. Do not change product type to evade this: it also selects provisioning, CEC/sleep, and surveillance behavior. Disabling only the stock Home activity was rejected by Android; hiding the package was denied for missing `MANAGE_USERS`; a suspend-only request left it unsuspended.

Rapid physical Home presses exposed a brief Jio screen with the original redirect. The helper normally passes Home through and schedules its own launch 250 ms later. The existing overlay option `"home_long_press_home": true` instead consumes Home and opens CleanYourTV on release, including held presses. It was enabled with a separate overlay/accessibility backup and helper rebind. The owner explicitly confirmed no Jio flash during rapid physical Home presses afterward. Two subsequent software reboot audits retained this option, recovered authorized ADB, automatically foregrounded CleanYourTV, and showed the helper bound with no crashed services and empty crash-buffer snapshots. Disabled-package membership stayed unchanged. The owner later confirmed the requested physical cold boot, rapid Home and volume checks were good. These audits are separate from the prior disable test and the earlier box's evidence. Injected keys do not establish physical interception. This option changes held Home to CleanYourTV and does not remove firmware Home policy or guarantee a Jio-free boot screen. Explicit held-Home behavior and extended idle remain separate acceptance checks.

### Earlier 25.1.9 observations

On the previously configured JMSC200A (25.1.9), the stock launcher reclaimed Home after extended use. Reboot testing reproduced restoration of `com.iwedia.ui.rjio.launcher.reliance` after both `pm disable-user --user 0` and `pm uninstall -k --user 0`. Direct disabling of its `IntroActivity` is rejected with `SecurityException`. Selecting CleanYourTV as Home works for the current session only. That disable-only method is not a persistence fix. The later investigation identified the enabling mechanism and verified the redirect above across reboot; the firmware policy remains in place.

ADB and Bluetooth recovered after reboot, existing optional package disables remained, and Android TV Network and accessory activities opened successfully. `stay_on_while_plugged_in=3` persisted; `screen_off_timeout` returned to `900000`. JHS standby and launcher persistence behavior cannot be assumed on JMS. Local evidence and the pre-change baseline are retained under ignored `.state`.

The original `stage1.sh` suspension workaround was also tested: `pm suspend --user 0` followed by `pm disable-user --user 0` and selecting CleanYourTV. Before reboot the stock launcher reported `suspended=true` and `enabled=3`; after reboot it reported `suspended=false` and `enabled=1`, and Jio IntroActivity reclaimed Home. Suspension is therefore not a verified persistence fix on this box. Boot evidence is saved locally in `.state/jms-suspension-reset-boot.log`. If restoring Jio Home after a session workaround, run `pm unsuspend --user 0 com.iwedia.ui.rjio.launcher.reliance` before enabling it.

Stock-launcher recovery if needed: `adb -s TARGET shell cmd package install-existing --user 0 com.iwedia.ui.rjio.launcher.reliance`, followed by `pm enable` and selecting its Home activity.

The first successful session used JHSC200 v1 even though a JMSC model was initially discussed. Later local testing established the JMSC200A 25.1.9 ADB path and the Home redirect documented above. The original disable-only Home approach failed subsequent reboot tests; extended idle acceptance remains outstanding. See the [detailed comparison audit](device-audit-2026-11-15.md).

Upstream reports JMSC200Av2 support on firmware `22.1.09`, `24.1.39`, and `25.1.9`. That does not establish support for base `JMSC200A`, a different hardware revision, or a later firmware.

## Rules for the first validation

1. Record the exact model, hardware revision, and firmware before changing anything.
2. Capture a clean baseline and keep package changes out of the certificate/ADB validation phase.
3. Start with the bundled JMS/default chain:

```powershell
.\scripts\start_proxy.ps1 -Model JMS
```

4. Run the recorder and follow the [manual timing rule](manual-setup.md#offline-timing-rule-for-both-models): after READY remove WAN, wait about 30 seconds, power off for five seconds, then keep WAN off for at least four minutes after power-on and until boot settles before reconnecting. Repeat this timing for task delivery; elapsed time alone is not proof of success.
5. Stop on `unknown_ca`. Do not switch to the JHS/eMudhra chain as a guess.
6. Record the ACS path, TLS error or accepted chain, GenieACS device identity format, task response, and TCP 5555 behavior.
7. Queue only the two ADB parameters using `queue_adb.py` after the device really checks in.
8. Do not run a JHS package profile on JMS. Enumerate packages and resolve the launcher component first.

## Evidence required before marking a firmware verified

- proxy log shows a real STB TLS connection and CWMP request;
- GenieACS shows a new device with a matching check-in time;
- both ADB settings receive status `0`;
- TCP 5555 opens after cold boot;
- ADB authorizes and reconnects after another reboot;
- stock launcher rollback, remote, Wi-Fi, Settings, and retained apps are tested;
- exact cleanup and DNS restoration are tested.

Update this reference with observed facts, including failures. Do not generalize one JMS hardware revision to the whole family.

## Observed facts on the tested JMSC200A

1. **Certificate Chain**: Uses `acs_chain.pem` (RIL Root CA) on `https://acs.oss.jio.com:9443/ftacs-digest/ACS`.
2. **CWMP Date Strictness**: Rejects ISO 8601 UTC `.000Z` date format with SOAP Fault 9007. Requires `YYYY-MM-DDTHH:MM:SS+00:00`. `tls/pass_front.py` dynamically normalizes this.
3. **GenieACS Declarative Cache**: If `Device.JioSTB.USB.USBDebugging` is cached as `true` in MongoDB while ADB is not actually listening, GenieACS will not send the command over the wire. After verifying this exact cache/RPC failure, export the record and unset only that cached parameter before requeuing; see [troubleshooting](troubleshooting.md#genieacs-skips-queued-setparametervalues-tasks).
4. **ACS Connection Request unavailable** (not remote-control wake): Connection Request on port 7547 actively resets TCP (`RST`). Trigger check-ins via cold boot (unplug power 5s, reconnect) during the WAN-off window.

## Initial setup observations on JMSC200A (Firmware 25.1.9)

Initial enablement and launcher observations on **JMSC200A**, running firmware `JioSTB-JMSC200A-25.1.9` (`Jio/4KOTTSTB/MSTB:11/25.1.9/8:user/release-keys`), are retained below as history. The disable-only launcher result in item 4 did not survive later reboot testing; use the redirect at the top of this reference for the tested workaround:

1. **Certificate Chain**: `acs_chain.pem` (Reliance RIL Root CA) accepted without TLS errors on port 9443.
2. **Date Parser Rewriting**: Strict Jio date parser rejected ISO 8601 `.000Z` with Fault 9007; `tls/pass_front.py` rewritten to `+00:00`, which was accepted with `Status 0` for `Device.JioSTB.USB.DebugValidityDate` (valid through 2037).
3. **Persistent ADB**: Port 5555 active (`[init.svc.adbd]: [running]`, `[service.adb.tcp.port]: [5555]`, `[persist.sys.usb.config]: [adb]`).
4. **CleanYourTV Launcher**: Installed `com.gathin.tvhome`, stock launcher `com.iwedia.ui.rjio.launcher.reliance` safely disabled via `pm disable-user --user 0`, CleanYourTV confirmed active Home window.
5. **Top Bar & Stats UI Customizations**:
   - **Settings Button**: Icon-only 42dp circular button showing only the clean gear logo.
   - **Wi-Fi & Bluetooth Buttons**:
     - At rest: 42dp circular buttons with active glowing blue frosted glass (`pill_bg_connected.xml`) when connected, dim transparent glass (`pill_bg_disconnected.xml`) when disconnected.
     - On D-Pad remote focus: Expands to full pill showing connected Wi-Fi SSID and Bluetooth remote (`JIO BLE Remote`).
     - `ACCESS_FINE_LOCATION` granted automatically by `build_install_launcher.ps1` so Android 11 resolves the active Wi-Fi SSID.
   - **Hardware Stats**: Text labels ("CPU", "Memory", "Storage") replaced with Material vector icons (`ic_stat_cpu`, `ic_stat_memory`, `ic_stat_storage`) vertically centered via `CenteredImageSpan`, displaying live real values without UI jank.
6. **Debloat & Performance**:
   - `com.jio.controlcentre` disabled (eliminates Compose back-button panic trap, saves ~135 MB RAM).
   - `com.jio.tr069client` and ad services disabled.
   - Core (`JmsCore`) and optional bloatware (`JmsOptional`) profiles codified in `scripts/disable_packages.ps1`.
   - Available free RAM: **~910 MB**.
   - CPU idle: **~89%**.
7. **Installed Applications**:
   - SmartTube (`SmartTube_stable_32.71_armeabi-v7a.apk`)
   - Cobalt (`cobalt-arm.apk`)
   - Downloader (`com.esaba.downloader_1.4.4-49_minAPI16(nodpi)_apkmirror.com.apk`)
   - Monet Launcher (`monet-launcher.apk` â€” safe rollback fallback)

## Full follow-up audit (2026-11-15)

The same full before/after collector used for JHS has now captured JMS twice, including complete package metadata and retained-uninstalled queries. JMS has 148 installed packages (121 system, 27 third-party), no extra retained-uninstalled names, and 34 disabled packages after this follow-up. Both software reboot observations recovered authorized ADB and showed CleanYourTV foreground through the observation window.

The standalone `JmsCore` profile now includes three packages present in the original setup policy but previously omitted: `com.jio.httpupdate`, `com.jio.usbupdate`, and `com.jio.backgroundscheduler`. Their updater/scheduler components were inspected, then the packages were disabled reversibly and verified still disabled after reboot. This intentionally disables their update/scheduling functions; it is separate from the proven JioService Home-restoration mechanism. Do not disable JioService.

See the [detailed evidence, rollback, and remaining acceptance limits](device-audit-2026-11-15.md#full-jms-follow-up-and-reversible-robustness-change). Extended idle/overnight behavior remains an open check.
