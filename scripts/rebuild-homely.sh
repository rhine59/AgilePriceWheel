#!/usr/bin/env bash
# Delegate using a stable service root; works from any current directory.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/services/homely/scripts/rebuild-controller.sh" "$@"
