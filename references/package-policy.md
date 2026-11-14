# Reversible package policy

Capture a package, property, and Home baseline before changing anything. Disable one coherent group, reboot, and test. Use `pm disable-user --user 0`; do not clear data or uninstall system packages.

## Preserve by default

- `com.jio.store` — JioStore
- `com.jio.mymusic.app` — MyMusic
- `com.media.jio.sso.stb` — Jio Account/SSO; retain when keeping JioStore or MyMusic
- `com.jio.remote.btserver` — remote/Bluetooth service
- `com.iwedia.bluetoothconnectionservice`
- `com.iwedia.displayservice`
- `com.iwedia.tvinput`
- `com.rjil.jiostbsetting`
- other hardware, input, display, Settings, provisioning, and connectivity services not explicitly profiled

## Verified JHS core profile

These were disabled on the verified JHS box after ADB was persistent:

- `com.jio.tr069client`
- `com.rjil.jio.stb.commandreceiver`
- `com.jio.stbadservice`
- `com.iwedia.httpupdate`
- `com.iwedia.updateservice`
- `com.iwedia.pvodupdateservice`
- `com.iwedia.updatercuotaservice`

This changes update and management behavior. Apply it only after the launcher, ADB persistence, and rollback path have been tested.

## Verified JHS optional profile

User-facing packages disabled in the completed session included:

- `com.jio.media.livetv`
- `com.jio.stb.bot`
- `com.jio.media.jionewsstb`
- `com.discoveryplus.tv.jiotv`
- `com.jiostb.jiogames`
- `com.jio.media.jiobeats`
- `com.jio.jiocall`
- `com.jio.web`
- `com.jio.jiocloudpc`
- `com.jiotv.sonyliv`
- `com.jio.screensaver`
- `com.jio.myhome.mediasharedmp`
- `com.jio.yt`
- `com.jio.myjiotv`
- `com.android.app.jio.voiceassist`
- `com.jio.media.jiotvplus`
- `com.jio.jiopay`
- `com.etvwin.androidtv`
- `com.hoichoi.mitv`
- `com.suntv.sunnxt`
- `com.amazon.amazonvideo.livingroom`
- `com.netflix.partnertoken`
- `com.zee5.aosp`
- `com.inn.nvengineer`
- `com.jio.dialserver`
- `com.jio.controlcentre`

Known implications:

- `com.netflix.partnertoken` is the PADI/partner-token component; disabling it can affect Netflix activation.
- `com.jio.dialserver` is JioCast Dial server; disable only when casting is unused.
- `com.jio.stb.catv` is a privileged LiveTV component. It is no longer part of the default optional profile: disabling it did not cure the verified JHS crash loop, and its state changed during reboot testing.
- `com.iwedia.comedia.service` is a persistent vendor television service. Do not disable it during ordinary debloating. On verified JHS firmware, disable it only when logs show its confirmed repeating `libcomedias.so` crash signature and LiveTV is not needed; follow `jhs-remote-performance.md` and preserve rollback state.
- `com.inn.nvengineer` is JioNetVelocity.
- `com.jio.media.jiotvplus` is the downloadable JioTV+ package.
- `com.jio.controlcentre` is Jio's quick settings overlay and notification panel. Its Jetpack Compose UI intercepts remote input and its `onPreviewKeyEvent` handler drops `KEYCODE_BACK` ("back pressed - debounced, ignoring"), creating a panic trap where Back fails and only Home escapes. It has zero system dependents; disabling it stops its background services (`EndlessService`, `CCBridgeService`), saves ~135 MB RAM, and removes the trapped tile from all launchers.

## Explicit package mode

For packages outside these profiles, query first:

```bash
./adb.exe -s TARGET shell pm path PACKAGE.NAME
./adb.exe -s TARGET shell dumpsys package PACKAGE.NAME
```

Use the script's `-Packages` parameter only after identifying its role and rollback command. Never infer safety from a `com.jio` or `com.iwedia` prefix.

Re-enable any package with:

```bash
./adb.exe -s TARGET shell pm enable PACKAGE.NAME
```
