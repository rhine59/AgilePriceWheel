#!/usr/bin/env bash
# Build only: never starts/recreates the deployed service or changes activation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER="${DOCKER:-docker}"
IMAGE="${IMAGE:-homely-heating-controller:verified}"
PLATFORM="${PLATFORM:-linux/amd64}"
if [[ $# -gt 1 || ${1:-} == --help || ${1:-} == -h ]]; then
  echo 'Usage: scripts/rebuild-controller.sh [new-archive.tar.gz]'
  echo 'Overrides: DOCKER, IMAGE, PLATFORM (default linux/amd64 for Synology).'
  exit "$(( $# > 1 ? 2 : 0 ))"
fi
export DOCKER IMAGE PLATFORM
ARCHIVE="${1:-}"
if [[ -n "$ARCHIVE" && -e "$ARCHIVE" ]]; then
  echo 'Refusing to overwrite an existing image archive.' >&2; exit 2
fi
"$DOCKER" build --platform "$PLATFORM" -f "$ROOT/controller/Dockerfile" -t "$IMAGE" "$ROOT"
"$ROOT/scripts/verify-controller.sh"
if [[ -n "$ARCHIVE" ]]; then
  # Private, atomic archive creation; failed exports never appear complete.
  umask 077
  TEMP="$(mktemp "${ARCHIVE}.partial.XXXXXX")"
  trap 'rm -f "$TEMP"' EXIT
  "$DOCKER" save "$IMAGE" | gzip > "$TEMP"
  ln "$TEMP" "$ARCHIVE" # no overwrite if another writer created the destination
  rm "$TEMP"
  trap - EXIT
  echo "Verified image archive: $ARCHIVE"
fi
"$DOCKER" image inspect --format '{{.Id}}' "$IMAGE"
echo 'Build and verification complete. No deployed container was restarted.'
