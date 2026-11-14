# CleanYourTV on verified JHSC200

This optional workflow was verified on JHSC200 v1, Android 11, firmware `STB-JHSC200-11.3.46`. It builds [Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv) from source and keeps Monet installed as the recovery Home. Revalidate after a firmware or upstream launcher change.

CleanYourTV package: `com.gathin.tvhome`. It has no Internet permission and no native libraries. Do not run `examples/jio-stb-c200a/debloat.txt` on JHS: that list was contributed for a JMS C200A and does not establish that its package choices are safe on JHS.

## Outcome

The verified adaptation provides:

- SmartTube, Cobalt, JioStore, and MyMusic in the dock;
- Android TV Settings from the top Settings button;
- Android TV Network settings from the Wi-Fi button;
- Jio stock Settings as **Native settings** in the Settings long-press menu;
- the launcher's normal animations;
- Monet retained for immediate rollback.

The measured launcher memory was about 45 MB PSS during the initial comparison and about 66 MB PSS after the final reboot, versus about 84 MB PSS observed for Monet. Treat these as observations from one box, not a general performance guarantee.

## Preflight and backup

Require working persistent ADB and capture a baseline first. Resolve the current Home and save the disabled-package list:

```powershell
& $Adb -s $Target shell cmd package resolve-activity --brief `
  -a android.intent.action.MAIN -c android.intent.category.HOME
& $Adb -s $Target shell pm list packages -d
```

Keep this rollback command ready, substituting the actual Monet component if discovery reports a different one:

```powershell
& $Adb -s $Target shell cmd package set-home-activity --user 0 com.klevico.monet/.HomeActivity
& $Adb -s $Target shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

Do not uninstall Monet or Jio Settings. Keep `com.rjil.jiostbsetting`, `com.android.tv.settings`, remote/Bluetooth services, and the already verified remote repair state enabled as documented elsewhere in this skill.

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

Read the CleanYourTV repository's `AGENTS.md` before editing. Make only these JHS-scoped changes:

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

Do not add Internet access, new dependencies, binaries, or a JHS debloat list derived from the JMS example.

## Build and install

When local JDK/SDK versions do not match the project, use the repository's Docker builder:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
& .\tools\docker-build.ps1 -Project launcher `
  -Tasks @('testReleaseUnitTest','lintRelease','assembleRelease')
```

Require unit tests, lint, and the release build to pass. Confirm the APK stays below the repository's 589,824-byte gate. Install the resulting APK, select it as Home, and bring Home forward:

```powershell
& $Adb -s $Target install -r .\launcher\app\build\outputs\apk\release\app-release.apk
& $Adb -s $Target shell cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity
& $Adb -s $Target shell am start -a android.intent.action.MAIN -c android.intent.category.HOME
```

Installing a second Home claimant may temporarily show Android's resolver. Reissue the intended `set-home-activity` command immediately. Do not disable Monet.

## Verification and rollback

Verify by observed resumed components, then cold-boot once:

- Home resolves to and resumes `com.gathin.tvhome/.MainActivity`;
- Settings resumes `com.android.tv.settings/.MainSettings`;
- Wi-Fi resumes `com.android.tv.settings/.connectivity.NetworkActivity`;
- all four dock apps open, including `com.jio.mymusic.app/com.jio.mymusic.ui.WelcomeActivity`;
- long-press Settings contains **Native settings** and it opens Jio Settings;
- physical remote navigation, volume, idle wake, and Home work;
- ADB reconnects and no launcher ANR/crash loop appears after reboot.

ADB key injection verifies routing but does not reproduce Bluetooth remote timing; require a short physical-remote check before declaring completion.

Rollback to Monet with the saved command. If Home resolution becomes ambiguous, explicitly start Monet and re-run `set-home-activity`. Leave CleanYourTV installed until Monet has survived a reboot; uninstalling it is optional only after recovery is proven.
