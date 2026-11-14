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
