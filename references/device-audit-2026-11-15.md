# JHS/JMS forensic comparison â€” 2026-11-15

## Finding and present status

The launcher-return problem is a model-specific boot-policy difference. JHS keeps its stock launcher disabled across the observed reboot. JMS explicitly enables that launcher from JioService startup. Both boxes have stock-launcher version `45.00.00.176` and CleanYourTV version `3.4`; version numbers alone do not explain the difference and do not prove the APKs are byte-identical.

On JMS, the practical fix is CleanYourTV's existing `stock_home_redirect` configuration plus `HomeKeyService`. Two software reboots and the owner's physical power-cycle/Home-button check passed on 2026-11-15. JHS does not need this helper in the observed configuration. This is a working redirect around JMS policy, not removal of that policy. Extended idle/overnight behavior is still an outstanding acceptance test.

No package, permission, Home, accessibility, or power-setting changes were applied to JHS during this audit. The audit performed one software reboot, read-only queries, UI launches, and Home navigation. Launching apps can change caches, tasks, and usage counters.

## Evidence and coverage

Private JHS evidence: `.state/audit-jhs-20261115-134757/`. Private JMS comparison: `.state/comparison-jms-20261115-132944/`, supplemented by earlier boot logs, per-launcher package dumps, and the pulled JMS `JioService.apk`.

The JHS capture contains 45 command outputs before and 45 after reboot. Each main capture entry records the command, UTC time, duration, exit code, byte count, and SHA-256 in `manifest.json`. Extra captures cover users, audio, HDMI, input methods, device idle, available Binder services, Wi-Fi status, and key vendor packages. `package-inventory.csv` records every known JHS package's version, UID, system classification, code location, install/update times, flags, and user-0 state. Full PackageManager output preserves activities, services, receivers, providers, permissions, preferred activities, shared UIDs, and current/hidden system-package records.

Other evidence includes the reboot timeline, navigation results, screenshot, copied historical JHS baseline/change records, and JMS restoring-method disassembly. Raw evidence can contain serials, accounts, MACs, SSIDs, addresses, and other private configuration. Keep `.state` out of Git.

The original saved JMS snapshot lacked full PackageManager metadata and a retained-uninstalled list. The later JMS follow-up on the same date filled those gaps with `.state/audit-jms-20261115-140301/` and a second capture after the three-package robustness change at `.state/audit-jms-20261115-140645/`. Both use the same 45-command before/after collection as JHS. The complete comparison inventory now includes both models' versions and system classifications.

## Device identity and important differences

| Item | JHS | JMS |
| --- | --- | --- |
| Model | JHSC200 | JMSC200A |
| Firmware | STB-JHSC200-11.3.46 | JioSTB-JMSC200A-25.1.9 |
| Product/device | UHDHybridSTB / franklin | 4KOTTSTB / MSTB |
| Android | 11 | 11 |
| Reported security patch | 2024-06-01 | 2024-02-05 |
| Advertised Android app ABI | armeabi-v7a, armeabi | armeabi-v7a, armeabi |
| Installed packages in capture | 145 | 148 |
| System / third-party classification | 118 / 27 | 121 / 27 |
| Disabled user-0 packages | 37 | 31 initially; 34 after the follow-up robustness change |
| Retained known but uninstalled user-0 packages | 0 exposed by PackageManager | 0 exposed by PackageManager |
| Resolved Android Home | CleanYourTV | Stock Jio launcher |
| Observed foreground Home | CleanYourTV | CleanYourTV through redirect |
| Stock launcher user-0 state | installed, disabled-user, not suspended | installed, enabled, not suspended |
| CleanYourTV Home accessibility helper | Not enabled | Enabled and bound |
| Other bound accessibility helper | iWedia LED Manager | None in saved snapshot |
| JioService Android package | Absent | com.jio.stb.jioservice present |
| Active model-specific TR-069 service | insight.tr069.client remains enabled | com.jio.tr069client disabled after setup |
| ADB | Authorized; recovered after audited reboot | Authorized; recovered after both follow-up audited reboots |

The full package union and both models' versions/classifications are in [device-package-inventory-2026-11-15.md](device-package-inventory-2026-11-15.md). Absence on one model is not evidence that we removed a package from it.

## Reconstruction of JHS changes

The earliest recovered JHS baseline was taken on 2026-11-14 at 14:36, after ADB enablement. It is not a factory image or an immutable record of every past operation. It contained 140 installed packages, stock Jio Home, and one disabled package: `com.android.talkback`.

Comparison with the present 145-package inventory:

- All 140 original baseline packages remain installed; none is missing.
- Five additional packages remain installed: `com.gathin.tvhome`, `com.klevico.monet`, `org.smarttube.stable`, `io.gh.reisxd.tizentube.cobalt`, and `com.esaba.downloader`.
- Shevery (`com.hamondev.shevery`) was successfully installed in the intervening post-setup logs but is absent now, including from `pm list packages -u`. This confirms an intervening install followed by present absence, not the exact removal command/time.
- Current state has 36 more disabled packages than the earliest baseline. The full disabled inventory is recorded, not inferred from a profile file.
- JioStore, MyMusic, Jio Account/SSO, vendor Settings, Android TV Settings, remote/Bluetooth services, display, and TV input packages remain installed and enabled. Enabled TV input alone does not establish working LiveTV.

Recovered change stages:

1. ADB enabled with the JHS-compatible TLS chain; persisted iWedia debug state/date are visible in current properties. The date is displayed as `2037-01-01T05:30:00+05:30`, equivalent to midnight UTC.
2. Initial post-setup logs show seven disables: `com.jio.tr069client`, command receiver, ad service, and four iWedia updater services. JMS-named HTTP/USB update and background-scheduler packages were reported absent on JHS.
3. The 14:55 app-cleanup record shows 17 entertainment/voice/casting-related disables; the 15:05 record adds eight optional app disables. Those are disabled installations, not APK deletion.
4. Later state includes disabled stock launcher, control centre, comedia service, and CATV package. Their precise individual commands/times are not all preserved in the earliest change records; current disabled state is verified.
5. Earlier remote repair addressed a recorded comedia native crash loop. The recorded pre-repair values were a 900000-ms screen timeout and stay-awake value 0. Current values are 2147483647 and 3, respectively, and survived the audited reboot.
6. Monet was replaced as Home by the customized CleanYourTV. Normal animations were restored at the owner's request. Current transition/window scales are 1.0; animator-duration scale is unset, not an explicitly stored 0.
7. CleanYourTV received settings shortcuts, default-on stats with a toggle, CPU/RAM/storage vector icons, and expanding Wi-Fi/Bluetooth pills. Runtime location grants support reading Wi-Fi SSID. The currently installed APK reports version 3.4; no new APK was installed in this audit.

Historical permission logs also contain failed attempts for permissions/app-ops unsupported on Android 11 or not requested by Shevery. Examples: POST_NOTIFICATIONS, NEARBY_WIFI_DEVICES, ACCESS_RESTRICTED_SETTINGS, and SYSTEM_EXEMPT_FROM_HIBERNATION. Attempted commands are not proof of grants. Shevery is absent now; there is no reason to reapply those attempts for this launcher fix.

## Timed JHS reboot experiment

Method: capture before state; issue one `adb reboot`; sample boot completion, uptime, and foreground activity about every 10 seconds; do not send Home or launch an app during the boot observation; capture after state around two minutes.

| Observation | Result |
| --- | --- |
| Before reboot | CleanYourTV resolved and foreground Home |
| About 5 seconds | ADB query timed out |
| About 15â€“45 seconds | ADB transport not available at sampled instants |
| About 55.6 seconds | First successful sample: boot_completed=1, uptime about 49.4 seconds, CleanYourTV foreground |
| About 66â€“117 seconds | CleanYourTV remained foreground in each sample |
| Around two minutes | Full after snapshot succeeded; all disabled-package memberships unchanged |
| Crash buffer before and after | Empty |
| Accessibility after boot | LED Manager bound; no crashed services; no CleanYourTV redirect helper |
| ADB persistence | Port/service recovered and the existing PC key remained authorized |

These are sampled host-relative times, not exact screen-visible boot latency or remote input latency. The first successful sample bounds what was visible to ADB; it does not identify the exact frame when the launcher appeared. No physical power removal was performed by the agent in this audit.

Stable settings: stay-awake 3, screen timeout 2147483647, normal stored animation scales, and every secure setting in the before/after snapshots. Expected changes include boot count 45â†’46, telemetry timestamps, Jio inactivity-status timestamp, and remote-key counters reset to zero. The Jio inactivity JSON still reports inactivity disabled.

The final checkpoint at roughly 657 seconds of device uptime still showed CleanYourTV foreground, the same stay-awake/screen-timeout values, and an empty crash buffer. This is a short observation after reboot/navigation, not an overnight or full standby-wake test.

## UI and application checks

All checks used ADB-injected navigation. Each destination was confirmed as the foreground activity before Home was injected; each Home returned to CleanYourTV.

| Check | Observed activity | Home result |
| --- | --- | --- |
| Android TV Settings | com.android.tv.settings/.MainSettings | CleanYourTV |
| Network | com.android.tv.settings/.connectivity.NetworkActivity | CleanYourTV |
| Bluetooth pairing | com.android.tv.settings/.accessories.AddAccessoryActivity | CleanYourTV |
| Jio native Settings | com.rjil.jiostbsetting/.MainActivity | CleanYourTV |
| SmartTube | BrowseActivity | CleanYourTV |
| TizenTube/Cobalt | dev.cobalt.app.MainActivity | CleanYourTV |
| Downloader | .MainActivity | CleanYourTV |
| JioStore | .activities.HomeActivity | CleanYourTV |
| MyMusic | WelcomeActivity | CleanYourTV |

Launching an app successfully does not prove playback, DRM, login, subscriptions, downloads, installation flows, audio quality, or every screen inside that app. Disabled apps were inventoried but not enabled or launched. System services/providers were inspected through PackageManager and dumpsys; executing every component would not be a read-only audit and could trigger reset/update/provisioning actions.

## Power, remote, storage, and resources

- JHS stayed awake (`mWakefulness=Awake`, `mStayOn=true`). Stay-awake value 3 prevents sleep for the configured AC/USB power conditions; it is not proof that every vendor standby path is disabled.
- Bluetooth was ON; the bonded JIO BLE Remote appeared disconnected in the after snapshot. Bonding does not prove an active HID connection. This audit's injected keys cannot validate physical remote latency, pairing recovery, volume/IR, or idle wake. Do not reset pairing based only on this idle snapshot.
- JHS secure sleep_timeout is 10800000 ms while screen_off_timeout is 2147483647 ms. These are different controls. Vendor inactivity logic also exists. Verify actual long idle/wake rather than assuming one setting controls everything.
- JHS has blank standard voice-recognition/interaction service fields, `voice_enabled=0`, and disabled Jio voiceassist. This is consistent with the earlier voice limitation; no universal STT compatibility is established by this audit.
- JHS usable data filesystem: 4105168 KiB total, 1587376 KiB available before audit navigation, about 3.92 GiB total and 1.51 GiB available. JMS saved snapshot: 25241900 KiB total, 22748552 KiB available, about 24.07 GiB total and 21.69 GiB available. These are data filesystems, not raw advertised flash capacity. Space changes with normal use.
- Kernel-reported RAM: JHS about 1.91 GiB; JMS about 1.94 GiB. Android meminfo free/cached accounting differs from the launcher's ActivityManager available-RAM display; do not compare them as identical metrics.
- Pre-audit CPU reports showed 6.6% aggregate on JHS and 11% on the earlier JMS capture. Sampling windows/workloads differ, so this is not a controlled benchmark or a guarantee of a performance advantage.
- JHS `insight.tr069.client` was active and used about 3.7% CPU in the sampled window, despite `com.jio.tr069client` being disabled. They are distinct packages. The earlier report's harmless IPC polling observation does not establish that all network-management behavior is disabled.
- JMS `lnt.hardware.dtvkit@1.0-service` was the largest listed process CPU consumer in its saved window. This is an observation, not a reason to disable a native hardware service.
- Read-only verified/system filesystem partitions reporting 100% usage are not equivalent to a full writable data partition.
- JHS thermal HAL reported status 0 and a current SoC temperature around 52.6 C in the supplemental snapshot; this is not a sustained stress or throttling test.
- JHS was connected on 5180 MHz Wi-Fi with RSSI -29 dBm and a reported 780-Mbit/s link in the supplemental sample. Link rate is not measured Internet throughput. These observations do not establish RF behavior over time.
- HDMI control/CEC was disabled in the JHS dump. Waking the box through a TV's CEC path is therefore not equivalent to waking it with the paired BLE remote; neither was physically tested in this audit.

## JMS root-cause evidence and failures

Pulled JMS JioService APK SHA-256: `9903f577fdc505396f3d6ba4654898f067a89e435dc01df7a41046a4a300601e`. The relevant method disassembly is saved privately with the audit evidence.

Observed call chain:

```text
JioServiceExtendedImpl.initialSetup()
  -> checkAndActivateLauncherIfNeeded()
     -> getPersistJioSysProductType()
     -> isHospitalityBuild(productType)
     -> enableHomeLauncherIfNeeded(!hospitality)
        -> enablePackageIfNeeded(stockLauncher, true)
           -> PackageManager.setApplicationEnabledSetting(stockLauncher, 1, 0)
```

The JMS product type was `AirFiber-UBR-Plan`, and boot tests showed the stock launcher enabled after reboot. Its Home filter priority was 2, while CleanYourTV's was 0. Assigning the Android Home role to CleanYourTV did not overcome the observed stock routing. A role holder, a resolved Home, and the actual foreground activity must be checked separately.

Failed attempts were preserved: disable-user only; component disable (SecurityException); user-0 removal retaining data (package restored after reboot); suspend plus disable (suspension cleared after reboot). JioService's code proves the direct enabling mechanism. The exact actor that cleared suspension or restored user-0 installation was not isolated; do not claim this one method proves those additional operations.

The successful workaround uses existing HomeKeyService window-state and short-Home handling, plus its boot probe. The JMS overlay sets stock_home_redirect to the Jio launcher and restore_key_services=true, and the helper is enabled in accessibility. Android may still resolve Home to Jio; the helper returns the visible interface to CleanYourTV. Initial Jio branding can appear briefly. Do not force-stop the launcher casually: force-stop removes accessibility services, and recovery requires the documented helper-repair path or reenabling it.

The earlier ADB failure was a separate issue: CWMP validity date normalization caused fault **9007**; numeric-offset rewriting fixed it. A cached true debugging value then prevented an actual repeated write. These explain the setup retries, not today's stock-launcher restoration after ADB already persisted.

Early conversation referred to JMS 24.1.39, but the recovered device observations identify 25.1.9 build 8. This difference in labels does not establish when a firmware update happened, or prove an update occurred during the overnight failure. The saved JHS before/after properties retain the same 11.3.46 fingerprint.

## Original-repo versus standalone gaps

1. The standalone installer omitted stock-launcher suspension. Testing the original suspension sequence still failed on this exact JMS build. Record that failed evidence rather than treating upstream comments as universal guarantees.
2. The original post-setup script handles com.jio.httpupdate, com.jio.usbupdate, and com.jio.backgroundscheduler. These were enabled on JMS and omitted from standalone JmsCore. The follow-up inspected their APK services/receivers and update permissions, added them to JmsCore, and disabled them reversibly. All three stayed disabled after the subsequent reboot. This closes an update/scheduling profile omission; no causal link to Home restoration is proven.
3. On JHS those exact JMS package names are absent; the iWedia updater counterparts are disabled. JHS also has enabled com.jio.jiobackgroundscheduler, a different package. Prefix similarity is insufficient grounds to disable it.
4. Do not copy the JHS comedia/CATV changes to JMS. Their package architecture differs, and disabling JHS television services has intentional LiveTV/tuner consequences.
5. Historical JMS documentation said fully verified before an adequate persistence/idle test. Treat the newer regression and redirect results as the authoritative scope. The old JMS reference contained a stale 9003 date-fault statement; it has been corrected to the actual captured 9007 fault.
6. A bare `adb.exe` in the final supplemental checkpoint selected an older laptop PATH installation and produced an ADB server-version mismatch. The command was corrected to the bundled executable's absolute path and the final checkpoint succeeded. The main collector already uses an absolute path. Use one ADB distribution consistently; transport failures caused by restarting the host server are distinct from device authorization/persistence faults. Bundled ADB here reports 37.0.1.

## Full JMS follow-up and reversible robustness change

Two additional software reboot experiments used the same collection method as JHS. The first captured the existing configuration without changing it. The second followed the three-package change below. No Home or launcher command was injected during either boot observation.

| Check | Existing configuration | After updater/scheduler change |
| --- | --- | --- |
| Installed / system / third-party packages | 148 / 121 / 27 | 148 / 121 / 27 |
| Disabled user-0 packages | 31 | 34 |
| First successful boot sample | About 55.8 seconds; CleanYourTV foreground | About 55.6 seconds; CleanYourTV foreground |
| Later boot samples through about 117 seconds | CleanYourTV foreground | CleanYourTV foreground |
| Disabled membership across each reboot | Unchanged | Unchanged |
| Secure and system settings across each reboot | Unchanged | Unchanged |
| Crash buffer after reboot | Empty | Empty |
| Home helper | Bound, no crashed services reported | Bound, no crashed services reported |
| Authorized ADB recovery | Passed | Passed |

The update/scheduler APK inspection identified `HttpUpdateService` in `com.jio.httpupdate` (2.1.1), `OtaUpdateService` in `com.jio.usbupdate` (2.3.5), and `BackgroundSchedulerService` in `com.jio.backgroundscheduler` (1.0.0), with boot/update-related receivers. The updater APKs request recovery/reboot permissions. These observations justify reviewing their original-repo update-blocking role; they do not prove an actual firmware update or launcher reset occurred yesterday.

Exactly these three packages changed from enabled to disabled-user; nothing was uninstalled or cleared. The change report is `.state/package-change-20261115-140645.json`. To revert this follow-up only, use the bundled ADB with `-s IP:5555 shell pm enable --user 0 PACKAGE` for each of those three names. Disabling them intentionally removes their normal update/scheduling functions, including USB update handling. Do not apply these JMS package names to unrelated models.

After the second reboot, the nine UI destinations listed above were tested again on JMS. Android Settings, Network, Bluetooth pairing, Jio Settings, SmartTube, TizenTube, Downloader, JioStore, and MyMusic opened; every injected Home returned to CleanYourTV. This checks navigation, not playback or physical remote behavior. Full results and supplemental hardware/service dumps are saved with the second audit. No launcher APK, theme, power setting, or JioService state was changed in this follow-up.

The 17 shared-package version differences and model-only package sets are preserved in the complete inventory. They reinforce that identical package toggles across models are not a valid goal. The direct Home-restoration evidence remains JMS JioService's enabling code; the redirect continues to work around that policy. Overnight/extended idle remains unverified, and these two new tests were software reboots rather than a new physical power cycle.

## Robustness acceptance gates

For future setup, record exact model/firmware first, then capture evidence before changing anything. Keep independent gates for TLS/check-in, actual parameter acknowledgement/readback, authorized ADB, launcher rendering, resolved Home, foreground Home, package persistence, physical cold boot, and extended idle.

For JMS builds with the demonstrated restoration behavior, use the existing redirect helper and preserve unrelated accessibility services when appending it. Back up overlay configuration and grants first. Confirm the helper is bound with no crash and that CleanYourTV appears after boot before sending any launch/Home commands. Test Home from other apps, not only while already on the launcher.

Require two software reboots, an owner-performed power cycle, an owner physical-remote check, and an overnight/idle check before calling long-term reliability verified. Keep rollback state per model and device. Do not disable JioService, Bluetooth, display, input, provisioning, or native DTV services to obtain superficial package parity.

The reusable collector is `scripts/audit_stb.py`: default capture is read-only; `--reboot` explicitly adds one reboot and timed recovery capture. The JMS follow-up has now used the same collector and filled the metadata gaps; do not repeat ACS enablement or reset the configured box merely to compare it.

## Limits

This is an extensive accessible-state audit, not a guarantee that every hidden firmware behavior was inspected. It does not include privileged app-private databases, deleted files, inaccessible persistent settings files, raw eMMC/partition images, root/bootloader changes, exhaustive APK reverse engineering, or a packet capture of every future network request. Historical baselines are partial and post-ADB. Android cannot reconstruct fully deleted apps from an empty retained-uninstalled list. Report what is captured, what is reconstructed from saved evidence, and what remains untested separately.

Explicit collection limits: `dumpsys bootstat` reported no such service, so the recorded boot timing comes from the host samples and uptime; `/proc/partitions` access was denied; the JHS theme-provider read reported ENOENT, indicating no config.json overlay. Some Android shell tools return exit code 0 even when their text reports such limitations. Zero exit codes in the manifest are not proof that every requested datum existed. The shell ran as UID 2000 with SELinux enforcement; no root access was requested.
