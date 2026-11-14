# JHS remote lag, batching, and standby wake

This path is verified only on JHSC200 v1 firmware `STB-JHSC200-11.3.46` / build fingerprint containing `Jio/UHDHybridSTB/franklin:11/11.3.46`.

## Expected versus faulty behavior

Jio documents a delay of roughly five seconds immediately after boot as normal. Persistent delay, several buffered key presses executing together, loss of input after idle, or failure to wake from a steady-red standby state are faults.

Before changing packages, check batteries and pairing. Jio's reset combinations are:

- 43-key remote: hold `7 + 9` for four seconds.
- 38-key remote: hold `OK + TV` for four seconds.

Reboot the STB and pair within approximately 30 cm.

## Verified failure signature

On the verified box:

- Bluetooth was enabled and the `JIO BLE Remote` was bonded.
- `com.jio.remote.btserver` and `com.iwedia.bluetoothconnectionservice` were enabled.
- the remote showed `STATE_CONNECTED` while active and `STATE_DISCONNECTED` after idle;
- `com.iwedia.comedia.service` crashed repeatedly with `SIGSEGV` in `/vendor/lib/libcomedias.so`, including `SLIST_BuildPrefferedOrder_zapping_order`;
- each restart launched `crash_dump32`, consumed CPU, and coincided with delayed, batched input;
- re-enabling `com.jio.stb.catv` did not stop the loop;
- disabling `com.iwedia.comedia.service` for user 0 and rebooting reduced the post-boot matching crash count to zero;
- preventing automatic standby avoided the broken BLE wake path.

Cobalt was also heavy while foregrounded, using hundreds of MB of RAM and substantial CPU. Force-stop third-party foreground apps during diagnosis so they do not obscure the vendor-service fault.

## Diagnose

Run from this skill repository in PowerShell:

```powershell
.\scripts\jhs_remote_repair.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -Target STB_IP:5555 `
  -Action Diagnose
```

Do not apply the workaround unless the report shows the repeating `com.iwedia.comedia.service` / `libcomedias.so` signature and LiveTV is not required.

## Apply the verified workaround

```powershell
.\scripts\jhs_remote_repair.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -Target STB_IP:5555 `
  -Action Apply `
  -Reboot
```

This operation:

1. verifies the JHS build fingerprint;
2. records the original timeout and stay-awake settings in `.state`;
3. disables `com.iwedia.comedia.service` for user 0;
4. force-stops Cobalt if installed;
5. sets `stay_on_while_plugged_in=3`;
6. sets `screen_off_timeout=2147483647`;
7. optionally reboots.

After reboot, reconnect ADB and diagnose again. Confirm the crash count stays at zero, the remote reconnects on the first press, navigation no longer batches, and Home, display, audio, Settings, and retained apps work. LiveTV/tuner functions may no longer work.

## Roll back

```powershell
.\scripts\jhs_remote_repair.ps1 `
  -SourceRepo C:\path\to\sideload-jiostb `
  -Target STB_IP:5555 `
  -Action Rollback `
  -Reboot
```

Rollback re-enables the vendor service and restores the saved power settings. If the backup is unavailable, the observed pre-fix values were `stay_on_while_plugged_in=0` and `screen_off_timeout=900000`; do not assume those values on another box.

## Interpretation

- Bonded but disconnected after idle: press one key and wait; if it never reconnects, replace batteries and reset/re-pair the remote.
- Connected but input still batches with no crash loop: inspect current foreground CPU and memory use, then test with that app force-stopped.
- Crash loop returns after rollback: reapply only if LiveTV is unnecessary.
- JMS or another firmware: collect evidence only. Do not apply this JHS-specific workaround.
