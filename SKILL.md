---
name: jiostb-clean-setup
description: Prepare, diagnose, enable network ADB, install a launcher, and make reversible package changes on supported Jio STBs using Windows, Technitium DNS, and GenieACS. Use for verified JHSC200/JioOS 2.0 work and provisional JMSC/JMS work; do not use for firmware flashing or bootloader unlocking.
---

# Jio STB Clean Setup

Work from this standalone repository. It contains the verified Windows ADB runtime, TLS/GenieACS assets, orchestration scripts, and modified CleanYourTV source. Do not request or depend on a separate `sideload-jiostb` or CleanYourTV checkout.

## Route the device

1. Record the exact model and firmware shown by the STB.
2. For `JHSC200 v1` / JioOS 2.0, read [references/jhs.md](references/jhs.md).
3. For `JMSC200A`, `JMSC200Av2`, or another JMS variant, read [references/jms.md](references/jms.md). Treat that path as provisional until the exact model and firmware complete the full workflow.
4. Read [references/troubleshooting.md](references/troubleshooting.md) when a readiness check, TLS handshake, ACS check-in, or ADB connection fails.
5. Before disabling packages, read [references/package-policy.md](references/package-policy.md).
6. For delayed or batched remote input, loss of wake after idle, or repeated iWedia crashes on verified JHS firmware, read [references/jhs-remote-performance.md](references/jhs-remote-performance.md).
7. To build and adapt CleanYourTV as the JHS Home launcher, read [references/cleanyourtv-jhs.md](references/cleanyourtv-jhs.md). Do not apply its JMS C200A debloat example to JHS.

## Operational invariants

- Confirm the user owns or is authorized to modify the STB.
- Keep the router powered and Wi-Fi/LAN active. Disconnect only the WAN/uplink during the interception boot window.
- Keep the PC online during preparation, downloads, and ordinary ADB work.
- Keep Windows Defender Firewall enabled. Add narrowly scoped inbound rules for only the STB IP and PC IP.
- Give only the STB the PC's DNS address. Keep the PC and other clients on normal router/DHCP DNS.
- Create the exact DNS zone `acs.oss.jio.com`; never create a broad `jio.com` zone.
- Queue only the two ADB parameters. Do not add FOTA or downgrade flags to the normal workflow.
- Prefer `pm disable-user --user 0` over uninstalling or clearing system packages. Capture a baseline first.
- Never publish `.state`, device serials, GenieACS exports, logs, credentials, device-specific certificates, or ADB keys. Repository-owned runtime assets and their licenses are intentionally tracked.
- Restore the STB to DHCP/automatic DNS before removing PC-side DNS, proxy, Docker, or firewall support.

## Preferred workflow

1. Have the user manually set the STB static IP, gateway, subnet, and DNS 1 to the PC LAN IP. Confirm the PC itself remains on normal router/DHCP DNS.
2. If local PowerShell scripts are blocked, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`. From elevated PowerShell run `scripts/prepare.ps1` with PC IP, STB IP, and model. It performs preflight, exact Technitium configuration, scoped firewall rules, GenieACS startup, and proxy startup. Resolve every reported problem.
3. Run `scripts/offline_watch.py` and wait for `READY`.
4. Disconnect the router WAN/uplink, cold-boot the STB, and wait for a new ACS check-in. Reconnect WAN after the check-in or after the STB reaches its offline error screen.
5. Identify the new GenieACS device and run `scripts/queue_adb.py`. This queues only ADB enablement and its validity date.
6. Repeat the WAN-off cold boot. Wait for both tasks to be acknowledged and TCP 5555 to open.
7. Reconnect WAN. Connect ADB, accept the RSA prompt on the TV, and verify `adb get-state` returns `device`.
8. Run `scripts/capture_baseline.ps1 -Target ...` before launcher or package changes.
9. Build and install bundled CleanYourTV with `scripts/build_install_launcher.ps1 -Target ...`. Test it before using `-DisableStockLauncher`. Use `scripts/disable_packages.ps1 -WhatIf` before applying a profile.
10. Verify reboot, Home, remote, connected Wi-Fi/Bluetooth names, both pills' settings actions, Settings, JioStore/MyMusic if retained, and ADB reconnection.
    If remote input remains delayed or standby cannot wake, run `scripts/jhs_remote_repair.ps1 -Action Diagnose` before changing more packages.
11. Put the STB back on DHCP/automatic DNS. Then run `scripts/cleanup_pc.ps1` to remove the temporary PC configuration.

## Stop conditions

Stop and preserve logs if any of these occur:

- the exact model/firmware is outside the documented support matrix;
- the proxy reports `unknown_ca` for the selected certificate chain;
- the STB never reaches the exact ACS hostname;
- tasks are acknowledged but TCP 5555 stays closed after a cold boot;
- Android reports an unauthorized ADB key and no RSA prompt appears;
- a package change breaks the remote, display, Settings, TV input, store, or retained apps.

Restore the last reversible step before trying another change. Do not compensate by disabling unrelated services.
