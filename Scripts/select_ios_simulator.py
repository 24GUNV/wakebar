#!/usr/bin/env python3

import json
import subprocess


def runtime_version(identifier: str) -> tuple[int, ...]:
    suffix = identifier.rsplit("iOS-", maxsplit=1)[-1]
    return tuple(int(component) for component in suffix.split("-"))


payload = json.loads(
    subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        text=True,
    )
)

candidates = []
for runtime, devices in payload["devices"].items():
    if "SimRuntime.iOS-" not in runtime:
        continue
    phones = [
        device
        for device in devices
        if device.get("isAvailable", True) and device["name"].startswith("iPhone")
    ]
    if phones:
        candidates.append((runtime_version(runtime), phones[0]["udid"]))

if not candidates:
    raise SystemExit("No available iPhone Simulator was found")

print(max(candidates)[1])
