#!/usr/bin/env python3
"""Record an offline STB boot attempt without changing the device or ACS tasks."""

import argparse
import datetime
import json
import socket
import time
import urllib.request
from pathlib import Path


def port_open(host, port):
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False


def devices():
    client = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with client.open(
        "http://127.0.0.1:7557/devices/?projection=_id,_lastInform", timeout=2
    ) as response:
        return {item["_id"]: item.get("_lastInform") for item in json.load(response)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stb-ip", required=True)
    parser.add_argument("--seconds", type=int, default=600)
    parser.add_argument("--proxy-log", type=Path)
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error("--seconds must be positive")
    skill_root = Path(__file__).resolve().parent.parent
    if not (skill_root / "tls" / "pass_front.py").is_file():
        parser.error("standalone repository is incomplete: tls/pass_front.py is missing")
    proxy_path = args.proxy_log or skill_root / ".state" / "pass_front.log"
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    output = skill_root / ".state" / f"offline-{stamp}"
    output.mkdir(parents=True)

    with (output / "report.txt").open("w", encoding="utf-8") as report, (
        output / "proxy-new.log"
    ).open("wb") as capture:

        def log(message):
            line = f'[{datetime.datetime.now().isoformat(timespec="seconds")}] {message}'
            print(line, flush=True)
            report.write(line + "\n")
            report.flush()

        log(f"Report directory: {output}")
        log(f"STB: {args.stb_ip}; diagnostic only; no tasks queued or apps changed.")
        missing = [port for port in (7547, 7557, 8443, 9443) if not port_open("127.0.0.1", port)]
        try:
            previous = devices()
        except (OSError, ValueError, KeyError) as error:
            log(f"NOT READY: cannot read GenieACS devices: {error}")
            return 1
        if missing or not proxy_path.exists():
            log(f"NOT READY: missing listener ports={missing}; proxy log exists={proxy_path.exists()}")
            return 1

        log("Initial device snapshot (not evidence of a new check-in): " + json.dumps(previous))
        log("Local services reachable. This does not verify STB-to-PC connectivity.")
        log("READY: disconnect router WAN/uplink, keep Wi-Fi on, then cold-boot the STB.")
        log(f"Recording for {args.seconds} seconds. Ctrl+C also saves the report.")
        position = proxy_path.stat().st_size
        deadline = time.monotonic() + args.seconds
        last_adb = None
        last_error = None
        changes = 0
        try:
            while True:
                with proxy_path.open("rb") as source_log:
                    if proxy_path.stat().st_size < position:
                        position = 0
                        log("Proxy log was truncated; capturing from its new beginning.")
                    source_log.seek(position)
                    capture.write(source_log.read())
                    capture.flush()
                    position = source_log.tell()
                try:
                    current = devices()
                    for device_id, last_inform in current.items():
                        if last_inform and previous.get(device_id) != last_inform:
                            changes += 1
                            log(f"NEW/UPDATED INFORM: {device_id} at {last_inform}")
                    previous = current
                    if last_error:
                        log("GenieACS API recovered.")
                    last_error = None
                except (OSError, ValueError, KeyError) as error:
                    if str(error) != last_error:
                        log(f"GenieACS read error: {error}")
                    last_error = str(error)
                adb = port_open(args.stb_ip, 5555)
                if adb != last_adb:
                    status = "OPEN (authorization not checked)" if adb else "not reachable"
                    log(f"STB TCP 5555: {status}")
                    last_adb = adb
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break
                time.sleep(min(3, remaining))
        except KeyboardInterrupt:
            log("Recording stopped by user.")
        finally:
            log(f"Finished. New/updated device check-ins observed: {changes}.")
            log("Reconnect router internet before continuing ordinary setup or diagnostics.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
