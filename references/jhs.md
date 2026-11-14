# JHSC200 v1 / JioOS 2.0

Verified on firmware `STB-JHSC200-11.3.46`. Revalidate after any firmware change.

## Model-specific facts

- ACS request path: `/ftacs-digest/ACS`
- Accepted proxy chain in the source checkout: `tls/forged_chain.pem`
- ADB parameters:
  - `Device.JioSTB.USB.USBDebugging = true` as `xsd:boolean`
  - `Device.JioSTB.USB.DebugValidityDate = 2037-01-01T00:00:00.000Z` as `xsd:dateTime`
- A successful task response is `SetParameterValuesResponse` with status `0`.
- Confirmed persistent properties included `service.adb.tcp.port=5555` and `persist.iwedia.tr.adb.state=enabled`.

The default `acs_chain.pem` failed on the verified JHS box with `TLSV1_ALERT_UNKNOWN_CA`. Do not retry it repeatedly. Use the JHS chain and stop if that chain is also rejected.

## Start and observe

Use PowerShell from this skill repository:

```powershell
.\scripts\start_proxy.ps1 -SourceRepo C:\path\to\sideload-jiostb -Model JHS
python .\scripts\offline_watch.py --source-repo C:\path\to\sideload-jiostb --stb-ip 192.168.1.128
```

Do not disconnect WAN until the recorder says `READY`. The first offline cold boot establishes the real STB check-in. Queue the two ADB parameters while WAN is restored, then do a second offline cold boot to collect them.

## Connect ADB

From the source checkout:

```bash
./adb.exe connect 192.168.1.128:5555
./adb.exe -s 192.168.1.128:5555 get-state
```

Accept the RSA prompt on the TV. The final command must print `device`. Internet may be connected at this point because ADB stays on the LAN.

## Replacement launcher

Install the launcher APK from the authorized source checkout. The verified package was `com.klevico.monet`:

```bash
./adb.exe -s 192.168.1.128:5555 install -r monet-launcher.apk
./adb.exe -s 192.168.1.128:5555 shell monkey -p com.klevico.monet -c android.intent.category.LEANBACK_LAUNCHER 1
```

On the verified JHS firmware, `cmd package set-home-activity` returned success but the stock launcher reclaimed Home. After confirming Monet launches, use the reversible workaround:

```bash
./adb.exe -s 192.168.1.128:5555 shell pm disable-user --user 0 com.iwedia.ui.rjio.launcher.reliance
./adb.exe -s 192.168.1.128:5555 shell cmd package set-home-activity com.klevico.monet/.MainActivity
./adb.exe -s 192.168.1.128:5555 shell monkey -p com.klevico.monet -c android.intent.category.LEANBACK_LAUNCHER 1
./adb.exe -s 192.168.1.128:5555 shell input keyevent HOME
```

If the component name differs, query it before setting Home:

```bash
./adb.exe -s 192.168.1.128:5555 shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME com.klevico.monet
```

Rollback:

```bash
./adb.exe -s 192.168.1.128:5555 shell pm enable com.iwedia.ui.rjio.launcher.reliance
./adb.exe -s 192.168.1.128:5555 shell input keyevent HOME
```

Shevery is optional and was not required for persistent ADB on the verified box.

## Verification gate

Before cleanup, cold-boot once with WAN connected and verify:

- replacement Home opens;
- remote navigation and volume work;
- Wi-Fi and Settings work;
- retained JioStore and MyMusic work if required;
- `adb connect` succeeds again;
- no unexpected update or setup loop appears.

If any item fails, re-enable only the package changed immediately before the failure.
