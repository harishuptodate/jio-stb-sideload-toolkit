# Jio STB Sideload Toolkit

A standalone Windows toolkit and Codex skill for enabling persistent network ADB on supported Jio set-top boxes, installing the included CleanYourTV launcher, making reversible package changes, and restoring the PC afterward.

This repository contains everything the workflow consumes locally: Windows ADB, GenieACS Compose, the TLS proxy and certificate chains, setup and rollback scripts, modified CleanYourTV source, its Docker build environment, and the Codex skill. No second repository is required. Internet is still required initially for Docker images and ordinary downloads.

## Start here

This root README is the entry point to the complete information collected for the documented JHS/JMS workflow: setup, known mistakes, corrections, model-specific workarounds, verification, and rollback are included here or in the linked files. No previous chat or second repository is required. This does not guarantee support for every firmware or cover every possible future failure; remaining limits are documented.

**Recommended: use an AI agent such as Claude, Codex, or Antigravity** with access to this checkout and a local terminal. Ask it to read `SKILL.md`, the manual, and the exact model guide before acting. It can perform laptop work and explain each physical step; you still operate the TV/router, accept prompts, and test the remote. Save the offline instructions before disconnecting WAN, because an online agent may become unreachable.

If you prefer to work without AI, or want to read and understand the procedure first? The [complete manual](references/manual-setup.md) provides sequential PowerShell commands, physical actions, timing, expected results, troubleshooting, and rollback.

| Need | Reference |
| --- | --- |
| Complete manual procedure | [Manual](references/manual-setup.md) |
| AI-agent workflow | [Skill](SKILL.md) |
| Exact model differences | [JHS](references/jhs.md) / [JMS](references/jms.md) |
| DNS, ports, certificates, task faults, and ADB problems | [Troubleshooting](references/troubleshooting.md) |
| Package changes and their consequences | [Package policy](references/package-policy.md) |
| Launcher features and settings | [CleanYourTV guide](references/cleanyourtv-jhs.md) |
| Diagnosed JHS lag and standby workaround | [Remote guide](references/jhs-remote-performance.md) |
| Monet backup and Shevery artifacts | [Bundled apps](assets/apps/README.md) |
| Observed failures, root-cause evidence, and limits | [Audit](references/device-audit-2026-11-15.md) / [package inventory](references/device-package-inventory-2026-11-15.md) |

**Curated by [harishuptodate/](https://github.com/harishuptodate/jio-stb-sideload-toolkit).** This standalone toolkit brings together the information collected during both STB setups, fills documented information gaps in the original repo, and records errors encountered, corrections, workarounds, and potential failure conditions so the next human or agent need not rediscover them. Original workflow and launcher authors retain their credit and licenses; see [Attribution](#attribution) and [NOTICE](NOTICE). Curation is not a claim that every unknown firmware behavior has been eliminated.

For a complete human-operated procedure, use the [detailed manual for JHS and JMS](references/manual-setup.md). It covers every phase, expected output, model-specific Home behavior, rollback, and the mistakes observed during both setups. You do not need an AI agent. The shorter workflow below is a quick route; JMS users must follow its linked redirect procedure.

For AI agents, start with [SKILL.md](SKILL.md), then the exact model guide and the manual. Do not infer completion from command exit codes or copy package states between models.

## Support status

| Device | Firmware | Status |
| --- | --- | --- |
| JHSC200 v1 / JioOS 2.0 | `STB-JHSC200-11.3.46` | ADB, launcher and reboot checks passed; extended idle not established by the audit |
| JMSC200A | `25.1.9` | ADB and Home redirect tested across reboots and owner power cycle; extended idle pending |
| JMSC200Av2 | `22.1.09`, `24.1.39`, `25.1.9` reported upstream | Provisional; stop on certificate or ACS differences |
| Other JMSC200A firmware and other variants | Other / unknown | Unverified; diagnostics only |

Support is exact-model and exact-firmware specific. Do not treat JHS and JMS as interchangeable. This project does not flash firmware, unlock the bootloader, root Android, or bypass account/payment services.

See the [2026-11-15 device comparison audit](references/device-audit-2026-11-15.md) and [complete package inventory](references/device-package-inventory-2026-11-15.md) for measured JHS reboot behavior, historical changes, the JMS launcher cause, and remaining verification limits. Private raw captures are kept under `.state`; `scripts/audit_stb.py` collects a fresh snapshot without modifying package states.

## How certificates enable the ADB setup

Both models use the same local DNS -> TLS proxy -> GenieACS management-settings workflow. The certificate does not itself enable debugging: it is presented during the STB's management connection; GenieACS then supplies the debugging setting and validity date. That opens network ADB on STB port 5555 without a USB cable or a manual TV-menu toggle.

On tested JHS, preparation selects `forged_chain.pem`, the eMudhra-related chain; tested JMS selects `acs_chain.pem`, containing RILROOTCA. RIL here refers to Reliance Industries Limited, not Android's Radio Interface Layer. These are bundled local proxy assets, not a live service request to eMudhra or Reliance. Acceptance by these particular STBs does not establish a genuinely CA-issued certificate or standards-compliant validation. We did not obtain either CA's private signing key.

Read the [step-by-step mechanism and evidence limits](references/manual-setup.md#how-the-certificate-and-debugging-steps-fit-together) for exactly where the chain is selected, presented, and followed by debugging activation. Neither chain roots the box, unlocks its bootloader, or supplies Google TV certification.

## What remains manual

An agent or script cannot safely perform these physical/router steps:

1. Read the exact STB model and firmware from the TV.
2. Give the STB a static LAN address and set DNS 1 to the PC's active Wi-Fi/LAN IPv4 address.
3. Keep the router powered and Wi-Fi/LAN active while temporarily disconnecting only its WAN/internet uplink when instructed.
4. Cold-boot the STB by unplugging power, waiting five seconds, and reconnecting it.
5. Accept the ADB RSA prompt on the TV if it appears.
6. Test the physical remote after launcher or package changes.
7. Restore DHCP/automatic DNS on the STB before PC cleanup.

Do not turn off the router or Wi-Fi during an offline window.

## Requirements

- Windows 10/11 PC and an authorized STB on the same LAN
- Windows administrator access
- Docker Desktop, Python 3, PowerShell 5.1 or newer, and Git
- Technitium DNS Server at `http://127.0.0.1:5380`
- Access to the STB network menu and the router WAN/uplink

A USB drive and Jio account login are not required for the verified JHS ADB path. If the STB reaches a Jio login screen, leave it there.

## Example network values

Replace every example with your actual LAN values:

| Setting | Example |
| --- | --- |
| Router/gateway | `192.168.1.1` |
| PC IPv4 | `192.168.1.5` |
| STB static IPv4 | `192.168.1.128` |
| Subnet mask | `255.255.255.0` |
| STB gateway | `192.168.1.1` |
| STB DNS 1 | `192.168.1.5` (the PC) |
| STB DNS 2 | blank or `0.0.0.0` |

Use `ipconfig` to find the PC's active IPv4 address. Reserve the STB address in the router or choose an unused address outside its DHCP pool. Keep the PC on normal router/DHCP DNS; only the STB points to the PC.

## Short workflow (JHS; follow the JMS branch where indicated)

Open an **elevated PowerShell** in the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 1. Configure the STB network manually

Set the static IP, gateway, subnet mask, and DNS values described above. Keep internet connected. Do not cold-boot or disconnect WAN yet. Confirm the PC still has internet and still uses normal DNS.

### 2. Prepare the PC in one command

```powershell
.\scripts\prepare.ps1 `
  -PcIp 192.168.1.5 `
  -StbIp 192.168.1.128 `
  -Model JHS
```

Use `-Model JMS` for the tested JMS path. Technitium must already be installed/running separately; Docker Compose does not start it.

This checks files and ports, prompts for Technitium credentials, backs up its listeners, configures only `acs.oss.jio.com`, replaces three firewall rules scoped to this PC/STB pair, starts GenieACS, and starts the JHS TLS proxy on 8443/9443. Defender Firewall stays enabled.

Fix every reported conflict before continuing. UDP/TCP 53 is often occupied by Internet Connection Sharing; the verified setup avoids stopping it by binding Technitium to the PC's specific LAN address.

### 3. First offline boot: discover the device

In a second PowerShell window in the repository root:

```powershell
python .\scripts\offline_watch.py --stb-ip 192.168.1.128
```

Wait for `READY`, then:

1. Disconnect only the router WAN/internet uplink, then wait about 30 seconds.
2. Keep router power and Wi-Fi on.
3. Unplug STB power, wait five seconds, and reconnect it.
4. Keep WAN disconnected for at least four minutes after STB power-on and until boot settles; record `NEW/UPDATED INFORM`. An error screen alone is not success.
5. Reconnect WAN only after that minimum/settled boot, then diagnose missing results online. See the [recommended timing rule](references/manual-setup.md#offline-timing-rule-for-both-models).
6. Stop the recorder with `Ctrl+C` after the check-in; the report is still saved.

Open GenieACS at `http://localhost:3000` and copy the exact `_id` whose `_lastInform` changed. The bundled local Compose defaults are `admin` / `admin`; change them if the service will remain exposed.

### 4. Queue only ADB enablement

With WAN restored:

```powershell
python .\scripts\queue_adb.py --device-id "EXACT-GENIEACS-DEVICE-ID"
```

This queues only `Device.JioSTB.USB.USBDebugging=true` and `Device.JioSTB.USB.DebugValidityDate=2037-01-01T00:00:00.000Z`. It does not queue firmware or downgrade flags.

### 5. Second offline boot: deliver the tasks

Run a fresh recorder:

```powershell
python .\scripts\offline_watch.py --stb-ip 192.168.1.128
```

Wait for `READY`, disconnect only WAN, wait about 30 seconds, then cold-boot again with five seconds of power-off. Keep WAN disconnected for at least four minutes after STB power-on and until boot settles, recording the new check-in. The desired result is task acknowledgement and `STB TCP 5555: OPEN`. Reconnect WAN after the minimum/settled boot, even if results are missing and need online diagnosis. An early check-in does not shorten the recommended wait, and elapsed time does not prove success. Internet may stay connected for subsequent ADB work because it is LAN traffic.

### 6. Connect and authorize ADB

```powershell
.\adb.exe connect 192.168.1.128:5555
.\adb.exe -s 192.168.1.128:5555 get-state
```

Accept the TV's RSA prompt if shown. The second command must print `device`.

### 7. Capture rollback state

```powershell
.\scripts\capture_baseline.ps1 -Target 192.168.1.128:5555
```

The `.state` baseline records properties, packages, disabled packages, Home, and ADB settings. It can contain identifiers; never publish `.state`.

### 8. Build and install CleanYourTV

The bundled source was adapted on JHS and also installed/tested on the documented JMS:

- Android TV Settings and Network screens bypass Jio's high-priority redirect;
- Jio Settings remains under **long-press Settings → Native settings**;
- the dock targets SmartTube, Cobalt, JioStore, and MyMusic when present;
- normal animations remain enabled;
- available RAM and free storage show by default;
- **Launcher settings → RAM and storage** toggles the stats line;
- the top Wi-Fi and Bluetooth pills show the connected network and remote/device names;
- selecting Bluetooth opens Android TV's accessory pairing screen.

Build, test, lint, install, and select it as Home:

```powershell
.\scripts\build_install_launcher.ps1 -Target 192.168.1.128:5555
```

Verify its screen and remote. If the Jio launcher reclaims Home on JHS, apply the verified reversible workaround:

```powershell
.\scripts\build_install_launcher.ps1 `
  -Target 192.168.1.128:5555 `
  -SkipBuild `
  -DisableStockLauncher
```

The script stores the previous Home and stock-launcher state under `.state`; it never uninstalls the stock launcher.

For JMS, complete [manual step 7](references/manual-setup.md#7-jms-only-configure-the-home-redirect) by default after rendering succeeds: back up and merge `stock_home_redirect=com.iwedia.ui.rjio.launcher.reliance`, `restore_key_services=true`, and `home_long_press_home=true`, then enable/rebind HomeKeyService while preserving other accessibility services. Direct Home-key handling prevents the rapid-Home flash observed with the older redirect; held Home also opens CleanYourTV instead of the vendor long-press action. Keep stock Home and JioService enabled. This is a workaround around firmware routing, not permanent stock-launcher removal. See [the JMS evidence](references/jms.md) for the distinct 25.1.9 and 24.1.39 results. Verify foreground startup and all three keys/helper binding after reboot, then physical short/rapid/held Home, volume and a cold boot; keep extended idle separate. A successful installer command alone does not prove persistence. JHS keeps its separate disable-stock-launcher path.

### 9. Optional reversible app cleanup

Read [the package policy](references/package-policy.md). Preview first:

```powershell
.\scripts\disable_packages.ps1 `
  -Target 192.168.1.128:5555 `
  -Profile JhsOptional `
  -WhatIf
```

Apply only after reviewing the exact list:

```powershell
.\scripts\disable_packages.ps1 `
  -Target 192.168.1.128:5555 `
  -Profile JhsOptional
```

For JMS substitute `JmsOptional`. To apply the update/management core policy, separately preview and review `JhsCore` or `JmsCore`; these are not implied by the optional-app example. JMS core includes the three previously omitted updater/scheduler packages. Those omissions are separate from JioService restoring Home.

The script uses `pm disable-user --user 0`, records a report, and never uninstalls or clears apps. Re-enable one package with:

```powershell
.\adb.exe -s 192.168.1.128:5555 shell pm enable PACKAGE.NAME
```

Preserve JioStore, MyMusic, Jio Account/SSO, Jio Settings, and remote/Bluetooth services unless you deliberately accept losing them.

### 10. Reboot verification

Cold-boot once with WAN connected and verify:

- CleanYourTV returns as Home;
- physical remote, volume, Home, and idle wake work;
- Wi-Fi displays the connected SSID and opens Android TV Network settings;
- Bluetooth displays the connected device and opens Android TV accessory pairing;
- Settings opens Android TV Settings;
- long-press Settings offers Native settings;
- retained JioStore/MyMusic open;
- RAM/storage appear and their toggle works;
- ADB reconnects;
- no setup, update, ANR, or crash loop appears.

For delayed input or failed idle wake on verified JHS, follow [the remote guide](references/jhs-remote-performance.md). Diagnose before applying its workaround.

### 11. Restore normal networking and clean the PC

Restore DHCP/automatic IP and DNS on the STB and confirm its internet. Then run elevated:

```powershell
.\scripts\cleanup_pc.ps1 -StbDhcpRestored
```

Cleanup stops the tracked proxy, stops Compose without deleting Mongo data, removes the exact temporary firewall rules, removes the zone only when this run created it, and restores Technitium listeners.

## Rollback

For JMS, first [restore the saved redirect configuration and helper state](references/manual-setup.md#11-rollback). Enabling Jio Home alone will not remove its redirect. Restore the stock launcher:

```powershell
.\adb.exe -s TARGET shell pm enable com.iwedia.ui.rjio.launcher.reliance
.\adb.exe -s TARGET shell input keyevent HOME
```

Read `.state\launcher-before-*.json` for the previous Home. If needed, query the current Home with:

```powershell
.\adb.exe -s TARGET shell cmd package resolve-activity --brief `
  -a android.intent.action.MAIN -c android.intent.category.HOME
```

Re-enable packages individually using `pm enable`. Run `jhs_remote_repair.ps1 -Action Rollback` only if that script previously created its backup.

## JMS path

The tested JMSC200A 25.1.9 has working ADB and a Home redirect workaround; extended idle remains pending. Other revisions/builds are provisional. Use `-Model JMS`, which selects `acs_chain.pem`, and follow the [detailed manual](references/manual-setup.md) and [JMS reference](references/jms.md). The original repo's suspension technique failed persistence testing on this exact box; our helper works around the boot policy without removing it. Stop on `unknown_ca`, a different ACS path, tasks acknowledged without port 5555, or an undocumented firmware. Do not guess with the JHS chain or package profile.

## Bundled Monet backup and Shevery

Both APKs are included locally under [assets/apps](assets/apps/README.md); no separate download is needed. The standard `build_install_launcher.ps1` command installs Monet and Shevery before installing/selecting **CleanYourTV as primary Home**. Monet is an installed backup, not the default. Shevery is an optional management helper; installation does not start its privileged service or grant it elevated permissions. Neither app is required for CleanYourTV's JMS redirect.

For an already configured box, add only these two apps without rebuilding or changing Home:

```powershell
.\scripts\install_support_apps.ps1 -Target 192.168.1.128:5555 -WhatIf
.\scripts\install_support_apps.ps1 -Target 192.168.1.128:5555
```

Use the box's current IP. The installer checks pinned APK hashes, updates with `install -r`, and records prior package metadata privately. It stops on version/signature conflicts; do not uninstall existing data to bypass them. See the [manual](references/manual-setup.md#bundled-support-apps-monet-backup-and-shevery) for verification, deliberate backup use, and removal.

## Codex skill

The repository root is the skill folder. Put it under `%USERPROFILE%\.codex\skills\jio-stb-sideload-toolkit` or create a junction to this checkout, then invoke `$jio-stb-sideload-toolkit` with the exact model, firmware, PC IP, and STB IP.

Example request: `Use $jio-stb-sideload-toolkit from this checkout. My model/firmware is [...], PC IP is [...], STB IP is [...]. Prepare the laptop, tell me each physical step, use the correct model path, keep rollback state, and report which checks actually passed.`

The skill guides the agent through preparation, pauses for each manual WAN/cold-boot step, queues only the ADB parameters, builds the included launcher, preserves rollback state, and cleans up. It cannot operate TV network menus, unplug hardware, accept RSA prompts, or validate physical-remote timing.

For another AI agent, provide the checkout and ask it to read `SKILL.md` and the linked manual/model guide as project instructions. It needs local PowerShell/file access to execute the workflow; an agent without those tools can guide the human through the same commands. The skill does not depend on the previous chat or its private device IDs. Resume from the first unverified phase instead of replaying completed setup.

## Repository layout

| Path | Purpose |
| --- | --- |
| `SKILL.md`, `references/` | Agent workflow and model decisions |
| `scripts/` | Preparation, tasking, launcher install, diagnostics, rollback, cleanup |
| `tls/` | GenieACS Compose, proxy, and model certificate chains |
| `adb.exe`, `AdbWin*.dll` | Bundled Windows ADB runtime |
| `launcher/` | Modified CleanYourTV source |
| `tools/docker-build.ps1`, `tools/docker/` | Reproducible Android build environment |
| `third_party/` | Upstream licenses/notices |
| `.state/` | Private local backups/reports, ignored by Git |

## Corrections and common failures

- Create only `acs.oss.jio.com`, never a broad `jio.com` zone.
- Point only the STB to PC DNS; assigning the PC its own DNS can break laptop internet.
- Keep Defender Firewall enabled and use the scoped rules from `prepare.ps1`.
- Local simulations do not prove the STB trusts the TLS chain.
- Verified JHS rejected the default chain with `TLSV1_ALERT_UNKNOWN_CA`; it accepted `forged_chain.pem`.
- WAN is disconnected only for interception boots; reconnect it before ordinary ADB work.
- Do not use CleanYourTV's JMS C200A debloat list on JHS.
- Never publish `.state`, logs, device exports, serials, Android IDs, MAC addresses, credentials, or ADB keys.

## Attribution

The ACS/proxy workflow was adapted from `ilikechocopies/sideload-jiostb` under Apache-2.0. CleanYourTV is by Gathin under MIT; its font/icon licenses remain in `launcher/`. Android platform-tools retain their upstream terms. See `NOTICE` and `third_party/`.
