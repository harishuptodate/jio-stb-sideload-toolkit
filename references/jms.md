# JMS family: provisional path

## Working Home redirect on JMSC200A 25.1.9

Use this path when disable/uninstall/suspend is reset at boot. Inspection of this box's `JioService.apk` found `JioServiceExtendedImpl.initialSetup()` calling `checkAndActivateLauncherIfNeeded()`, which enables the stock launcher for a home product. Do not disable the whole JioService: it also handles hardware functions.

The bundled CleanYourTV already provides `HomeKeyService` for exactly this situation. On 2026-11-15, a device-local theme overlay with the following keys and the accessibility helper enabled returned to CleanYourTV automatically after reboot; Home from Android TV Settings, Network settings, and SmartTube also returned to CleanYourTV:

```json
{"stock_home_redirect":"com.iwedia.ui.rjio.launcher.reliance","restore_key_services":true}
```

Before applying, back up an existing theme with `content read --uri content://com.gathin.tvhome.theme/config.json`, the enabled accessibility-service list, accessibility switch, and WRITE_SECURE_SETTINGS grant. Merge these keys into an existing config rather than replacing its other keys. A missing config reports ENOENT; other read failures must be resolved first. Save the JSON locally, push it to `/data/local/tmp/jms-home-redirect.json`, and apply:

```powershell
.\adb.exe -s TARGET shell 'content write --uri content://com.gathin.tvhome.theme/config.json < /data/local/tmp/jms-home-redirect.json'
.\adb.exe -s TARGET shell pm grant com.gathin.tvhome android.permission.WRITE_SECURE_SETTINGS
.\adb.exe -s TARGET shell am force-stop com.gathin.tvhome
.\adb.exe -s TARGET shell am start -W -n com.gathin.tvhome/.MainActivity
```

Then append `com.gathin.tvhome/.HomeKeyService` to `settings secure enabled_accessibility_services` without removing existing services, and set `accessibility_enabled=1`. The tested box had an empty list. Leave the stock launcher enabled for this fallback. Confirm `dumpsys accessibility` shows the Home button helper bound, with no crashed service. Test actual foreground activity after boot before injecting Home or launching CleanYourTV; then test Home from another app.

This is a foreground/Home redirect, not a permanent change to the firmware's resolved Home. Jio's initial logo or screen may appear briefly before Android binds the helper. A PC, ACS, and Docker are not required after configuration. A full physical power cycle and extended idle test remain separate acceptance checks. Physical remote behavior must also be checked by the owner.

Rollback: restore the previous config through the provider (or delete only `config.json` if none existed), restore the previous enabled-service list and accessibility switch, and restart CleanYourTV. Revoke WRITE_SECURE_SETTINGS only if it was newly granted for this workaround. Keep JioService enabled.

## Persistence regression observed 2026-11-15

On the previously configured JMSC200A (25.1.9), the stock launcher reclaimed Home after extended use. Reboot testing reproduced restoration of `com.iwedia.ui.rjio.launcher.reliance` after both `pm disable-user --user 0` and `pm uninstall -k --user 0`. Direct disabling of its `IntroActivity` is rejected with `SecurityException`. Selecting CleanYourTV as Home works for the current session only. Do not describe launcher boot persistence as verified on this firmware until the restoration mechanism is identified and a fix survives reboot.

ADB and Bluetooth recovered after reboot, existing optional package disables remained, and Android TV Network and accessory activities opened successfully. `stay_on_while_plugged_in=3` persisted; `screen_off_timeout` returned to `900000`. JHS standby and launcher persistence behavior cannot be assumed on JMS. Local evidence and the pre-change baseline are retained under ignored `.state`.

The original `stage1.sh` suspension workaround was also tested: `pm suspend --user 0` followed by `pm disable-user --user 0` and selecting CleanYourTV. Before reboot the stock launcher reported `suspended=true` and `enabled=3`; after reboot it reported `suspended=false` and `enabled=1`, and Jio IntroActivity reclaimed Home. Suspension is therefore not a verified persistence fix on this box. Boot evidence is saved locally in `.state/jms-suspension-reset-boot.log`. If restoring Jio Home after a session workaround, run `pm unsuspend --user 0 com.iwedia.ui.rjio.launcher.reliance` before enabling it.

Stock-launcher recovery if needed: `adb -s TARGET shell cmd package install-existing --user 0 com.iwedia.ui.rjio.launcher.reliance`, followed by `pm enable` and selecting its Home activity.

This repository has not completed an end-to-end local validation on a JMS box. The earlier successful session used a JHSC200 v1 even though a JMSC model was initially discussed.

Upstream reports JMSC200Av2 support on firmware `22.1.09`, `24.1.39`, and `25.1.9`. That does not establish support for base `JMSC200A`, a different hardware revision, or a later firmware.

## Rules for the first validation

1. Record the exact model, hardware revision, and firmware before changing anything.
2. Capture a clean baseline and keep package changes out of the certificate/ADB validation phase.
3. Start with the bundled JMS/default chain:

```powershell
.\scripts\start_proxy.ps1 -Model JMS
```

4. Run the recorder and perform one WAN-off cold boot.
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

## Observed facts on JMSC200A (RNOSBGMB021108F)

1. **Certificate Chain**: Uses `acs_chain.pem` (RIL Root CA) on `https://acs.oss.jio.com:9443/ftacs-digest/ACS`.
2. **CWMP Date Strictness**: Rejects ISO 8601 UTC `.000Z` date format with SOAP Fault 9003. Requires `YYYY-MM-DDTHH:MM:SS+00:00`. `tls/pass_front.py` dynamically normalizes this.
3. **GenieACS Declarative Cache**: If `Device.JioSTB.USB.USBDebugging` is cached as `true` in MongoDB while ADB is not actually listening, GenieACS will not send the command over the wire. Unset the cached parameter in `db.devices` before queuing.
4. **Remote Wake Unusable**: Connection Request on port 7547 actively resets TCP (`RST`). Trigger check-ins via cold boot (unplug power 5s, reconnect) during the WAN-off window.

## Full Verification on JMSC200A (Firmware 25.1.9) - PASSED

Completed full end-to-end enablement, hardening, and launcher replacement on **JMSC200A** (`E4FAE4-JMSC200A-RNOSBGMB021108F`), running firmware `JioSTB-JMSC200A-25.1.9` (`Jio/4KOTTSTB/MSTB:11/25.1.9/8:user/release-keys`):

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
   - Monet Launcher (`monet-launcher.apk` — safe rollback fallback)
