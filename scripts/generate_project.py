"""Deterministic Xcode project generator. Python stdlib only; no XcodeGen dependency."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "MiDinero.xcodeproj"


def identifier(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()[:24].upper()


def quote(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def generate() -> dict[str, str]:
    objects: dict[str, str] = {}

    def add(key: str, isa: str, fields: str) -> str:
        object_id = identifier(key)
        if object_id in objects:
            raise ValueError(f"Duplicate object: {key}")
        objects[object_id] = f"{{ isa = {isa}; {fields} }}"
        return object_id

    def refs(values: list[str]) -> str:
        return "(" + ", ".join(values) + ("," if values else "") + ")"

    app_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "MiDinero").rglob("*.swift"))
    test_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "MiDineroTests").rglob("*.swift"))
    ui_sources = sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / "MiDineroUITests").rglob("*.swift"))
    resources = ["MiDinero/Resources/Assets.xcassets", "MiDinero/Resources/PrivacyInfo.xcprivacy"]
    all_files = app_sources + test_sources + ui_sources + resources + ["MiDinero/Resources/Info.plist"]
    file_ids = {}
    for path in all_files:
        kind = "sourcecode.swift" if path.endswith(".swift") else (
            "folder.assetcatalog" if path.endswith(".xcassets") else "text.plist.xml"
        )
        file_ids[path] = add("file:" + path, "PBXFileReference",
                             f"lastKnownFileType = {kind}; path = {quote(path)}; sourceTree = \"<group>\";")

    product_ids = []
    target_ids = {}
    for name, sources, product_type in [
        ("MiDinero", app_sources, "application"),
        ("MiDineroTests", test_sources, "bundle.unit-test"),
        ("MiDineroUITests", ui_sources, "bundle.ui-testing"),
    ]:
        is_app = name == "MiDinero"
        suffix = ".app" if is_app else ".xctest"
        product_id = add("product:" + name, "PBXFileReference",
                         f"explicitFileType = {'wrapper.application' if is_app else 'wrapper.cfbundle'}; "
                         f"includeInIndex = 0; path = {name + suffix}; sourceTree = BUILT_PRODUCTS_DIR;")
        product_ids.append(product_id)
        source_build_ids = [add("build:" + path, "PBXBuildFile", f"fileRef = {file_ids[path]};") for path in sources]
        source_phase = add("sources:" + name, "PBXSourcesBuildPhase",
                           f"buildActionMask = 2147483647; files = {refs(source_build_ids)}; runOnlyForDeploymentPostprocessing = 0;")
        resource_ids = [add("resource:" + path, "PBXBuildFile", f"fileRef = {file_ids[path]};") for path in resources] if is_app else []
        resource_phase = add("resources:" + name, "PBXResourcesBuildPhase",
                             f"buildActionMask = 2147483647; files = {refs(resource_ids)}; runOnlyForDeploymentPostprocessing = 0;")
        framework_phase = add("frameworks:" + name, "PBXFrameworksBuildPhase",
                              "buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
        configs = []
        for configuration in ["Debug", "Release"]:
            settings = {
                "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1",
                "MARKETING_VERSION": "0.1.0", "PRODUCT_NAME": "$(TARGET_NAME)",
                "PRODUCT_BUNDLE_IDENTIFIER": "com.eduardo.MiDinero" + ("" if is_app else "." + name),
                "TARGETED_DEVICE_FAMILY": "1", "SWIFT_VERSION": "5.0",
                "SWIFT_STRICT_CONCURRENCY": "complete", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
                "OTHER_SWIFT_FLAGS": "$(inherited) -enable-upcoming-feature InferSendableFromCaptures",
                "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
                "SKIP_INSTALL": "NO" if is_app else "YES",
                "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
            }
            if is_app:
                settings.update({"GENERATE_INFOPLIST_FILE": "NO", "INFOPLIST_FILE": "MiDinero/Resources/Info.plist",
                                 "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                                 "SWIFT_EMIT_LOC_STRINGS": "YES", "ENABLE_PREVIEWS": "YES",
                                 "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "NO"})
            else:
                settings["GENERATE_INFOPLIST_FILE"] = "YES"
                settings["LD_RUNPATH_SEARCH_PATHS"] += " @loader_path/Frameworks"
                if name == "MiDineroTests":
                    settings["BUNDLE_LOADER"] = "$(TEST_HOST)"
                    settings["TEST_HOST"] = "$(BUILT_PRODUCTS_DIR)/MiDinero.app/MiDinero"
                else:
                    settings["TEST_TARGET_NAME"] = "MiDinero"
            fields = " ".join(f"{k} = {quote(v)};" for k, v in sorted(settings.items()))
            configs.append(add(f"config:{name}:{configuration}", "XCBuildConfiguration",
                               f"buildSettings = {{ {fields} }}; name = {configuration};"))
        config_list = add("configs:" + name, "XCConfigurationList",
                          f"buildConfigurations = {refs(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
        dependencies = []
        if not is_app:
            proxy = add("proxy:" + name, "PBXContainerItemProxy",
                        f"containerPortal = {identifier('project')}; proxyType = 1; remoteGlobalIDString = {identifier('target:MiDinero')}; remoteInfo = MiDinero;")
            dependencies.append(add("dependency:" + name, "PBXTargetDependency",
                                    f"target = {identifier('target:MiDinero')}; targetProxy = {proxy};"))
        target_ids[name] = add("target:" + name, "PBXNativeTarget",
                               f"buildConfigurationList = {config_list}; buildPhases = {refs([source_phase, framework_phase, resource_phase])}; "
                               f"buildRules = (); dependencies = {refs(dependencies)}; name = {name}; productName = {name}; "
                               f"productReference = {product_id}; productType = {quote('com.apple.product-type.' + product_type)};")
    groups = []
    for name, files in [("MiDinero", app_sources + resources + ["MiDinero/Resources/Info.plist"]),
                        ("MiDineroTests", test_sources), ("MiDineroUITests", ui_sources)]:
        groups.append(add("group:" + name, "PBXGroup", f"children = {refs([file_ids[p] for p in files])}; name = {name}; sourceTree = \"<group>\";"))
    products = add("products", "PBXGroup", f"children = {refs(product_ids)}; name = Products; sourceTree = \"<group>\";")
    root_group = add("mainGroup", "PBXGroup", f"children = {refs(groups + [products])}; sourceTree = \"<group>\";")
    project_configs = []
    for configuration in ["Debug", "Release"]:
        debug = configuration == "Debug"
        settings = {
            "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
            "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES", "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
            "ENABLE_STRICT_OBJC_MSGSEND": "YES", "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "DEBUG_INFORMATION_FORMAT": "dwarf" if debug else "dwarf-with-dsym",
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if debug else "-O",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)" if debug else "$(inherited)",
            "SWIFT_COMPILATION_MODE": "incremental" if debug else "wholemodule",
            "ENABLE_TESTABILITY": "YES" if debug else "NO", "ONLY_ACTIVE_ARCH": "YES" if debug else "NO",
            "COPY_PHASE_STRIP": "NO" if debug else "YES",
        }
        fields = " ".join(f"{k} = {quote(v)};" for k, v in sorted(settings.items()))
        project_configs.append(add("projectConfig:" + configuration, "XCBuildConfiguration",
                                   f"buildSettings = {{ {fields} }}; name = {configuration};"))
    project_config_list = add("projectConfigs", "XCConfigurationList",
                              f"buildConfigurations = {refs(project_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
    attributes = " ".join(f"{tid} = {{ CreatedOnToolsVersion = 16.0;" +
                          (f" TestTargetID = {target_ids['MiDinero']};" if name != "MiDinero" else "") + " };"
                          for name, tid in target_ids.items())
    add("project", "PBXProject",
        f"attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {attributes} }}; }}; "
        f"buildConfigurationList = {project_config_list}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = es; "
        f"hasScannedForEncodings = 0; knownRegions = (es, Base); mainGroup = {root_group}; productRefGroup = {products}; "
        f"projectDirPath = \"\"; projectRoot = \"\"; targets = {refs(list(target_ids.values()))};")
    pbx = "// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n"
    pbx += "\n".join(f"\t\t{key} = {value};" for key, value in sorted(objects.items()))
    pbx += f"\n\t}};\n\trootObject = {identifier('project')};\n}}\n"

    def reference(name: str) -> str:
        return (f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[name]}" '
                f'BuildableName="{name + (".app" if name == "MiDinero" else ".xctest")}" '
                f'BlueprintName="{escape(name)}" ReferencedContainer="container:MiDinero.xcodeproj"/>')

    build_entries = "".join(
        f'<BuildActionEntry buildForTesting="YES" buildForRunning="{"YES" if name == "MiDinero" else "NO"}" '
        f'buildForProfiling="{"YES" if name == "MiDinero" else "NO"}" buildForArchiving="{"YES" if name == "MiDinero" else "NO"}" '
        f'buildForAnalyzing="YES">{reference(name)}</BuildActionEntry>' for name in target_ids
    )
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>{build_entries}</BuildActionEntries></BuildAction>
  <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="NO">
    <EnvironmentVariables><EnvironmentVariable key="MIDINERO_UI_TEST_STORE" value="B08991D7-2B7B-4A47-9B3C-411D22BC725B" isEnabled="YES"/></EnvironmentVariables>
    <Testables><TestableReference skipped="NO" parallelizable="NO">{reference('MiDineroTests')}</TestableReference><TestableReference skipped="NO" parallelizable="NO">{reference('MiDineroUITests')}</TestableReference></Testables>
  </TestAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('MiDinero')}</BuildableProductRunnable></LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('MiDinero')}</BuildableProductRunnable></ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    return {"project.pbxproj": pbx, "xcshareddata/xcschemes/MiDinero.xcscheme": scheme,
            "project.xcworkspace/contents.xcworkspacedata": '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="self:"/></Workspace>\n'}


if __name__ == "__main__":
    for path, contents in generate().items():
        destination = PROJECT / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(contents, encoding="utf-8", newline="\n")
        print(f"Generated {destination.relative_to(ROOT)}")
