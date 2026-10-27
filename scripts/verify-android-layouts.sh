#!/usr/bin/env bash
# Offline fixture screens on one disposable/unconfigured emulator; restores display overrides.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE="${1:-emulator-5554}"
ADB="${ANDROID_HOME:?Set ANDROID_HOME}/platform-tools/adb"
[[ "$DEVICE" == emulator-* ]] || { echo 'Use a disposable emulator.' >&2; exit 2; }
BUILD="${AGILE_ANDROID_BUILD_ROOT:+$AGILE_ANDROID_BUILD_ROOT/app}"
BUILD="${BUILD:-$ROOT/android/app/build}"
REPORT="$BUILD/reports/heating-layouts"
mkdir -p "$REPORT"
SIZE="$("$ADB" -s "$DEVICE" shell wm size | awk '/Override size:/ {print $3}' | tr -d '\r')"
DENSITY="$("$ADB" -s "$DEVICE" shell wm density | awk '/Override density:/ {print $3}' | tr -d '\r')"
restore() {
  "$ADB" -s "$DEVICE" shell wm size "${SIZE:-reset}" >/dev/null
  "$ADB" -s "$DEVICE" shell wm density "${DENSITY:-reset}" >/dev/null
}
trap restore EXIT
"$ROOT/scripts/verify-android.sh" --device "$DEVICE"
for profile in compact large tablet; do
  case "$profile" in compact) width=320; height=640;; large) width=480; height=960;; tablet) width=1280; height=800;; esac
  "$ADB" -s "$DEVICE" shell wm size "${width}x${height}"
  "$ADB" -s "$DEVICE" shell wm density 160
  "$ADB" -s "$DEVICE" shell am instrument -w -e timeout_msec 60000 -e class uk.co.krh.agilepricewheel.HeatingScreenTest uk.co.krh.agilepricewheel.test/androidx.test.runner.AndroidJUnitRunner > "$REPORT/$profile.txt"
  python3 - "$REPORT/$profile.txt" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text()
match=re.search(r'OK \((\d+) tests?\)',text)
assert match and int(match[1])>=7 and 'FAILURES' not in text and 'Process crashed' not in text, 'Layout tests failed; see '+sys.argv[1]
print(pathlib.Path(sys.argv[1]).stem+': '+match[0])
PY
  for screen in heating-screen heating-history heating-app; do
    "$ADB" -s "$DEVICE" exec-out run-as uk.co.krh.agilepricewheel cat "files/$screen.png" > "$REPORT/$profile-$screen.png"
  done
done
