---
name: jiostb-clean-setup
description: Prepare, diagnose, enable network ADB, install a launcher, and make reversible package changes on supported Jio STBs using Windows, Technitium DNS, and GenieACS. Use for verified JHSC200/JioOS 2.0 work and provisional JMSC/JMS work; do not use for firmware flashing or bootloader unlocking.
---

# Jio STB Clean Setup

Use the source `sideload-jiostb` checkout as an input. This skill supplies safer orchestration and documentation; it does not redistribute its certificates, APKs, ADB binaries, or private material.

## Route the device

1. Record the exact model and firmware shown by the STB.
2. For `JHSC200 v1` / JioOS 2.0, read [references/jhs.md](references/jhs.md).
3. For `JMSC200A`, `JMSC200Av2`, or another JMS variant, read [references/jms.md](references/jms.md). Treat that path as provisional until the exact model and firmware complete the full workflow.
4. Read [references/troubleshooting.md](references/troubleshooting.md) when a readiness check, TLS handshake, ACS check-in, or ADB connection fails.
5. Before disabling packages, read [references/package-policy.md](references/package-policy.md).

## Operational invariants

- Confirm the user owns or is authorized to modify the STB.
- Keep the router powered and Wi-Fi/LAN active. Disconnect only the WAN/uplink during the interception boot window.
- Keep the PC online during preparation, downloads, and ordinary ADB work.
- Keep Windows Defender Firewall enabled. Add narrowly scoped inbound rules for only the STB IP and PC IP.
- Give only the STB the PC's DNS address. Keep the PC and other clients on normal router/DHCP DNS.
- Create the exact DNS zone `acs.oss.jio.com`; never create a broad `jio.com` zone.
- Queue only the two ADB parameters by default. Do not queue the source repo's FOTA or downgrade flags unless the user explicitly requests them and accepts their effect.
- Prefer `pm disable-user --user 0` over uninstalling or clearing system packages. Capture a baseline first.
- Never publish device serials, GenieACS exports, logs, credentials, certificates, private keys, APKs, or ADB binaries.
- Restore the STB to DHCP/automatic DNS before removing PC-side DNS, proxy, Docker, or firewall support.

## Preferred workflow

1. If local PowerShell scripts are blocked, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` in that terminal. Then run `scripts/preflight.ps1` with the source checkout, PC IP, and STB IP. Resolve every reported port or file problem.
2. Run `scripts/configure_technitium.ps1`. It backs up listener settings, binds DNS to the PC LAN IP and loopback, and creates only `acs.oss.jio.com`.
3. Add the scoped firewall rules printed by preflight from an elevated PowerShell prompt.
4. Start the model-specific proxy with `scripts/start_proxy.ps1`.
5. Run `scripts/offline_watch.py` and wait for `READY`.
6. Disconnect the router WAN/uplink, cold-boot the STB, and wait for a new ACS check-in. Reconnect WAN after the check-in or after the STB reaches its offline error screen.
7. Identify the new GenieACS device and run `scripts/queue_adb.py`. This queues only ADB enablement and its validity date.
8. Repeat the WAN-off cold boot. Wait for both tasks to be acknowledged and TCP 5555 to open.
9. Reconnect WAN. Connect ADB, accept the RSA prompt on the TV, and verify `adb get-state` returns `device`.
10. Run `scripts/capture_baseline.ps1` before launcher or package changes.
11. Install and select the launcher using the model reference. Use `scripts/disable_packages.ps1 -WhatIf` before applying a profile.
12. Verify reboot, Home, remote, Wi-Fi, Settings, JioStore/MyMusic if retained, and ADB reconnection.
13. Put the STB back on DHCP/automatic DNS. Then run `scripts/cleanup_pc.ps1` to remove the temporary PC configuration.

## Stop conditions

Stop and preserve logs if any of these occur:

- the exact model/firmware is outside the documented support matrix;
- the proxy reports `unknown_ca` for the selected certificate chain;
- the STB never reaches the exact ACS hostname;
- tasks are acknowledged but TCP 5555 stays closed after a cold boot;
- Android reports an unauthorized ADB key and no RSA prompt appears;
- a package change breaks the remote, display, Settings, TV input, store, or retained apps.

Restore the last reversible step before trying another change. Do not compensate by disabling unrelated services.
