"""Unsigned device validation. A valid xcarchive is NOT a signed/installable IPA."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import sys

from validate_xcode import ROOT, Validation

EVIDENCE = ROOT / 'build/device-evidence'
ARCHIVE = ROOT / 'build/device/MiDinero.xcarchive'


class DeviceValidation(Validation):
    def __init__(self) -> None:
        super().__init__(EVIDENCE)
        self.result.pop('tests')
        self.result.pop('discovered_tests')
        self.result['states'] = {
            'BUILDABLE': 'NOT_VERIFIED', 'ARCHIVABLE': 'NOT_VERIFIED',
            'SIGNABLE': 'NOT_VERIFIED_NO_CREDENTIALS',
            'DISTRIBUTABLE': 'NO_UNSIGNED_ARCHIVE', 'TESTFLIGHT_READY': 'NO_NOT_UPLOADED',
        }

    def execute(self) -> None:
        if sys.platform != 'darwin':
            raise RuntimeError('A real Mac with Xcode is required; no device build executed.')
        self.result['status'] = 'DEVICE_VALIDATION_FAILED'
        self.command('macos', ['sw_vers'])
        self.command('architecture', ['uname', '-m'])
        self.command('revision', ['git', 'rev-parse', 'HEAD'])
        self.result['developer_dir'] = os.environ.get('DEVELOPER_DIR')
        xcode = self.command('xcode-version', ['xcodebuild', '-version'])
        self.command('swift-version', ['xcrun', 'swift', '--version'])
        sdk = self.command('sdk-version', ['xcrun', '--sdk', 'iphoneos', '--show-sdk-version']).strip()
        if int(re.search(r'Xcode (\d+)', xcode)[1]) < 26 or int(sdk.split('.')[0]) < 26:
            raise RuntimeError('Device distribution validation requires Xcode 26+ / iOS SDK 26+.')
        self.command('sdks', ['xcodebuild', '-showsdks'])
        self.command('export-help', ['xcodebuild', '-help'])
        self.command('upload-help', ['xcrun', 'altool', '--help'])
        base = ['xcodebuild', '-project', 'MiDinero.xcodeproj', '-scheme', 'MiDinero',
                '-configuration', 'Release', '-destination', 'generic/platform=iOS',
                '-derivedDataPath', str(ROOT / 'build/Device-DerivedData'),
                'CODE_SIGNING_ALLOWED=NO', 'CODE_SIGNING_REQUIRED=NO', 'CODE_SIGN_IDENTITY=',
                'SWIFT_STRICT_CONCURRENCY=complete']
        self.command('build-settings', base + ['-showBuildSettings'])
        self.command('device-release-build', base + ['-resultBundlePath', str(EVIDENCE / 'DeviceBuild.xcresult'), 'build'])
        self.result['states']['BUILDABLE'] = 'VERIFIED_RELEASE_IPHONEOS'
        self.command('device-archive', base + ['-archivePath', str(ARCHIVE),
                     '-resultBundlePath', str(EVIDENCE / 'Archive.xcresult'), 'archive'])
        self.validate_structure()
        # tar preserves bundle modes/symlinks. No signed provisioning material exists.
        tar = EVIDENCE / 'MiDinero-unsigned.xcarchive.tar.gz'
        self.command('package-unsigned-archive', ['tar', '-czf', str(tar), '-C', str(ARCHIVE.parent), ARCHIVE.name])
        self.result['archive_sha256'] = hashlib.sha256(tar.read_bytes()).hexdigest()
        self.result['states']['ARCHIVABLE'] = 'VERIFIED_UNSIGNED_DEVICE_ARCHIVE'
        self.result['status'] = 'DEVICE_BUILD_AND_UNSIGNED_ARCHIVE_VERIFIED'

    def validate_structure(self) -> None:
        def read(path: Path) -> dict:
            with path.open('rb') as stream:
                return plistlib.load(stream)

        def require(condition: bool, message: str) -> None:
            if not condition:
                raise RuntimeError('Archive structure: ' + message)

        archive_info = read(ARCHIVE / 'Info.plist')
        properties = archive_info.get('ApplicationProperties', {})
        require(properties.get('ApplicationPath') == 'Applications/MiDinero.app', 'not an application archive')
        app = ARCHIVE / 'Products/Applications/MiDinero.app'
        info = read(app / 'Info.plist')
        require(info.get('CFBundleIdentifier') == 'com.eduardo.MiDinero', 'bundle ID mismatch')
        require(info.get('CFBundleShortVersionString') == '0.1.0', 'version mismatch')
        require(info.get('CFBundleVersion') == '1', 'build number mismatch')
        require(info.get('CFBundleDisplayName') == 'MiDinero', 'display name mismatch')
        require(info.get('MinimumOSVersion') == '17.0', 'minimum OS changed')
        require(info.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'not an iPhoneOS binary')
        require(info.get('UIDeviceFamily') == [1], 'not iPhone only')
        require(info.get('ITSAppUsesNonExemptEncryption') is False, 'encryption declaration missing')
        require(info.get('CFBundleIcons', {}).get('CFBundlePrimaryIcon', {}).get('CFBundleIconName') == 'AppIcon', 'icon not compiled')
        require((app / 'Assets.car').is_file(), 'missing asset catalog')
        require(not (app / 'embedded.mobileprovision').exists(), 'unexpected provisioning profile')
        require(not (app / '_CodeSignature').exists(), 'unexpected code signature')
        require(not (app / 'PlugIns').exists(), 'unexpected extension/test bundle')
        privacy = read(app / 'PrivacyInfo.xcprivacy')
        require(privacy.get('NSPrivacyTracking') is False and privacy.get('NSPrivacyCollectedDataTypes') == [], 'privacy manifest mismatch')
        metadata = app / 'Metadata.appintents'
        require(metadata.is_dir(), 'missing App Intents metadata')
        metadata_files = [p for p in metadata.rglob('*') if p.is_file()]
        require(bool(metadata_files), 'empty App Intents metadata')
        # Metadata is generated by Apple, never invented as a source fixture.
        metadata_data = b'\n'.join(p.read_bytes() for p in metadata_files)
        require(b'RegisterExpenseIntent' in metadata_data, 'intent not extracted')
        binary = app / info['CFBundleExecutable']
        architectures = self.command('binary-architectures', ['xcrun', 'lipo', '-archs', str(binary)]).strip()
        require(architectures == 'arm64', 'wrong device architecture: ' + architectures)
        self.command('binary-platform', ['xcrun', 'vtool', '-show-build', str(binary)])
        linked = self.command('linked-frameworks', ['xcrun', 'otool', '-L', str(binary)])
        for framework in ('SwiftData', 'AppIntents', 'Charts', 'SwiftUI'):
            require(f'/{framework}.framework/' in linked, 'missing native framework: ' + framework)
        self.command('code-signature', ['codesign', '-dvv', str(app)], required=False)
        require(self.result['commands'][-1]['exit_code'] != 0, 'archive unexpectedly signed')
        dsym = ARCHIVE / 'dSYMs/MiDinero.app.dSYM'
        require(dsym.is_dir(), 'missing dSYM')
        binary_uuid = self.command('binary-uuid', ['xcrun', 'dwarfdump', '--uuid', str(binary)])
        dsym_uuid = self.command('dsym-uuid', ['xcrun', 'dwarfdump', '--uuid', str(dsym)])
        require(re.findall(r'UUID: ([A-F0-9-]+)', binary_uuid) == re.findall(r'UUID: ([A-F0-9-]+)', dsym_uuid), 'dSYM UUID mismatch')
        self.result['structure'] = {'archive_properties': properties, 'app_info': info,
                                    'privacy': privacy, 'architectures': architectures,
                                    'intent_metadata_files': [p.relative_to(app).as_posix() for p in metadata_files]}
        # Keep inspectable metadata even after the transient CI artifact expires.
        self.command('copy-intent-evidence', ['ditto', str(metadata), str(EVIDENCE / 'Metadata.appintents')])
        self.save()

    def finish(self) -> None:
        warnings = set()
        for log in EVIDENCE.glob('*.log'):
            warnings.update(line for line in log.read_text(errors='replace').splitlines() if 'warning:' in line.lower())
        self.result['warnings'] = sorted(warnings)
        self.result['finished_at'] = datetime.now(timezone.utc).isoformat()
        self.save()
        markdown = '# Device readiness\n\n' + '\n'.join(f'- {key}: **{value}**' for key, value in self.result['states'].items())
        markdown += f"\n\nError: {self.result['error'] or 'none'}\n\nUnsigned archive cannot be installed on an iPhone or uploaded to TestFlight.\n"
        (EVIDENCE / 'SUMMARY.md').write_text(markdown, encoding='utf-8')
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
                stream.write(markdown)
        print(markdown)


if __name__ == '__main__':
    if EVIDENCE.exists() or ARCHIVE.exists():
        raise SystemExit('Move previous device evidence/archive aside before running again.')
    EVIDENCE.mkdir(parents=True)
    validation = DeviceValidation()
    try:
        validation.execute()
    except (Exception, KeyboardInterrupt) as error:
        validation.result['error'] = str(error)
    finally:
        validation.finish()
    raise SystemExit(0 if validation.result['status'] == 'DEVICE_BUILD_AND_UNSIGNED_ARCHIVE_VERIFIED' else 1)
