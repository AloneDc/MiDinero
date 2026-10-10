"""Archive without local signing assets; automatic cloud signing during export.

Team App Store Connect API key only. No p12 or manually supplied profile.
Cloud export and upload require real Apple permissions; CI alone cannot prove them.
"""
import base64
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def run(args: list[str], *, capture: bool = False) -> bytes:
    # Intentionally do not echo argv: security commands receive secret arguments.
    return subprocess.run(args, cwd=ROOT, check=True,
                          stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None).stdout or b''


def work_directory() -> Path:
    if sys.platform != 'darwin' or os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Distribution is restricted to the configured hosted macOS workflow.')
    return Path(os.environ['RUNNER_TEMP']).resolve() / 'midinero-signing'


def cleanup(work: Path) -> None:
    if not work.exists():
        return
    shutil.rmtree(work)


def distribute(work: Path) -> None:
    names = ('BUILD_NUMBER', 'APP_BUNDLE_ID', 'APPLE_TEAM_ID', 'ASC_KEY_ID',
             'ASC_ISSUER_ID', 'ASC_PRIVATE_KEY_BASE64')
    missing = [name for name in names if not os.environ.get(name)]
    if missing:
        raise RuntimeError('Missing real configuration: ' + ', '.join(missing))
    env = {name: os.environ[name] for name in names}
    if not re.fullmatch(r'[1-9][0-9]{0,3}(\.(0|[1-9][0-9]?)){0,2}', env['BUILD_NUMBER']):
        raise RuntimeError('BUILD_NUMBER must use Apple numeric CFBundleVersion syntax; use a new number.')
    if not re.fullmatch(r'[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+', env['APP_BUNDLE_ID']):
        raise RuntimeError('Invalid APP_BUNDLE_ID.')
    if not re.fullmatch(r'[A-Z0-9]{10}', env['APPLE_TEAM_ID']) or not re.fullmatch(r'[A-Z0-9]{10}', env['ASC_KEY_ID']):
        raise RuntimeError('Invalid Team ID or API Key ID.')
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', env['ASC_ISSUER_ID']):
        raise RuntimeError('Invalid team API Issuer ID.')
    xcode = run(['xcodebuild', '-version'], capture=True).decode()
    sdk = run(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], capture=True).decode().strip()
    if int(re.search(r'Xcode (\d+)', xcode)[1]) < 26 or int(sdk.split('.')[0]) < 26:
        raise RuntimeError('Apple uploads require Xcode 26+ and iOS SDK 26+ (recheck current requirements).')
    print(xcode, 'iOS SDK ' + sdk, flush=True)
    work.mkdir(mode=0o700)
    os.umask(0o077)
    keys = work / 'private_keys'
    keys.mkdir()
    key = keys / f"AuthKey_{env['ASC_KEY_ID']}.p8"
    key.write_bytes(base64.b64decode(env['ASC_PRIVATE_KEY_BASE64'], validate=True))
    # Verify the private key parses without printing its contents.
    run(['openssl', 'pkey', '-in', str(key), '-check', '-noout'], capture=True)
    bundle = env['APP_BUNDLE_ID']
    team = env['APPLE_TEAM_ID']
    authentication = ['-allowProvisioningUpdates', '-authenticationKeyPath', str(key),
                      '-authenticationKeyID', env['ASC_KEY_ID'],
                      '-authenticationKeyIssuerID', env['ASC_ISSUER_ID']]
    archive = work / 'MiDinero.xcarchive'
    export = work / 'export'
    options = work / 'ExportOptions.plist'
    options.write_bytes(plistlib.dumps({
        'method': 'app-store-connect', 'destination': 'export', 'teamID': team,
        'signingStyle': 'automatic', 'manageAppVersionAndBuildNumber': False,
        'stripSwiftSymbols': True, 'uploadSymbols': True,
    }))
    # This app has no custom entitlements or extensions. Archive unsigned so a
    # fresh hosted Mac needs neither a development certificate nor registered UDID.
    # Export uses Apple's cloud-managed distribution identity, never ad hoc signing.
    print('Archiving Release; distribution signing happens during export.', flush=True)
    run(['xcodebuild', '-project', 'MiDinero.xcodeproj', '-scheme', 'MiDinero',
         '-configuration', 'Release', '-destination', 'generic/platform=iOS',
         '-derivedDataPath', str(work / 'DerivedData'), '-archivePath', str(archive),
         'CODE_SIGN_STYLE=Automatic', 'CODE_SIGNING_ALLOWED=NO',
         f'DEVELOPMENT_TEAM={team}', f'PRODUCT_BUNDLE_IDENTIFIER={bundle}',
         f"CURRENT_PROJECT_VERSION={env['BUILD_NUMBER']}",
         'archive'])
    app = archive / 'Products/Applications/MiDinero.app'
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if (info.get('CFBundleIdentifier') != bundle or info.get('CFBundleVersion') != env['BUILD_NUMBER']
            or info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']):
        raise RuntimeError('Archive bundle, version or device platform mismatch.')
    if run(['xcrun', 'lipo', '-archs', str(app / info['CFBundleExecutable'])], capture=True).strip() != b'arm64':
        raise RuntimeError('Archive must contain an arm64 iPhone executable.')
    print('Exporting signed IPA.', flush=True)
    run(['xcodebuild', '-exportArchive', '-archivePath', str(archive), '-exportPath', str(export),
         '-exportOptionsPlist', str(options), *authentication])
    ipas = list(export.glob('*.ipa'))
    if len(ipas) != 1:
        raise RuntimeError('Expected exactly one signed IPA.')
    # Verify the actual exported distribution signature and provisioning profile
    # before sending the IPA to Apple. No archive/IPA/private logs are published.
    unpacked = work / 'ipa-validation'
    with zipfile.ZipFile(ipas[0]) as ipa:
        ipa.extractall(unpacked)
    apps = list((unpacked / 'Payload').glob('*.app'))
    if len(apps) != 1:
        raise RuntimeError('Expected one exported application.')
    run(['codesign', '--verify', '--deep', '--strict', str(apps[0])])
    profile = plistlib.loads(run(['security', 'cms', '-D', '-i',
                                 str(apps[0] / 'embedded.mobileprovision')], capture=True))
    entitlements = profile.get('Entitlements', {})
    if (profile.get('TeamIdentifier') != [team] or profile.get('ProvisionedDevices')
            or profile.get('ProvisionsAllDevices') or entitlements.get('get-task-allow') is not False
            or entitlements.get('beta-reports-active') is not True
            or entitlements.get('application-identifier') not in
            [prefix + '.' + bundle for prefix in profile.get('ApplicationIdentifierPrefix', [])]):
        raise RuntimeError('Export did not produce the expected App Store distribution profile.')
    # altool supports API-key auth. The key directory contains only this run's p8.
    os.environ['API_PRIVATE_KEYS_DIR'] = str(keys)
    print('Validating and uploading IPA to App Store Connect.', flush=True)
    auth = ['--api-key', env['ASC_KEY_ID'], '--api-issuer', env['ASC_ISSUER_ID']]
    for operation in ('--validate-app', '--upload-app'):
        run(['xcrun', 'altool', operation, '--file', str(ipas[0]), '-t', 'ios', *auth])
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
        stream.write('## TestFlight upload\n\nRelease archive, verified cloud-signed IPA export and upload completed. '
                     'Apple processing, export compliance, tester assignment and beta review are still checked in App Store Connect. '
                     'This does not prove installation or physical Shortcuts execution.\n')


if __name__ == '__main__':
    work = work_directory()
    if sys.argv[1:] == ['--cleanup']:
        cleanup(work)
    else:
        try:
            if work.exists():
                raise RuntimeError('Signing workspace already exists; clean the previous attempt first.')
            distribute(work)
        except Exception as error:
            # CalledProcessError includes argv/passwords: never stringify it.
            if isinstance(error, subprocess.CalledProcessError):
                print(f'Apple command failed with exit {error.returncode}; signing/upload NOT verified.', file=sys.stderr)
            else:
                print(f'Distribution stopped: {error}', file=sys.stderr)
            sys.exit(1)
        finally:
            cleanup(work)
