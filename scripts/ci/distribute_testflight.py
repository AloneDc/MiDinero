"""Future manual CI distribution. Never run with fabricated signing material.

Apple Distribution p12 + App Store provisioning profile + team ASC API key.
No developer account passwords, third-party signing service or Fastlane needed.
"""
import base64
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shutil
import subprocess
import sys

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
    # The work directory is fixed under RUNNER_TEMP. Profile path was written by us.
    marker = work / 'installed-profile.txt'
    if marker.exists():
        profile = Path(marker.read_text())
        allowed = Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles'
        if profile.parent == allowed and re.fullmatch(r'[A-Fa-f0-9-]+\.mobileprovision', profile.name):
            profile.unlink(missing_ok=True)
    prior = work / 'prior-keychains.json'
    if prior.exists():
        subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', *json.loads(prior.read_text())],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    subprocess.run(['security', 'delete-keychain', str(work / 'signing.keychain-db')],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    shutil.rmtree(work)


def distribute(work: Path) -> None:
    names = ('BUILD_NUMBER', 'APP_BUNDLE_ID', 'APPLE_TEAM_ID', 'APPLE_DISTRIBUTION_P12_BASE64',
             'APPLE_DISTRIBUTION_P12_PASSWORD', 'APPSTORE_PROFILE_BASE64', 'ASC_KEY_ID',
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
    certificate = work / 'distribution.p12'
    profile_file = work / 'appstore.mobileprovision'
    keys = work / 'private_keys'
    keys.mkdir()
    for name, destination in (
        ('APPLE_DISTRIBUTION_P12_BASE64', certificate), ('APPSTORE_PROFILE_BASE64', profile_file),
        ('ASC_PRIVATE_KEY_BASE64', keys / f"AuthKey_{env['ASC_KEY_ID']}.p8"),
    ):
        destination.write_bytes(base64.b64decode(env[name], validate=True))
    profile = plistlib.loads(run(['security', 'cms', '-D', '-i', str(profile_file)], capture=True))
    entitlement = profile.get('Entitlements', {})
    bundle = env['APP_BUNDLE_ID']
    team = env['APPLE_TEAM_ID']
    # Prefix need not equal Team ID for older developer accounts.
    prefixes = profile.get('ApplicationIdentifierPrefix', [])
    if (profile.get('TeamIdentifier') != [team]
            or entitlement.get('application-identifier') not in [prefix + '.' + bundle for prefix in prefixes]
            or entitlement.get('com.apple.developer.team-identifier') != team
            or entitlement.get('get-task-allow') is not False
            or profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices')
            or not profile.get('DeveloperCertificates')):
        raise RuntimeError('Expected an App Store distribution profile for this exact bundle and Team.')
    if profile['ExpirationDate'].replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc):
        raise RuntimeError('Provisioning profile expired.')
    uuid = profile['UUID']
    if not re.fullmatch(r'[A-Fa-f0-9-]{36}', uuid):
        raise RuntimeError('Invalid profile UUID.')
    profiles = Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles'
    profiles.mkdir(parents=True, exist_ok=True)
    installed = profiles / f'{uuid}.mobileprovision'
    if installed.exists():
        raise RuntimeError('Refusing to replace an existing provisioning profile.')
    (work / 'installed-profile.txt').write_text(str(installed))
    shutil.copyfile(profile_file, installed)
    keychain = work / 'signing.keychain-db'
    password = secrets.token_urlsafe(32)
    prior = re.findall(r'"([^"]+)"', run(['security', 'list-keychains', '-d', 'user'], capture=True).decode())
    (work / 'prior-keychains.json').write_text(json.dumps(prior))
    run(['security', 'create-keychain', '-p', password, str(keychain)], capture=True)
    run(['security', 'set-keychain-settings', '-lut', '21600', str(keychain)], capture=True)
    run(['security', 'unlock-keychain', '-p', password, str(keychain)], capture=True)
    run(['security', 'import', str(certificate), '-P', env['APPLE_DISTRIBUTION_P12_PASSWORD'],
         '-t', 'cert', '-f', 'pkcs12', '-k', str(keychain), '-T', '/usr/bin/codesign', '-T', '/usr/bin/security'], capture=True)
    run(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:,codesign:', '-k', password, str(keychain)], capture=True)
    run(['security', 'list-keychains', '-d', 'user', '-s', str(keychain), *prior], capture=True)
    identities = run(['security', 'find-identity', '-v', '-p', 'codesigning', str(keychain)], capture=True).decode()
    if 'Apple Distribution:' not in identities:
        raise RuntimeError('The p12 must contain a valid Apple Distribution identity AND its private key.')
    archive = work / 'MiDinero.xcarchive'
    export = work / 'export'
    options = work / 'ExportOptions.plist'
    options.write_bytes(plistlib.dumps({
        'method': 'app-store-connect', 'destination': 'export', 'teamID': team,
        'signingStyle': 'manual', 'signingCertificate': 'Apple Distribution',
        'provisioningProfiles': {bundle: uuid}, 'manageAppVersionAndBuildNumber': False,
        'stripSwiftSymbols': True, 'uploadSymbols': True,
    }))
    # Archive compiles and signs the Release app. No automatic profile creation.
    print('Archiving Release with real distribution signing.', flush=True)
    run(['xcodebuild', '-project', 'MiDinero.xcodeproj', '-scheme', 'MiDinero',
         '-configuration', 'Release', '-destination', 'generic/platform=iOS',
         '-derivedDataPath', str(work / 'DerivedData'), '-archivePath', str(archive),
         'CODE_SIGN_STYLE=Manual', 'CODE_SIGN_IDENTITY=Apple Distribution',
         f'DEVELOPMENT_TEAM={team}', f'PRODUCT_BUNDLE_IDENTIFIER={bundle}',
         f'PROVISIONING_PROFILE_SPECIFIER={uuid}', f"CURRENT_PROJECT_VERSION={env['BUILD_NUMBER']}",
         'archive'])
    run(['codesign', '--verify', '--deep', '--strict', str(archive / 'Products/Applications/MiDinero.app')])
    print('Exporting signed IPA.', flush=True)
    run(['xcodebuild', '-exportArchive', '-archivePath', str(archive), '-exportPath', str(export),
         '-exportOptionsPlist', str(options)])
    ipas = list(export.glob('*.ipa'))
    if len(ipas) != 1:
        raise RuntimeError('Expected exactly one signed IPA.')
    # altool supports API-key auth. The key directory contains only this run's p8.
    os.environ['API_PRIVATE_KEYS_DIR'] = str(keys)
    print('Validating and uploading IPA to App Store Connect.', flush=True)
    auth = ['--api-key', env['ASC_KEY_ID'], '--api-issuer', env['ASC_ISSUER_ID']]
    for operation in ('--validate-app', '--upload-app'):
        run(['xcrun', 'altool', operation, '--file', str(ipas[0]), '-t', 'ios', *auth])
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
        stream.write('## TestFlight upload\n\nSigned archive, IPA export and upload completed. '
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
