# Jio STB Clean Setup

A standalone Windows toolkit and Codex skill for enabling persistent network ADB on supported Jio set-top boxes, installing the included CleanYourTV launcher, making reversible package changes, and restoring the PC afterward.

This repository contains everything the workflow consumes locally: Windows ADB, GenieACS Compose, the TLS proxy and certificate chains, setup and rollback scripts, modified CleanYourTV source, its Docker build environment, and the Codex skill. No second repository is required. Internet is still required initially for Docker images and ordinary downloads.

## Support status

| Device | Firmware | Status |
| --- | --- | --- |
| JHSC200 v1 / JioOS 2.0 | `STB-JHSC200-11.3.46` | Completed and verified |
| JMSC200Av2 | `22.1.09`, `24.1.39`, `25.1.9` reported upstream | Provisional; stop on certificate or ACS differences |
| Base JMSC200A and other variants | Any | Unverified; diagnostics only |

Support is exact-model and exact-firmware specific. Do not treat JHS and JMS as interchangeable. This project does not flash firmware, unlock the bootloader, root Android, or bypass account/payment services.

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

## Complete verified JHS workflow

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

This checks files and ports, prompts for Technitium credentials, backs up its listeners, configures only `acs.oss.jio.com`, replaces three firewall rules scoped to this PC/STB pair, starts GenieACS, and starts the JHS TLS proxy on 8443/9443. Defender Firewall stays enabled.

Fix every reported conflict before continuing. UDP/TCP 53 is often occupied by Internet Connection Sharing; the verified setup avoids stopping it by binding Technitium to the PC's specific LAN address.

### 3. First offline boot: discover the device

In a second PowerShell window in the repository root:

```powershell
python .\scripts\offline_watch.py --stb-ip 192.168.1.128
```

Wait for `READY`, then:

1. Disconnect only the router WAN/internet uplink.
2. Keep router power and Wi-Fi on.
3. Unplug STB power, wait five seconds, and reconnect it.
4. Wait for `NEW/UPDATED INFORM` or the STB offline/error screen.
5. Reconnect WAN.
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

Wait for `READY`, disconnect only WAN, cold-boot again, and wait for the new check-in. The desired result is task acknowledgement and `STB TCP 5555: OPEN`. Reconnect WAN immediately afterward. Internet may stay connected from this point because ADB is LAN traffic.

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

The bundled source is customized for verified JHS:

- Android TV Settings and Network screens bypass Jio's high-priority redirect;
- Jio Settings remains under **long-press Settings → Native settings**;
- the dock targets SmartTube, Cobalt, JioStore, and MyMusic when present;
- normal animations remain enabled;
- available RAM and free storage show by default;
- **Launcher settings → RAM and storage** toggles the stats line.

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

The script uses `pm disable-user --user 0`, records a report, and never uninstalls or clears apps. Re-enable one package with:

```powershell
.\adb.exe -s 192.168.1.128:5555 shell pm enable PACKAGE.NAME
```

Preserve JioStore, MyMusic, Jio Account/SSO, Jio Settings, remote/Bluetooth services, Jio Voice Assist, and the Jio keyboard unless you deliberately accept losing their functions. Voice search requires Jio Voice Assist enabled and microphone permission granted to the Jio keyboard.

### 10. Reboot verification

Cold-boot once with WAN connected and verify:

- CleanYourTV returns as Home;
- physical remote, volume, Home, and idle wake work;
- Wi-Fi opens Android TV Network settings;
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

Restore the stock launcher:

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

JMS is provisional. Use `-Model JMS`, which selects `acs_chain.pem`, and read [references/jms.md](references/jms.md). Stop on `unknown_ca`, a different ACS path, tasks acknowledged without port 5555, or an undocumented firmware. Do not guess with the JHS chain or package profile.

## Codex skill

The repository root is the skill folder. Put it under `%USERPROFILE%\.codex\skills\jiostb-clean-setup` or create a junction to this checkout, then invoke `$jiostb-clean-setup` with the exact model, firmware, PC IP, and STB IP.

The skill guides the agent through preparation, pauses for each manual WAN/cold-boot step, queues only the ADB parameters, builds the included launcher, preserves rollback state, and cleans up. It cannot operate TV network menus, unplug hardware, accept RSA prompts, or validate physical-remote timing.

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
