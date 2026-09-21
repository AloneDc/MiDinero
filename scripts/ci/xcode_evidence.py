"""Parse real Xcode outputs. Unknown/missing evidence must never produce a green result."""
from __future__ import annotations

import re


def select_simulator(inventory: dict, destinations: str, requested: str | None = None,
                     sdk_version: str | None = None) -> dict:
    compatible = set(re.findall(r"id:\s*([A-Fa-f0-9-]{36})", destinations))
    runtimes = {runtime["identifier"]: runtime for runtime in inventory.get("runtimes", [])}
    choices = []
    for runtime_id, devices in inventory.get("devices", {}).items():
        runtime = runtimes.get(runtime_id, {})
        if ".iOS-" not in runtime_id or not runtime.get("isAvailable", False):
            continue
        version = tuple(int(n) for n in runtime.get("version", "0").split("."))
        if version < (17,):
            continue
        for device in devices:
            # Fresh runners can initially list only generic Xcode destinations.
            # In that case use an installed device matching the detected SDK, boot
            # it, and let xcodebuild resolve the explicit UUID authoritatively.
            matches = device.get("udid") in compatible if compatible else runtime.get("version") == sdk_version
            if (device.get("isAvailable") and device.get("name", "").startswith("iPhone") and matches):
                choices.append(dict(device, runtime=runtime_id, runtimeVersion=runtime["version"], version=version))
    if requested:
        choices = [device for device in choices if device["udid"] == requested]
    if not choices:
        raise ValueError("No available iPhone (iOS >= 17) matches Xcode destinations or the detected Simulator SDK.")
    # Prefer the installed SDK's runtime, even when CoreSimulator advertises
    # newer runtimes installed by another Xcode on the same hosted image.
    choices.sort(key=lambda device: (device["runtimeVersion"] == sdk_version, device["version"], device["name"], device["udid"]), reverse=True)
    selected = choices[0]
    selected.pop("version")
    return selected


def discovered_methods(enumeration: str) -> list[str]:
    # Input is the flat file WRITTEN BY XCODE, never source code or build logs.
    methods = sorted(set(re.findall(r"\btest[A-Z][A-Za-z0-9_]*", enumeration)))
    if not methods:
        raise ValueError("Xcode's enumeration file contains no recognizable XCTest methods.")
    return methods


def test_counts(summary: dict) -> dict:
    names = ("totalTestCount", "passedTests", "failedTests", "skippedTests", "expectedFailures")
    if any(type(summary.get(name)) is not int or summary[name] < 0 for name in names):
        raise ValueError("Unrecognized xcresulttool summary: refusing to infer missing test counts.")
    return {
        "total": summary["totalTestCount"],
        "executed": summary["passedTests"] + summary["failedTests"] + summary["expectedFailures"],
        "passed": summary["passedTests"], "failed": summary["failedTests"],
        "skipped": summary["skippedTests"], "expected_failures": summary["expectedFailures"],
    }


def require_complete_tests(discovered: list[str], expected: list[str], counts: dict) -> None:
    if len(expected) != len(set(expected)):
        raise ValueError("Duplicate test method names: update the enumeration parser to use full identifiers.")
    if set(discovered) != set(expected):
        raise ValueError(f"Xcode discovery differs from sources. Missing: {sorted(set(expected)-set(discovered))}; extra: {sorted(set(discovered)-set(expected))}")
    if (counts["total"] != len(discovered) or counts["executed"] != len(discovered)
            or counts["passed"] != len(discovered) or counts["failed"] != 0
            or counts["skipped"] != 0 or counts["expected_failures"] != 0):
        raise ValueError(f"Not all {len(discovered)} discovered tests executed and passed: {counts}")
