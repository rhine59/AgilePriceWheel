#!/usr/bin/env bash
# Package committed public source for a NAS without Git. No ignored runtime files.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
  echo 'Usage: scripts/package-controller-source.sh new-source.tar.gz'
  echo 'Requires a clean committed Git checkout; does not build or deploy.'
  exit 0
fi
if [[ $# -ne 1 ]]; then echo 'Usage: scripts/package-controller-source.sh new-source.tar.gz' >&2; exit 2; fi
ARCHIVE="$1"
if [[ -e "$ARCHIVE" ]]; then echo 'Refusing to overwrite an existing source archive.' >&2; exit 2; fi
if [[ -n "$(git -C "$ROOT" status --porcelain --untracked-files=normal)" ]]; then
  echo 'Use a clean committed checkout so the archive matches its recorded revision.' >&2; exit 2
fi
umask 077
TEMP="$(mktemp "${ARCHIVE}.partial.XXXXXX")"
trap 'rm -f "$TEMP"' EXIT
git -C "$ROOT" archive --format=tar HEAD | gzip > "$TEMP"
ln "$TEMP" "$ARCHIVE"
rm "$TEMP"
trap - EXIT
printf 'Source revision: '
git -C "$ROOT" rev-parse HEAD
printf 'Committed source archive: %s\n' "$ARCHIVE"
echo 'Only tracked committed files were packaged; no Git database or ignored credentials.'
