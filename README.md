# Jio STB Clean Setup

A manual guide and Codex skill for a cleaner, reversible version of the `sideload-jiostb` workflow on Windows.

This repository contains orchestration scripts and documentation only. It expects a separate checkout of [ilikechocopies/sideload-jiostb](https://github.com/ilikechocopies/sideload-jiostb) for GenieACS, its TLS proxy, certificates, APKs, and ADB. Those assets are intentionally not copied here.

## Support status

| Device | Firmware | Status |
| --- | --- | --- |
| JHSC200 v1 / JioOS 2.0 | STB-JHSC200-11.3.46 | Completed and verified |
| JMSC200Av2 | 22.1.09, 24.1.39, 25.1.9 reported upstream | Provisional; needs local validation |
| Base JMSC200A and other variants | Any | Unverified; diagnostic use only |

Support is exact-model and exact-firmware specific. A family name alone is not evidence that its certificate trust, ACS path, or ADB parameters match.

## Requirements

- Windows PC and STB on the same LAN
- An authorized Jio STB
- PowerShell 5.1 or newer, Python 3, Docker Desktop, and Git Bash
- Technitium DNS Server on the PC
- A separate `sideload-jiostb` checkout
- Ability to set static DNS on the STB and briefly disconnect only the router's WAN/uplink

A USB drive is not required for the verified JHS path. Keep the router and Wi-Fi powered throughout.

## Clean workflow

Run these commands from this repository in PowerShell. Replace the example addresses and source path. If Windows blocks local scripts, allow them only for the current PowerShell process first; this does not change the machine-wide policy:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then run:

```powershell
.\scripts\preflight.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -PcIp 192.168.1.5 `
  -StbIp 192.168.1.128

.\scripts\configure_technitium.ps1 -PcIp 192.168.1.5
.\scripts\start_proxy.ps1 -SourceRepo C:\path\to\sideload-jiostb -Model JHS

python .\scripts\offline_watch.py `
  --source-repo C:\path\to\sideload-jiostb `
  --stb-ip 192.168.1.128
```

When the recorder says `READY`:

1. Disconnect only the WAN/uplink; keep router power and Wi-Fi on.
2. Unplug STB power, wait five seconds, and reconnect it.
3. Wait for a new ACS check-in, then reconnect WAN.
4. Queue ADB using the GenieACS device ID shown by the check-in:

```powershell
python .\scripts\queue_adb.py --device-id "YOUR-GENIEACS-DEVICE-ID"
```

Repeat the WAN-off cold boot so the STB collects the queued settings. Once TCP 5555 opens, reconnect WAN and use ADB normally; ADB is local LAN traffic and does not require the internet to remain disconnected.

Before any app changes:

```powershell
.\scripts\capture_baseline.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -Target 192.168.1.128:5555

.\scripts\disable_packages.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -Target 192.168.1.128:5555 `
  -Profile JhsOptional `
  -WhatIf
```

Read [the JHS guide](references/jhs.md) or [the provisional JMS guide](references/jms.md) before continuing.

## Corrections to the rough workflow

- `stage1.sh --list-devices` only lists devices and exits; it is not setup.
- `stage1.sh --tasks-only` also queues FOTA/downgrade changes. `queue_adb.py` queues only the two ADB settings.
- The PC must not use itself as DNS. Only the STB points at the PC.
- The DNS zone must be `acs.oss.jio.com`, not `jio.com`.
- Windows Internet Connection Sharing can own UDP 53 on `0.0.0.0`. Binding Technitium to the PC's specific LAN address avoids stopping ICS or Docker.
- `doctor.py --simulate` proves only the local synthetic request path. It does not prove the STB trusts the certificate or reaches the proxy.
- The JHS device rejected the default chain with `TLSV1_ALERT_UNKNOWN_CA`; it accepted the JHS/eMudhra forged chain.
- On JHS, setting the Home activity alone was not durable. The stock launcher had to be disabled for user 0, then the replacement launcher selected and launched.
- Keep the firewall enabled and scope rules to one STB address.
- Run Compose teardown with its file path unless the current directory is `tls`.

## Cleanup and rollback

First restore DHCP/automatic DNS on the STB and confirm normal internet. Then run from an elevated PowerShell prompt:

```powershell
.\scripts\cleanup_pc.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -StbDhcpRestored
```

The cleanup stops the tracked proxy, stops Compose without deleting its named Mongo volume, removes the exact temporary firewall rules, deletes the DNS zone only when this skill created it, and restores the saved Technitium listener endpoints.

Package disables are reversed with:

```powershell
.\adb.exe -s 192.168.1.128:5555 shell pm enable PACKAGE.NAME
```

Restore the JHS stock launcher with:

```powershell
.\adb.exe -s 192.168.1.128:5555 shell pm enable com.iwedia.ui.rjio.launcher.reliance
```

## Use as a Codex skill

Copy or clone this directory under your Codex skills directory, then invoke `$jiostb-clean-setup`. The agent reads `SKILL.md` and loads the matching model reference.

Do not publish local logs, GenieACS exports, device identifiers, credentials, certificates, private keys, APKs, or ADB binaries in issues or commits.
