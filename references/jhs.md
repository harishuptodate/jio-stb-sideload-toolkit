# JHSC200 v1 / JioOS 2.0

Verified on firmware `STB-JHSC200-11.3.46`. Revalidate after any firmware change.

For the full ordered Windows procedure and rollback, use the [complete manual](manual-setup.md). JHS does not need the JMS redirect in the observed configuration; extended idle is not established by the comparison audit.

## Model-specific facts

- ACS request path: `/ftacs-digest/ACS`
- Accepted bundled proxy chain: `tls/forged_chain.pem`
- ADB parameters:
  - `Device.JioSTB.USB.USBDebugging = true` as `xsd:boolean`
  - `Device.JioSTB.USB.DebugValidityDate = 2037-01-01T00:00:00.000Z` as `xsd:dateTime`
- A successful task response is `SetParameterValuesResponse` with status `0`.
- Confirmed persistent properties included `service.adb.tcp.port=5555` and `persist.iwedia.tr.adb.state=enabled`.

The default `acs_chain.pem` failed on the verified JHS box with `TLSV1_ALERT_UNKNOWN_CA`. Do not retry it repeatedly. Use the JHS chain and stop if that chain is also rejected.

## Start and observe

Use PowerShell from this skill repository:

```powershell
.\scripts\start_proxy.ps1 -Model JHS
python .\scripts\offline_watch.py --stb-ip 192.168.1.128
```

Do not disconnect WAN until the recorder says `READY`. The first offline cold boot establishes the real STB check-in. Queue the two ADB parameters while WAN is restored, then do a second offline cold boot to collect them.

## Connect ADB

From this repository:

```bash
./adb.exe connect 192.168.1.128:5555
./adb.exe -s 192.168.1.128:5555 get-state
```

Accept the RSA prompt on the TV. The final command must print `device`. Internet may be connected at this point because ADB stays on the LAN.

## Replacement launcher

Follow [cleanyourtv-jhs.md](cleanyourtv-jhs.md), then run the bundled builder/installer:

```powershell
.\scripts\build_install_launcher.ps1 -Target 192.168.1.128:5555
```

On verified JHS, the stock launcher may reclaim Home. Test CleanYourTV first, then rerun with `-SkipBuild -DisableStockLauncher`. This disables the stock package only for user 0 and saves rollback state; it does not uninstall it.

Rollback:

```bash
.\adb.exe -s 192.168.1.128:5555 shell pm enable com.iwedia.ui.rjio.launcher.reliance
.\adb.exe -s 192.168.1.128:5555 shell input keyevent HOME
```

## Verification gate

Before cleanup, cold-boot once with WAN connected and verify:

- replacement Home opens;
- remote navigation and volume work;
- Wi-Fi and Settings work;
- retained JioStore and MyMusic work if required;
- `adb connect` succeeds again;
- no unexpected update or setup loop appears.

If any item fails, re-enable only the package changed immediately before the failure.
