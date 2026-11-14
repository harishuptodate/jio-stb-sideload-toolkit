# CleanYourTV on verified JHSC200

This optional workflow was verified on JHSC200 v1, Android 11, firmware `STB-JHSC200-11.3.46`. This repository includes a modified copy of [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv), so no second checkout is required. Revalidate after a firmware or launcher source change.

CleanYourTV package: `com.gathin.tvhome`. It has no Internet permission and no native libraries. Do not run `examples/jio-stb-c200a/debloat.txt` on JHS: that list was contributed for a JMS C200A and does not establish that its package choices are safe on JHS.

## Outcome

The verified adaptation provides:

- SmartTube, Cobalt, JioStore, and MyMusic in the dock;
- Android TV Settings from the top Settings button;
- the connected SSID on the Wi-Fi button, which opens Android TV Network settings;
- the connected Bluetooth device on a Bluetooth button, which opens Android TV accessory pairing;
- Jio stock Settings as **Native settings** in the Settings long-press menu;
- the launcher's normal animations;
- available RAM and free storage displayed under the clock by default, with an on-screen toggle in Launcher settings;
- the previous Home component recorded before installation for rollback.

The measured launcher memory was about 45 MB PSS during the initial comparison and about 66 MB PSS after the final reboot, versus about 84 MB PSS observed for Monet. Treat these as observations from one box, not a general performance guarantee.

## Preflight and backup

Require working persistent ADB and capture a baseline first. Resolve the current Home and save the disabled-package list:

```powershell
& $Adb -s $Target shell cmd package resolve-activity --brief `
  -a android.intent.action.MAIN -c android.intent.category.HOME
& $Adb -s $Target shell pm list packages -d
```

The installer records the current Home component in `.state/launcher-before-*.json`. Keep that component available for rollback. On a stock JHS installation, also keep the Jio launcher enabled until CleanYourTV has survived a reboot.

```powershell
& $Adb -s $Target shell cmd package set-home-activity --user 0 '<saved package/activity>'
& $Adb -s $Target shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

Do not uninstall the previous launcher or Jio Settings during initial verification. Keep `com.rjil.jiostbsetting`, `com.android.tv.settings`, remote/Bluetooth services, and the already verified remote repair state enabled as documented elsewhere in this skill.

## Discover settings before adapting

JioOS registers `com.rjil.jiostbsetting/.MainActivity` at higher priority for both `android.settings.SETTINGS` and `android.settings.WIFI_SETTINGS`. The AOSP Android TV Settings package remains installed. On the verified firmware these explicit activities opened successfully:

| Function | Component |
| --- | --- |
| Android TV Settings | `com.android.tv.settings/.MainSettings` |
| Network | `com.android.tv.settings/.connectivity.NetworkActivity` |
| Bluetooth pairing | `com.android.tv.settings/.accessories.AddAccessoryActivity` |
| Apps | `com.android.tv.settings/.device.apps.AppsActivity` |
| Display and sound | `com.android.tv.settings/.device.displaysound.DisplaySoundActivity` |
| About | `com.android.tv.settings/.about.AboutActivity` |
| Developer options | `com.android.tv.settings/.system.development.DevelopmentActivity` |

Test components with `am start -W -n COMPONENT` and confirm `mResumedActivity` before wiring them into a build. A successful result on another firmware must be observed; package presence alone is insufficient.

## Source adaptation

The bundled source already contains these JHS-scoped changes:

1. Add `com.rjil.jiostbsetting` to the manifest's `<queries>` packages.
2. Add `com.rjil.jiostbsetting/com.rjil.jiostbsetting.MainActivity` first in `settings_fallback_components`. This exposes Jio Settings as **Native settings**.
3. In `SystemSettings.intent`, only when the resolved standard handler belongs to `com.rjil.jiostbsetting`, prefer an installed explicit AOSP component:
   - `ACTION_SETTINGS` -> `com.android.tv.settings.MainSettings`
   - `ACTION_WIFI_SETTINGS` -> `com.android.tv.settings.connectivity.NetworkActivity`
   - `ACTION_DISPLAY_SETTINGS` -> `com.android.tv.settings.device.displaysound.DisplaySoundActivity`
   - `ACTION_MANAGE_APPLICATIONS_SETTINGS` -> `com.android.tv.settings.device.apps.AppsActivity`
4. Set `dock_apps`, in order, to:

```xml
<item>org.smarttube.stable</item>
<item>io.gh.reisxd.tizentube.cobalt</item>
<item>com.jio.store</item>
<item>com.jio.mymusic.app</item>
```

5. Enable `app_library` and preload `com.jio.mymusic.app` in `library_apps`. MyMusic has a normal launcher activity but no Leanback launcher activity; without the preload, CleanYourTV skips it and fills its dock slot with another app.
6. Leave `reduced_motion` false unless the user explicitly prefers reduced animation. The verified owner preferred the normal animation.
7. Configure the system stats line to show live hardware stats with Material vector logos instead of text clutter:
   - In `config.xml`, set `show_stats` to `true` by default (`<bool name="show_stats">true</bool>`).
   - Replaced text labels ("CPU", "Memory", "Storage") with crisp vector icons: `ic_stat_cpu.xml` (microchip), `ic_stat_memory.xml` (RAM stick module), and `ic_stat_storage.xml` (drive trays).
   - Used `CenteredImageSpan` (`CenteredImageSpan.java`) to vertically center icons with font metrics.
   - Computes raw values off the main thread in `readRawStats()`, then builds `SpannableStringBuilder` on UI thread without frame drops.
   - Preserves live real numbers and units (e.g. `[CPU] 17% • [RAM] 651 MB free / 1990 MB • [Storage] 22 GB free`).
   - In `LauncherSettingsActivity.java`, `activity_launcher_settings.xml`, and `Config.java` (`SHOW_STATS_KEY`), retained the **RAM and storage** toggle switch.
8. Circular icon-only Settings button:
   - Converted `btnSettings` to `@style/TopButtonIcon` (42dp circle with 10dp padding).
   - Removed the text label so only the clean gear logo is shown.
9. Dynamic Wi-Fi and Bluetooth expanding pills:
   - **At Rest (Unfocused)**: Collapsed into compact 42dp circular buttons.
   - **Connection State Visuals**:
     - Connected: Active glowing blue frosted glass capsule (`pill_bg_connected.xml`) with electric blue gradient and stroke.
     - Disconnected: Dim neutral transparent glass (`pill_bg_disconnected.xml`).
   - **On D-Pad Remote Focus**:
     - Dynamically expands into a full pill.
     - Background transitions to solid white pill with dark text/icons.
     - Displays the connected Wi-Fi SSID or connected Bluetooth accessory name (e.g. `JIO BLE Remote`).
     - Collapses immediately when focus leaves.
   - **Wi-Fi SSID Resolution on Android 9/10/11**:
     - `WifiInfo.getSSID()` requires runtime location permissions on modern Android TV OS.
     - `build_install_launcher.ps1` automatically executes `pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` upon installation.

Do not add Internet access, new dependencies, binaries, or a JHS debloat list derived from the JMS example.

## Build and install

Use the standalone installer. It runs unit tests, lint, and the release build in Docker before installing the APK:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\scripts\build_install_launcher.ps1 -Target '192.168.1.8:5555'
```

The script requires the APK to remain below the repository's 589,824-byte gate, saves the existing Home in `.state`, installs the APK, selects CleanYourTV as Home, and verifies the resolved Home. For build-only verification, run:

```powershell
& .\tools\docker-build.ps1 -Project launcher `
  -Tasks @('testReleaseUnitTest','lintRelease','assembleRelease')
```

Installing a second Home claimant may temporarily show Android's resolver. Re-run the installer with `-SkipBuild` if the intended Home was not retained. Use `-DisableStockLauncher` only after the new Home has been tested and its saved rollback component is known.

## Verification and rollback

Verify by observed resumed components, then cold-boot once:

- Home resolves to and resumes `com.gathin.tvhome/.MainActivity`;
- Settings resumes `com.android.tv.settings/.MainSettings`;
- Wi-Fi shows the connected SSID and resumes `com.android.tv.settings/.connectivity.NetworkActivity`;
- Bluetooth shows the connected device name and resumes `com.android.tv.settings/.accessories.AddAccessoryActivity`;
- all four dock apps open, including `com.jio.mymusic.app/com.jio.mymusic.ui.WelcomeActivity`;
- long-press Settings contains **Native settings** and it opens Jio Settings;
- the stats line under the clock displays available RAM and free storage (e.g. Memory 741 MB free / 1959 MB · Storage 1.6 GB free);
- the **RAM and storage** toggle in Launcher settings switches the line off/on and persists across launcher restarts;
- physical remote navigation, volume, idle wake, and Home work;
- ADB reconnects and no launcher ANR/crash loop appears after reboot.

ADB key injection verifies routing but does not reproduce Bluetooth remote timing; require a short physical-remote check before declaring completion.

Rollback with the component saved in `.state/launcher-before-*.json`. Re-enable `com.iwedia.ui.rjio.launcher.reliance` first if the installer disabled it, set the saved component as Home, and press Home. Leave CleanYourTV installed until the restored launcher has survived a reboot; uninstalling it is optional after recovery is proven.
