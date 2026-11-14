# Troubleshooting

Work from the first failed layer. Do not change DNS, certificates, proxy code, and STB packages at the same time.

## Laptop internet stops

The PC was probably pointed at its own incomplete DNS service or a broad `jio.com` zone intercepted unrelated names.

- Restore the PC adapter to DHCP/router DNS.
- Point only the STB at the PC LAN address.
- Delete a broad `jio.com` zone.
- Create exactly `acs.oss.jio.com` with an A record to the PC LAN address.

## Technitium cannot bind port 53

Check owners:

```powershell
Get-NetUDPEndpoint -LocalPort 53 | Select-Object LocalAddress,OwningProcess
Get-NetTCPConnection -LocalPort 53 -State Listen | Select-Object LocalAddress,OwningProcess
```

Windows Internet Connection Sharing may own UDP 53 on `0.0.0.0`. That is address ownership, not necessarily a reserved/excluded port. Bind Technitium specifically to the PC LAN IP plus loopback with `configure_technitium.ps1`. Avoid stopping ICS or Docker unless a specific conflict remains.

## Recorder says missing 8443 or 9443

The TLS proxy is not listening on both model endpoints. Run `start_proxy.ps1`, inspect its log in `.state`, and rerun the recorder. A stale log file does not prove a current listener.

## `doctor.py --simulate` fails or passes

Simulation tests a synthetic request and PC-side services. A 405 or device lookup mismatch can come from the synthetic identity/encoding. Even a pass does not prove the STB trusts the chain, uses the expected ACS hostname, or can reach the PC.

Use a real WAN-off cold boot and correlate:

- a new proxy-log entry;
- a new GenieACS check-in time;
- STB source address;
- the exact ACS path.

## Proxy reports `TLSV1_ALERT_UNKNOWN_CA`

The STB rejected the presented chain. For verified JHS firmware, select the JHS chain. For JMS, preserve the log and stop; do not guess another model's chain.

## No ACS check-in

Verify in order:

1. STB static IP, gateway, subnet, and DNS are correct.
2. `nslookup acs.oss.jio.com PC_IP` returns the PC IP.
3. Firewall rules match the current PC and STB addresses.
4. Ports 53, 8443, and 9443 are listening on the PC LAN address.
5. Router Wi-Fi/LAN remained on while only WAN was disconnected.
6. The STB was cold-booted after WAN was disconnected.

## ADB port is actively refused

That means the STB is reachable but nothing is listening on 5555. Confirm both GenieACS tasks were acknowledged with status `0`, then cold-boot again during the WAN-off interception window. Do not treat a queued task as an applied task.

## ADB is unauthorized

Keep the TV visible and accept the RSA prompt. Then run:

```bash
./adb.exe disconnect 192.168.1.128:5555
./adb.exe connect 192.168.1.128:5555
./adb.exe -s 192.168.1.128:5555 get-state
```

Do not delete the PC's ADB keys unless the on-screen authorization flow is irrecoverably stuck; doing so invalidates existing authorizations.

## Home returns to the stock launcher

On verified JHS firmware, disable only the stock launcher for user 0 after the replacement launcher is installed and launchable. See `jhs.md`. Do not disable UI, Settings, TV input, or Bluetooth service packages.

## Compose teardown cannot find a file

Use this repository's explicit Compose file:

```powershell
docker compose -f C:\path\to\sideload-jiostb\tls\docker-compose.yml down
```

Do not add `-v` unless intentionally deleting the named Mongo data volume.
