#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Same real-Xcode pipeline as CI. SIMULATOR_ID is optional: destinations are detected.
exec python3 scripts/ci/validate_xcode.py
