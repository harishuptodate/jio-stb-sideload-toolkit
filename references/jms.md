# JMS family: provisional path

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
5. **Debloat & Performance**:
   - `com.jio.controlcentre` disabled (eliminates Compose back-button panic trap, saves ~135 MB RAM).
   - `com.jio.tr069client` and ad services disabled.
   - Core and optional bloatware profiles applied cleanly.
   - Available free RAM: **~910 MB**.
   - CPU idle: **~89%**.
6. **Installed Applications**:
   - SmartTube
   - Cobalt
   - Downloader
   - Monet Launcher (safe rollback fallback)
