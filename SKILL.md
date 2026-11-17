---
name: jiostb-clean-setup
description: Prepare, diagnose, enable network ADB, install a customized launcher, and make reversible package changes on supported Jio STBs using Windows, Technitium DNS, and GenieACS. Includes tested JHSC200 v1, JMSC200A 25.1.9, and JMSC200Av2-labelled 24.1.39 paths with model-specific persistence limits; do not use for firmware flashing or bootloader unlocking.
---

# Jio STB Clean Setup

Work from this standalone repository. It contains the verified Windows ADB runtime, TLS/GenieACS assets, orchestration scripts, and modified CleanYourTV source. Do not request or depend on a separate `sideload-jiostb` or CleanYourTV checkout.

## Route the device

1. Record the exact model and firmware shown by the STB.
2. For `JHSC200 v1` / JioOS 2.0, read [references/jhs.md](references/jhs.md).
3. For `JMSC200A` (`25.1.9`), `JMSC200Av2`, or another JMS variant, read [references/jms.md](references/jms.md). The tested base JMSC200A has authorized ADB and a reboot/cold-boot-tested Home redirect. A separate JMSC200Av2-labelled box reporting `JMSC200A` / `24.1.39` also passed direct physical Home handling and owner cold-boot/volume checks; keep its evidence separate. Extended idle behavior remains unverified.
4. Read [references/troubleshooting.md](references/troubleshooting.md) when a readiness check, TLS handshake, ACS check-in, or ADB connection fails.
5. Before disabling packages, read [references/package-policy.md](references/package-policy.md).
6. For delayed or batched remote input, loss of wake after idle, or repeated iWedia crashes on verified JHS firmware, read [references/jhs-remote-performance.md](references/jhs-remote-performance.md).
7. To build and adapt CleanYourTV as the JHS Home launcher, read [references/cleanyourtv-jhs.md](references/cleanyourtv-jhs.md). Do not apply its JMS C200A debloat example to JHS. If JMS restores the stock launcher after reboot, use the tested `stock_home_redirect` / `HomeKeyService` fallback in [references/jms.md](references/jms.md); disable/uninstall/suspend alone did not persist on the tested 25.1.9 box.
8. For a detailed JHS/JMS comparison, package history, failed approaches, evidence limits, and robustness gates, read [references/device-audit-2026-11-15.md](references/device-audit-2026-11-15.md). Use `scripts/audit_stb.py --target IP:5555 --label jhs` (or `jms`) for private read-only capture; add `--reboot` only when a reboot is authorized. This captures evidence and does not apply repairs.

## Explain the mechanism accurately

When explaining setup, use the manual's [certificate/debugging sequence](references/manual-setup.md#how-the-certificate-and-debugging-steps-fit-together). Both models use the same management interception workflow with different accepted chain assets. `start_proxy.ps1 -Model JHS` selects `forged_chain.pem`; JMS selects `acs_chain.pem`. Certificate presentation happens during the offline boot's TLS handshake; debugging is enabled later by the two management settings, not by the certificate alone. Do not describe this as obtaining a CA private key, contacting eMudhra for an unlock, a valid CA-issued impersonation certificate, root, or bootloader unlocking. Device acceptance and bundled issuer/subject names do not prove correct X.509 validation or isolate the precise trust weakness.

## Manual and agent handoff

Use [references/manual-setup.md](references/manual-setup.md) for the complete PowerShell procedure, expected outputs, offline handoff, JMS overlay/helper merge and rollback, and failure decisions. It is the human-facing end-to-end guide; do not leave a user to infer missing commands from historical notes. Load the exact model reference and package policy before device changes. For documentation-only work, do not connect to or modify an STB.

For a resumed or already configured box, identify its current model, firmware, IP, Home resolution/foreground, helper state, and private change history first. Do not rerun ACS setup or all profiles merely because context was lost. IP is not device identity; DHCP and switching boxes can change it. Use the bundled ADB absolute path in automation.

## Bundled support apps

Monet (`com.klevico.monet`) and Shevery (`com.hamondev.shevery`) are shipped in `assets/apps/` with a pinned hash manifest. Install both after authorized ADB/baseline capture as part of every new setup: the normal `scripts/build_install_launcher.ps1` invokes `scripts/install_support_apps.ps1` automatically before installing/selecting CleanYourTV. If the main launcher installer stops before its install phase, do not assume support apps were installed; check their package IDs. For an existing configured box needing only these apps, run `scripts/install_support_apps.ps1 -Target ...` directly instead of reselecting Home.

Keep CleanYourTV primary. Do not launch/select Monet, grant Monet WRITE_SECURE_SETTINGS, or enable Monet's Home helper during normal setup. Monet is an installed fallback only. Do not replace the JMS CleanYourTV redirect with Monet routing. Shevery installation alone is not service activation, root, universal Shizuku compatibility, or a guaranteed ADB recovery path. Do not grant broad permissions/AppOps, start its privileged service, or promise reboot persistence without a separate requested use case and actual verification. Follow [assets/apps/README.md](assets/apps/README.md) and the [manual support-app procedure](references/manual-setup.md#bundled-support-apps-monet-backup-and-shevery). Stop on checksum, signature, or version conflicts; never delete existing app data to force an update.

## Operational invariants

For both WAN-off discovery and task-delivery boots, provide the human the [manual timing rule](references/manual-setup.md#offline-timing-rule-for-both-models): wait for READY, remove uplink, pause about 30 seconds, power off STB for five seconds, power on with WAN off, and wait at least four minutes from power-on and until boot settles before reconnecting WAN. An early check-in does not shorten this curator-recommended wait; elapsed time does not prove success. This is operating guidance, not a measured firmware requirement. Save the handoff before losing internet.

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
4. Follow the manual's offline timing rule: remove WAN, pause about 30 seconds, cold-boot with five seconds power-off, then keep WAN off for at least four minutes after power-on and until boot settles. Record the new ACS check-in; restore WAN after that window for continuation or diagnosis.
5. Identify the new GenieACS device and run `scripts/queue_adb.py`. This queues only ADB enablement and its validity date.
6. Repeat the same WAN-off timing rule for task delivery. Record both task acknowledgements and TCP 5555 opening; do not reconnect before the minimum four-minute/settled-boot window or treat elapsed time as successful delivery.
7. Reconnect WAN. Connect ADB, accept the RSA prompt on the TV, and verify `adb get-state` returns `device`.
8. Run `scripts/capture_baseline.ps1 -Target ...` before launcher or package changes.
9. Build and install bundled CleanYourTV with `scripts/build_install_launcher.ps1 -Target ...` (automatically grants runtime location permission for Wi-Fi SSID resolution). Features include an icon-only gear Settings button, dynamic Wi-Fi & Bluetooth expanding pills on remote D-pad focus with glowing blue glass for connected states, and live hardware stats with Material vector logos. Test rendering first. On tested JHS use `-DisableStockLauncher` only after rendering succeeds. For JMS, complete the manual's Home redirect/helper step by default after rendering: merge `stock_home_redirect=com.iwedia.ui.rjio.launcher.reliance`, `restore_key_services=true`, and `home_long_press_home=true`, back up the prior overlay/helper state, and bind HomeKeyService while preserving other services. Do not wait for a rapid-Home flash report or treat a failed resolved-Home check as installation failure. Keep this default in the JMS overlay, not global launcher resources or JHS. Use `scripts/disable_packages.ps1 -WhatIf` with `-Profile JhsCore` / `JhsOptional` or `-Profile JmsCore` / `JmsOptional` before applying a profile.
10. Verify reboot, physical short/rapid/held Home from another app, volume, remote navigation, connected Wi-Fi/Bluetooth names, both pills' settings actions, Settings, JioStore/MyMusic if retained, and ADB reconnection. On JMS, require no Jio flash during rapid physical Home presses and verify the helper and all three overlay keys after reboot; held Home opens CleanYourTV instead of the vendor long-press action. Complete two software reboot observations and an owner cold boot, and keep extended idle as a separate check.
    On verified JHS only, if remote input remains delayed or standby cannot wake, run `scripts/jhs_remote_repair.ps1 -Action Diagnose` before changing more packages.
11. Put the STB back on DHCP/automatic DNS. Then run `scripts/cleanup_pc.ps1` to remove the temporary PC configuration.

## Evidence and model-specific failure rules

- Keep separate gates: current real INFORM, queued task, actual RPC/status 0, open 5555, authorized ADB, rendered launcher, resolved Home, foreground Home, reboot persistence, physical remote, and extended idle. None substitutes for another. Stop diagnosing at the first failed layer.
- JHS uses the forged/eMudhra chain; JMS uses the RIL chain. Do not swap chains blindly. READY proves local listeners, not device trust or connectivity. Restore WAN for ordinary work; never depend on the online agent during a WAN-off handoff.
- The captured JMS date fault is 9007. Inspect proxy normalization and the exact-device GenieACS cache before repeated retries. Cache repair must preserve/export the device record and unset only the demonstrated stale parameter, never wipe the database.
- On tested JMS, JioService explicitly re-enables stock Home; this was confirmed in both the 25.1.9 and separate 24.1.39 APKs. Upstream suspension was initially omitted, then tested and observed to reset on 25.1.9; the separate 24.1.39 box also restored a disabled launcher and rejected component disabling/hiding. Keep JioService and stock Home enabled for the default workaround. Direct Home handling consumes the key before normal routing, while the stock-window redirect covers boot. Preserve other accessibility services and keep a rollback copy of the overlay, helper list, switch, and grant. Do not repeat disable/uninstall/suspend experiments during normal setup merely to rediscover these recorded results.
- Call that JMS behavior a redirect workaround, not a root-cause/firmware fix. Resolved Home can remain Jio while foreground is CleanYourTV. Observe boot without injecting Home or launching the app. Force-stop can unbind the helper; repair/rebind it rather than disabling vendor hardware services.
- The three JMS updater/scheduler omissions are now in JmsCore. Disabling them intentionally removes those functions; it does not cure JioService Home restoration or establish that an overnight firmware update occurred. JHS counterparts and vendor services differ.
- JHS comedia repair requires the matching native crash evidence and acceptance of LiveTV/tuner loss. Do not copy it to JMS. Pairing, active BLE connection, injected navigation, physical latency, microphone capture, STT delivery, and idle wake are distinct checks.
- Preserve normal animations unless requested otherwise. Use reported app ABI, not assumed CPU bitness. Do not promise Play Store certification or universal voice from sideloading. Keep failed feature experiments reversible and revert them when requested.
- Retained-uninstalled lists cannot reconstruct fully deleted apps. Same package versions need not mean identical APKs. Do not benchmark models from different CPU sampling windows or equate read-only partition fullness with data exhaustion.

At completion, report exactly what changed, which original-repo differences are intentional, which observed failures remain, where private rollback evidence is saved, and what was tested physically versus through ADB. Two software reboots and a physical power-cycle/Home check support the current JMS workaround; extended idle/overnight remains unverified until actually observed. Never label one successful launch as complete persistence verification.

## Stop conditions

Stop and preserve logs if any of these occur:

- the exact model/firmware is outside the documented support matrix;
- the proxy reports `unknown_ca` for the selected certificate chain;
- the STB never reaches the exact ACS hostname;
- tasks are acknowledged but TCP 5555 stays closed after a cold boot;
- Android reports an unauthorized ADB key and no RSA prompt appears;
- a package change breaks the remote, display, Settings, TV input, store, or retained apps.

Restore the last reversible step before trying another change. Do not compensate by disabling unrelated services.
