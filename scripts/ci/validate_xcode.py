"""Real Xcode pipeline shared by GitHub Actions and local macOS. Python stdlib only."""
from __future__ import annotations

import json
import os
from pathlib import Path
import platform
import re
import shlex
import signal
import subprocess
import sys
import threading
from datetime import datetime, timezone

from xcode_evidence import discovered_methods, require_complete_tests, select_simulator, test_counts

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT / "build/ci-evidence"
DERIVED = ROOT / "build/CI-DerivedData"


class Validation:
    def __init__(self) -> None:
        self.result = {
            "status": "NOT_EXECUTED_ON_MACOS", "started_at": datetime.now(timezone.utc).isoformat(),
            "host": platform.platform(), "commands": [], "tests": None, "discovered_tests": None,
            "error": None, "warnings": [], "run_url": None,
        }
        if os.environ.get("GITHUB_RUN_ID"):
            self.result["run_url"] = f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}"

    def command(self, name: str, args: list[str], *, required: bool = True, timeout: int = 600) -> str:
        print(f"\n$ {shlex.join(args)}", flush=True)
        entry = {"name": name, "argv": args, "exit_code": None, "timeout_seconds": timeout}
        self.result["commands"].append(entry)
        chunks = []
        with (EVIDENCE / f"{name}.log").open("w", encoding="utf-8") as log:
            process = subprocess.Popen(args, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding="utf-8", errors="replace", start_new_session=True)
            def terminate() -> None:
                entry["timed_out"] = True
                print(f"{name} exceeded {timeout} seconds; stopping its process group.", flush=True)
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            watchdog = threading.Timer(timeout, terminate)
            watchdog.start()
            assert process.stdout is not None
            try:
                for line in process.stdout:
                    print(line, end="", flush=True)
                    log.write(line)
                    log.flush()
                    chunks.append(line)
                entry["exit_code"] = process.wait()
            finally:
                watchdog.cancel()
        self.save()
        if required and entry["exit_code"]:
            raise RuntimeError(f"{name} exited {entry['exit_code']}; see {name}.log")
        return "".join(chunks)

    def save(self) -> None:
        (EVIDENCE / "result.json").write_text(json.dumps(self.result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    def json_command(self, name: str, args: list[str], *, required: bool = True) -> dict:
        raw = self.command(name, args, required=required)
        value = json.loads(raw)
        (EVIDENCE / f"{name}.json").write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
        return value

    def execute(self) -> None:
        if sys.platform != "darwin":
            raise RuntimeError("A real macOS host with Xcode is required. No build or test was executed.")
        self.command("macos", ["sw_vers"])
        self.command("architecture", ["uname", "-m"])
        self.command("developer-directory", ["xcode-select", "-p"])
        xcode = self.command("xcode-version", ["xcodebuild", "-version"])
        self.command("swift-version", ["swift", "--version"])
        sdk_version = self.command("sdk-version", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-version"]).strip()
        self.command("sdk-path", ["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"])
        self.command("sdks", ["xcodebuild", "-showsdks"])
        self.command("revision", ["git", "rev-parse", "HEAD"])
        version = re.search(r"Xcode (\d+)", xcode)
        if not version or int(version[1]) < 16:
            raise RuntimeError("This evidence pipeline requires Xcode >= 16 for xcresulttool test summaries.")
        self.command("targets-and-schemes", ["xcodebuild", "-list", "-project", "MiDinero.xcodeproj"])
        base = ["xcodebuild", "-project", "MiDinero.xcodeproj", "-scheme", "MiDinero"]
        inventory = self.json_command("simulators", ["xcrun", "simctl", "list", "--json"])
        destinations = self.command("destinations", base + ["-sdk", "iphonesimulator", "-showdestinations"])
        device = select_simulator(inventory, destinations, os.environ.get("SIMULATOR_ID"), sdk_version)
        self.result["simulator"] = device
        print(f"Selected available destination: {device['name']} / iOS {device['runtimeVersion']} / {device['udid']}")
        if device["state"] != "Booted":
            self.command("simulator-boot", ["xcrun", "simctl", "boot", device["udid"]])
        self.command("simulator-ready", ["xcrun", "simctl", "bootstatus", device["udid"], "-b"], timeout=300)
        self.command("destinations-after-boot", base + ["-sdk", "iphonesimulator", "-showdestinations"])
        self.command("build-settings", base + ["-sdk", "iphonesimulator", "-showBuildSettings"])
        options = ["-configuration", "Debug", "-destination", f"platform=iOS Simulator,id={device['udid']}",
                   "-destination-timeout", "120", "-derivedDataPath", str(DERIVED),
                   "CODE_SIGNING_ALLOWED=NO", "SWIFT_STRICT_CONCURRENCY=complete"]
        self.result["status"] = "BUILD_FAILED"
        self.command("build", base + options + ["-resultBundlePath", str(EVIDENCE / "Build.xcresult"), "build"])
        self.command("build-for-testing", base + options + ["-resultBundlePath", str(EVIDENCE / "BuildForTesting.xcresult"), "build-for-testing"])
        self.result["status"] = "COMPILED_TESTS_FAILED"
        enumeration = EVIDENCE / "discovered-tests.txt"
        self.command("enumerate-tests", base + options + ["test-without-building", "-enumerate-tests",
                     "-test-enumeration-style", "flat", "-test-enumeration-format", "text",
                     "-test-enumeration-output-path", str(enumeration)])
        discovered = discovered_methods(enumeration.read_text(encoding="utf-8"))
        self.result["discovered_tests"] = discovered
        # Source methods are ONLY the expected inventory, not Xcode discovery.
        expected = []
        for folder in ("MiDineroTests", "MiDineroUITests"):
            for source in (ROOT / folder).rglob("*.swift"):
                expected.extend(re.findall(r"\bfunc (test[A-Z]\w*)\s*\(", source.read_text(encoding="utf-8")))
        self.result["expected_source_tests"] = sorted(expected)
        self.command("tests", base + options + ["-parallel-testing-enabled", "NO", "-maximum-concurrent-test-simulator-destinations", "1",
                     "-resultBundlePath", str(EVIDENCE / "Tests.xcresult"), "test-without-building"], required=False, timeout=900)
        test_exit = self.result["commands"][-1]["exit_code"]
        summary = self.json_command("test-summary", ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(EVIDENCE / "Tests.xcresult")])
        self.result["tests"] = test_counts(summary)
        self.json_command("test-details", ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", str(EVIDENCE / "Tests.xcresult")])
        self.command("test-attachments", ["xcrun", "xcresulttool", "export", "attachments", "--path", str(EVIDENCE / "Tests.xcresult"),
                     "--output-path", str(EVIDENCE / "attachments")])
        require_complete_tests(discovered, expected, self.result["tests"])
        if test_exit != 0:
            raise RuntimeError(f"xcodebuild test-without-building returned {test_exit}, even though test counts were parsed.")
        self.result["status"] = "BUILD_FAILED"
        self.command("release-build", base + ["-configuration", "Release", "-destination", "generic/platform=iOS Simulator",
                     "-derivedDataPath", str(DERIVED), "CODE_SIGNING_ALLOWED=NO", "SWIFT_STRICT_CONCURRENCY=complete",
                     "-resultBundlePath", str(EVIDENCE / "Release.xcresult"), "build"])
        self.result["status"] = "COMPILED_AND_TESTED"

    def finish(self) -> None:
        # Preserve SDK diagnostics without suppressing concurrency warnings.
        warnings = set()
        errors = set()
        for log in EVIDENCE.glob("*.log"):
            for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
                if re.search(r"\bwarning:", line, re.I):
                    warnings.add(line)
                if re.search(r"\berror:", line, re.I):
                    errors.add(line)
        self.result["warnings"] = sorted(warnings)
        self.result["compiler_error_lines"] = sorted(errors)
        self.result["finished_at"] = datetime.now(timezone.utc).isoformat()
        self.save()
        report = ["# Xcode validation", "", f"Status: **{self.result['status']}**", "",
                  f"Run: {self.result['run_url'] or 'local'}", "",
                  f"Discovered by Xcode: {len(self.result['discovered_tests']) if self.result['discovered_tests'] is not None else 'unknown'}", "",
                  f"Executed / passed / failed / skipped: {self.result['tests'] or 'unknown; no xcresult summary'}", "",
                  f"Distinct warning diagnostics: {len(warnings)}", "",
                  f"Pipeline error: {self.result['error'] or 'none'}", "",
                  "Raw commands, exit codes, complete logs and .xcresult bundles are in the artifact.", ""]
        markdown = "\n".join(report)
        (EVIDENCE / "SUMMARY.md").write_text(markdown, encoding="utf-8")
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
                summary.write(markdown)
        print(markdown)


def main() -> int:
    # Never overwrite artifacts from a previous local attempt.
    if EVIDENCE.exists():
        print(f"Evidence directory already exists: {EVIDENCE}. Move it aside before another local run.", file=sys.stderr)
        return 2
    EVIDENCE.mkdir(parents=True)
    validation = Validation()
    try:
        validation.execute()
    except (Exception, KeyboardInterrupt) as error:
        validation.result["error"] = str(error)
    finally:
        validation.finish()
    return 0 if validation.result["status"] == "COMPILED_AND_TESTED" else 1


if __name__ == "__main__":
    raise SystemExit(main())
