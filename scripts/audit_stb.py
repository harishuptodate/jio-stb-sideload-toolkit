#!/usr/bin/env python3
"""Capture private, read-only STB evidence; optionally record one authorized reboot."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import time


COMMANDS = {
    "properties": "getprop",
    "packages": "pm list packages -f -U",
    "packages-known": "pm list packages -u -f -U",
    "packages-installed": "pm list packages --user 0",
    "packages-known-names": "pm list packages -u --user 0",
    "packages-disabled": "pm list packages -d --user 0",
    "packages-enabled": "pm list packages -e --user 0",
    "packages-system": "pm list packages -s --user 0",
    "packages-third-party": "pm list packages -3 --user 0",
    "package-manager": "dumpsys package",
    "home-candidates": "cmd package query-activities --brief -a android.intent.action.MAIN -c android.intent.category.HOME",
    "home-resolved": "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME",
    "preferred": "dumpsys package preferred-xml --full",
    "roles": "dumpsys role",
    "activity": "dumpsys activity activities",
    "services": "dumpsys activity services",
    "processes": "ps -A",
    "process-top": "top -b -n 1 -m 25",
    "accessibility": "dumpsys accessibility",
    "power": "dumpsys power",
    "display": "dumpsys display",
    "input": "dumpsys input",
    "bluetooth": "dumpsys bluetooth_manager",
    "wifi": "dumpsys wifi",
    "connectivity": "dumpsys connectivity",
    "memory": "dumpsys meminfo",
    "cpu": "dumpsys cpuinfo",
    "storage": "df -k",
    "mounts": "cat /proc/mounts",
    "memory-kernel": "cat /proc/meminfo",
    "uptime": "cat /proc/uptime",
    "settings-global": "settings list global",
    "settings-system": "settings list system",
    "settings-secure": "settings list secure",
    "device-policy": "dumpsys device_policy",
    "jobs": "dumpsys jobscheduler",
    "alarms": "dumpsys alarm",
    "appops": "dumpsys appops com.gathin.tvhome",
    "launcher-package": "dumpsys package com.gathin.tvhome",
    "stock-launcher-package": "dumpsys package com.iwedia.ui.rjio.launcher.reliance",
    "launcher-config": "content read --uri content://com.gathin.tvhome.theme/config.json",
    "crashes": "logcat -d -b crash",
    "logcat": "logcat -d -b all -v threadtime",
    "bootstats": "dumpsys bootstat",
    "thermal": "dumpsys thermalservice",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", required=True)
    parser.add_argument("--label", required=True, choices=["jhs", "jms"])
    parser.add_argument("--reboot", action="store_true", help="Reboot after the initial snapshot and observe for two minutes")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    adb = str(root / "adb.exe")
    out = root / ".state" / ("audit-" + args.label + "-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    out.mkdir(parents=True)
    manifest = {"target": args.target, "started": datetime.now(timezone.utc).isoformat(), "commands": {}}

    def run(argv, timeout=25):
        try:
            r = subprocess.run([adb, "-s", args.target, *argv], capture_output=True, timeout=timeout)
            return r.returncode, r.stdout + r.stderr
        except subprocess.TimeoutExpired as error:
            return -1, (error.stdout or b"") + (error.stderr or b"") + b"\nAUDIT COMMAND TIMEOUT\n"

    if run(["get-state"])[1].strip() != b"device":
        raise SystemExit("Device must be connected and authorized before auditing")
    model = run(["shell", "getprop", "ro.product.model"])[1].decode(errors="replace").strip()
    if not model.upper().startswith(args.label.upper()):
        raise SystemExit("Model does not match audit label: " + model)
    manifest["model"] = model

    def save(phase, name, command):
        folder = out / phase
        folder.mkdir(exist_ok=True)
        started = time.monotonic()
        code, data = run(["shell", command])
        path = folder / (name + ".txt")
        path.write_bytes(data)
        manifest["commands"][phase + "/" + name] = {
            "command": command, "returncode": code, "seconds": round(time.monotonic()-started, 3),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "captured": datetime.now(timezone.utc).isoformat(),
        }

    def snapshot(phase):
        print("Capturing", phase, flush=True)
        for name, command in COMMANDS.items():
            save(phase, name, command)
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    print("Private evidence:", out, flush=True)
    snapshot("before")
    if args.reboot:
        print("Reboot requested; recording recovery without injecting Home or starting an app", flush=True)
        started = time.monotonic()
        run(["reboot"], timeout=5)
        milestones = []
        deadline = started + 180
        next_sample = 0
        while time.monotonic() < deadline:
            elapsed = round(time.monotonic() - started, 1)
            if elapsed >= next_sample:
                code, data = run(["shell", "getprop sys.boot_completed; cat /proc/uptime; dumpsys activity activities | grep mResumedActivity"], timeout=3)
                milestones.append({"seconds": elapsed, "returncode": code, "output": data.decode(errors="replace")})
                if code:
                    subprocess.run([adb, "disconnect", args.target], capture_output=True, timeout=5)
                    try:
                        subprocess.run([adb, "connect", args.target], capture_output=True, timeout=4)
                    except subprocess.TimeoutExpired:
                        pass
                print("Boot sample", elapsed, "s:", data.decode(errors="replace").strip()[:220], flush=True)
                next_sample = elapsed + 10
            if elapsed >= 120 and milestones[-1]["returncode"] == 0 and milestones[-1]["output"].startswith("1"):
                break
            time.sleep(1)
        (out / "boot-timeline.json").write_text(json.dumps(milestones, indent=2), encoding="utf-8")
        snapshot("after")
    manifest["finished"] = datetime.now(timezone.utc).isoformat()
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("Finished:", out, flush=True)


if __name__ == "__main__":
    main()
