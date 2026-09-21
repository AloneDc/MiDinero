"""Reject common credential files/content in Git's index. Never print secret values.

This is a guardrail, not proof that arbitrary secrets cannot exist. .gitignore does
not protect already tracked files or git add -f. Run before committing and in CI.
"""
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_SUFFIXES = {'.p12', '.pfx', '.cer', '.cert', '.der', '.pem', '.key', '.p8',
                    '.mobileprovision', '.provisionprofile', '.keychain', '.keychain-db',
                    '.xcuserstate', '.xcscmblueprint', '.xccheckout', '.ipa'}
PRIVATE_PARTS = {'xcuserdata', 'secrets', 'private_keys', '.private_keys', 'credentials'}
PATTERNS = (
    re.compile(rb'-----BEGIN (?:[A-Z]+ )?PRIVATE KEY-----'),
    re.compile(rb'\bgh[pousr]_[A-Za-z0-9]{30,}\b'),
    re.compile(rb'\bgithub_pat_[A-Za-z0-9_]{50,}\b'),
    re.compile(rb'\bAKIA[0-9A-Z]{16}\b'),
)


def main() -> None:
    files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    violations = []
    for relative in filter(None, files):
        path = PurePosixPath(relative)
        if (path.suffix.lower() in PRIVATE_SUFFIXES or PRIVATE_PARTS.intersection(path.parts)
                or (path.name.startswith('.env') and path.name != '.env.example')
                or path.name.endswith('.local.xcconfig') or path.name == 'ExportOptions.local.plist'):
            violations.append(f'{relative}: forbidden credential/personal filename')
        # Inspect the staged blob, not just the working copy.
        data = subprocess.check_output(['git', 'show', ':' + relative], cwd=ROOT)
        if any(pattern.search(data) for pattern in PATTERNS):
            violations.append(f'{relative}: private key/token pattern (value withheld)')
    if violations:
        raise SystemExit('\n'.join(violations))
    print(f'PASS: {len(list(filter(None, files)))} indexed files; no forbidden signing files or known key/token patterns.')


if __name__ == '__main__':
    main()
