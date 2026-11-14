#!/usr/bin/env python3
"""Queue only the two GenieACS tasks required to enable Jio STB network ADB."""

import argparse
import json
import urllib.error
import urllib.parse
import urllib.request


PARAMETERS = (
    ("Device.JioSTB.USB.USBDebugging", True, "xsd:boolean"),
    (
        "Device.JioSTB.USB.DebugValidityDate",
        "2037-01-01T00:00:00.000Z",
        "xsd:dateTime",
    ),
)


def opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def read_json(client, url):
    with client.open(url, timeout=10) as response:
        return json.load(response)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device-id", required=True, help="Exact GenieACS _id")
    parser.add_argument("--nbi", default="http://127.0.0.1:7557")
    args = parser.parse_args()

    nbi = args.nbi.rstrip("/")
    client = opener()
    devices = read_json(client, f"{nbi}/devices/?projection=_id,_lastInform")
    matches = [device for device in devices if device.get("_id") == args.device_id]
    if not matches:
        raise SystemExit("Device ID is not present in GenieACS. Copy the exact _id from a real check-in.")

    task_query = urllib.parse.urlencode(
        {"query": json.dumps({"device": args.device_id}, separators=(",", ":"))}
    )
    queued = read_json(client, f"{nbi}/tasks/?{task_query}")
    queued_names = {
        value[0]
        for task in queued
        for value in task.get("parameterValues", [])
        if value
    }

    device_path = urllib.parse.quote(args.device_id, safe="")
    for parameter in PARAMETERS:
        name = parameter[0]
        if name in queued_names:
            print(f"Already queued: {name}")
            continue
        payload = json.dumps(
            {"name": "setParameterValues", "parameterValues": [list(parameter)]}
        ).encode("utf-8")
        request = urllib.request.Request(
            f"{nbi}/devices/{device_path}/tasks",
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with client.open(request, timeout=10) as response:
                print(f"{response.status}: {name}")
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")
            raise SystemExit(f"Failed to queue {name}: HTTP {error.code}: {detail}") from error

    print("Only ADB enablement and its validity date were requested.")
    print("Cold-boot during the WAN-off interception window, then confirm status 0 responses.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
