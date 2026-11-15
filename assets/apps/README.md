# Bundled support apps

These are unchanged APKs copied from the local `ilikechocopies/sideload-jiostb` checkout. `manifest.json` records package IDs, versions, file sizes, and SHA-256 hashes; the installer verifies both hashes before installation. These are pinned artifacts, not a claim that they are current releases or independently audited apps.

| File | Package | Version | Setup role |
| --- | --- | --- | --- |
| `monet-launcher.apk` | `com.klevico.monet` | 1.1.0 | Installed backup launcher; never selected or launched automatically |
| `shevery-release.apk` | `com.hamondev.shevery` | 14.5.0 | Installed optional management helper; privileged service is not automatically started |

The main launcher installer installs both through `install_support_apps.ps1` before installing/selecting CleanYourTV. The support installer itself does not change Home, enable accessibility helpers, grant permissions, or alter package enablement. Existing same-signed installations are updated with `adb install -r`; version/signature conflicts stop installation instead of deleting data or forcing a downgrade.

To install only these apps on an already configured box, use the standalone support installer from the repository root. Do not reinstall/reselect the primary launcher just to add support apps. Installation alone does not prove Monet renders correctly on a new firmware or that Shevery's privileged service is active. Verify those separately if needed. Shevery does not supply Play Store or root, and the CleanYourTV JMS redirect does not depend on it.

For deliberate Monet fallback, open `com.klevico.monet/.HomeActivity` through ADB and test rendering. This starts its screen for a session; it does not by itself change permanent Home routing. JMS's CleanYourTV redirect can still handle physical Home, so persistent fallback requires backing up and adjusting that redirect/helper first. Follow the manual's rollback rather than silently replacing CleanYourTV as Home.

APK authors and dependencies retain their own license terms; the repository's Apache license does not relicense these binaries. Original embedded notices are preserved in the unchanged APKs. Source checkout: https://github.com/ilikechocopies/sideload-jiostb .
