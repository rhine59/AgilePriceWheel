#!/usr/bin/env bash
# Build, offline contract tests and lint. Optional UI tests require an unconfigured emulator.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE=""
BUILD_ROOT="${AGILE_ANDROID_BUILD_ROOT:-$ROOT/android}"
APP_BUILD="$ROOT/android/app/build"
GRADLE_ARGS=(--console=plain)
if [[ -n "${AGILE_ANDROID_BUILD_ROOT:-}" ]]; then
  [[ "$BUILD_ROOT" == /* ]] || { echo "AGILE_ANDROID_BUILD_ROOT must be absolute." >&2; exit 2; }
  APP_BUILD="$BUILD_ROOT/app"
  GRADLE_ARGS+=("-PagileBuildRoot=$BUILD_ROOT" "--project-cache-dir" "$BUILD_ROOT/project-cache")
fi
if [[ $# == 2 && $1 == --device ]]; then DEVICE="$2"
elif [[ $# != 0 ]]; then echo 'Usage: scripts/verify-android.sh [--device emulator-5554]' >&2; exit 2; fi
"$ROOT/android/gradlew" -p "$ROOT/android" "${GRADLE_ARGS[@]}" :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
python3 - "$APP_BUILD/test-results/testDebugUnitTest" <<'PY'
import pathlib,sys,xml.etree.ElementTree as ET
suites=[ET.parse(p).getroot() for p in pathlib.Path(sys.argv[1]).glob('TEST-*.xml')]
assert suites and sum(int(s.get('tests',0)) for s in suites)>0, 'No unit tests ran'
assert all(int(s.get('failures',0))+int(s.get('errors',0))==0 for s in suites), 'Unit tests failed'
print('Android unit results verified: '+str(sum(int(s.get('tests',0)) for s in suites))+' tests')
PY
if [[ -n "$DEVICE" ]]; then
  ADB="${ANDROID_HOME:?Set ANDROID_HOME to the Android SDK}/platform-tools/adb"
  [[ "$DEVICE" == emulator-* && "$("$ADB" -s "$DEVICE" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] || { echo 'Use an unconfigured emulator, not a personal device, for fixture/storage tests.' >&2; exit 2; }
  "$ROOT/android/gradlew" -p "$ROOT/android" "${GRADLE_ARGS[@]}" :app:assembleDebugAndroidTest
  "$ADB" -s "$DEVICE" install -r "$APP_BUILD/outputs/apk/debug/app-debug.apk"
  "$ADB" -s "$DEVICE" install -r "$APP_BUILD/outputs/apk/androidTest/debug/app-debug-androidTest.apk"
  REPORT="$APP_BUILD/reports/heating-device"
  mkdir -p "$REPORT"
  "$ADB" -s "$DEVICE" shell am instrument -w -e timeout_msec 60000 -e class uk.co.krh.agilepricewheel.HeatingScreenTest uk.co.krh.agilepricewheel.test/androidx.test.runner.AndroidJUnitRunner | tee "$REPORT/result.txt"
  # am instrument can exit 0 after failures; require a positive successful test count.
  python3 - "$REPORT/result.txt" <<'PY'
import pathlib,re,sys
text=pathlib.Path(sys.argv[1]).read_text()
match=re.search(r'OK \((\d+) tests?\)',text)
assert match and int(match[1])>=7 and 'FAILURES' not in text and 'Process crashed' not in text, 'Device tests did not pass'
PY
fi
