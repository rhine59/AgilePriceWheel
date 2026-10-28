#!/usr/bin/env bash
# Offline verification only: no credentials, deployment, or live heating calls.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="$ROOT/services/homely"
PYTHON="${PYTHON:-python3}"
if [[ $# -gt 0 ]]; then
  echo 'Usage: scripts/test-homely.sh (set PYTHON to your virtualenv Python)' >&2
  exit 2
fi
cd "$SERVICE"
"$PYTHON" -m unittest discover -s tests
"$PYTHON" examples/heating_services.py --demo --source-dir "$SERVICE"
"$PYTHON" examples/temperature_target_demo.py
