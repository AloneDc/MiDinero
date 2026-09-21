"""Structural checks only. This does NOT compile, type-check Swift or run XCTest."""
from __future__ import annotations

import json
import plistlib
import re
import struct
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from generate_project import generate, identifier

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    checks = 0

    def check(condition: bool, message: str) -> None:
        nonlocal checks
        if not condition:
            raise AssertionError(message)
        checks += 1

    for relative, expected in generate().items():
        path = ROOT / "MiDinero.xcodeproj" / relative
        check(path.read_text(encoding="utf-8") == expected, f"Project drift: {relative}")
    pbx = (ROOT / "MiDinero.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    definitions = re.findall(r"^\s*([A-F0-9]{24}) = \{ isa =", pbx, re.M)
    check(len(definitions) == len(set(definitions)), "Duplicate PBX object IDs")
    references = set(re.findall(r"\b[A-F0-9]{24}\b", pbx))
    check(references == set(definitions), "Unresolved PBX references")
    for folder in ("MiDinero", "MiDineroTests", "MiDineroUITests"):
        for source in sorted((ROOT / folder).rglob("*.swift")):
            relative = source.relative_to(ROOT).as_posix()
            check(identifier("file:" + relative) in definitions, f"Missing target file: {relative}")
            check(identifier("build:" + relative) in definitions, f"Missing build source: {relative}")
    for path in (ROOT / "MiDinero/Resources").rglob("*.plist"):
        with path.open("rb") as file:
            plistlib.load(file)
        check(True, str(path))
    privacy_path = ROOT / "MiDinero/Resources/PrivacyInfo.xcprivacy"
    with privacy_path.open("rb") as file:
        privacy = plistlib.load(file)
    check(privacy["NSPrivacyTracking"] is False, "Tracking enabled")
    check(privacy["NSPrivacyCollectedDataTypes"] == [], "Unexpected data collection")
    for path in (ROOT / "MiDinero.xcodeproj").rglob("*"):
        if path.suffix in (".xcscheme", ".xcworkspacedata"):
            ET.parse(path)
            check(True, str(path))
    for path in (ROOT / "MiDinero/Resources").rglob("*.json"):
        json.loads(path.read_text(encoding="utf-8"))
        check(True, str(path))
    icon = (ROOT / "MiDinero/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
    check(icon[:8] == b"\x89PNG\r\n\x1a\n", "Not a PNG")
    check(struct.unpack(">II", icon[16:24]) == (1024, 1024), "Icon must be 1024 square")
    check(icon[25] == 2, "Icon must be RGB without alpha")
    sources = list((ROOT / "MiDinero").rglob("*.swift"))
    text = "\n".join(p.read_text(encoding="utf-8") for p in sources)
    check("try!" not in text and "fatalError(" not in text, "Unsafe persistence fallback/crash")
    check(not re.search(r"\b(URLSession|WKWebView|Firebase|Supabase)\b", text), "Unexpected network/web implementation")
    domain = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "MiDinero/Domain").glob("*.swift"))
    check(not re.search(r"\b(Double|Float)\b", domain), "Floating point money in domain")
    check("cloudKitDatabase: .none" in text, "Missing explicit local-only store")
    check("requiresLocalDeviceAuthentication" in text, "Missing intent authentication")
    check('IPHONEOS_DEPLOYMENT_TARGET = "17.0"' in pbx, "Wrong deployment target")
    print(f"PASS: {checks} structural assertions. {len(sources)} app Swift files are included in the project.")

    if "--parse-project" in sys.argv:
        from openstep_parser import OpenStepDecoder
        project = OpenStepDecoder.ParseFromString(pbx)
        objects = project["objects"]
        root = objects[project["rootObject"]]
        check(root["isa"] == "PBXProject", "Invalid root object")
        check(len(root["targets"]) == 3, "Expected app, unit-test and UI-test targets")
        for target_id in root["targets"]:
            target = objects[target_id]
            check(target["isa"] == "PBXNativeTarget", "Invalid target")
            check(objects[target["productReference"]]["sourceTree"] == "BUILT_PRODUCTS_DIR", "Invalid product")
            for phase_id in target["buildPhases"]:
                phase = objects[phase_id]
                for build_id in phase["files"]:
                    file = objects[objects[build_id]["fileRef"]]
                    check((ROOT / file["path"]).exists(), f"Missing file: {file['path']}")
        print(f"PASS: independent OpenStep parser read {len(objects)} Xcode objects and all three targets; file references resolve.")

    if "--parse-swift" in sys.argv:
        try:
            import tree_sitter
            import tree_sitter_swift
        except ImportError as error:
            raise SystemExit("Install optional parser tools into .validation-tools; see docs/VALIDATION.md") from error
        parser = tree_sitter.Parser(tree_sitter.Language(tree_sitter_swift.language()))
        swift_files = sorted(ROOT.glob("MiDinero*/**/*.swift")) + [ROOT / "Package.swift"]
        errors = []
        for path in swift_files:
            data = path.read_bytes()
            tree = parser.parse(data)
            stack = [tree.root_node]
            while stack:
                node = stack.pop()
                if node.type == "ERROR" or node.is_missing:
                    errors.append(f"{path.relative_to(ROOT)}:{node.start_point.row + 1}: {node.type}: {data[node.start_byte:node.end_byte][:120]!r}")
                stack.extend(reversed(node.children))
        if errors:
            raise AssertionError("Swift grammar errors:\n" + "\n".join(errors))
        print(f"PASS: tree-sitter parsed {len(swift_files)} Swift files without ERROR/missing nodes. No type checking or macro expansion performed.")


if __name__ == "__main__":
    main()
