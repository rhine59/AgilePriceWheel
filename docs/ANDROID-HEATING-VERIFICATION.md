# Android heating verification — 27 October 2026

The Android client now implements the heating controls and weekly log. The
Synology image, running container, saved price thresholds and Automation switch
were not changed while building/testing Android. No live heating write was used
for these tests. The separate 22°C diagnostic was cancelled before execution.

## Build and contract checks

- Installable evaluation APK: `app-debug.apk`, version 1.1 / version code 2,
  application ID `uk.co.krh.agilepricewheel`, min SDK 26, target 36, compile 37.
- Pinned Gradle 9.6.0 wrapper with official distribution SHA-256, AGP 9.4.1,
  built-in Kotlin / Compose compiler 2.3.21, Compose BOM 2026.08.00.
- Build run using JDK 17.0.20.1 and the installed Android SDK on the Mac.
- `assembleDebug`, `testDebugUnitTest`, `assembleDebugAndroidTest` and `lintDebug`.
- 17 JVM tests: exact six-service requests, signed price validation, preservation
  of all other policy fields/revisions, concurrent revision refusal, uncertain
  write reconciliation without replay, network failures/explicit stop, controller
  readiness, host/key isolation and connection recreation, separate history errors,
  HTTPS validation, refused redirects, auth/conflict handling, malformed history,
  45-second freshness/slot expiry, DST weeks/times and server-provided cost/payment.
- Lint: zero errors. Ten advisory warnings concern newer available tools/libraries,
  retaining target SDK 36 and the existing missing launcher icon. These are not
  evidence of physical-device or Play Store release acceptance.
- The controller documentation/source also passed 225 offline backend tests,
  the 62-check all-service Python walkthrough and the schedule-planning rehearsal.

## Emulator checks

Seven instrumented checks run against fixture heating state, not live controls:
separate policy/reported status, UNKNOWN on failure, enable confirmation/cancel,
negative menu selection, paired weekly session with estimated payment and explicit
BST/GMT times, encrypted Keystore storage bound to address and restored on a new
store instance, and full-app navigation/settings with PV-dependent tabs hidden.
The secure-storage test refuses an emulator with an existing saved connection.

The screen matrix uses one Android 17 Pixel 10a emulator with reversible display
overrides. Each profile exercises all seven checks:

| Profile | Logical display | Coverage |
| --- | --- | --- |
| Normal phone | approximately 411×923dp, 1080×2424px at 420dpi | Heating, settings, signed policy, automation confirmation, history and storage |
| Compact phone | 320×640dp | Same checks; scrollable tabs and content |
| Large phone | 480×960dp | Same checks |
| Landscape tablet | 1280×800dp | Same checks; centred width-limited app content |

Fixture screenshots are generated for Heating, weekly history and full-app
navigation. Visual review identified and fixed dark-theme content contrast.
Heating now shows only controller errors, rather than unrelated pricing-page errors.
The test dependency explicitly uses Espresso 3.7.0 to avoid its older transitive
input-manager reflection failure on Android 17. No physical Android phone/tablet
has been connected or tested in this session.

## Reproduce

From the repository root, with JDK and `ANDROID_HOME` configured:

```sh
scripts/verify-android.sh
scripts/verify-android-layouts.sh emulator-5554
```

Use a disposable, unconfigured emulator for instrumented tests. The layout script
restores previous screen size/density on exit and stores logs/screenshots under
`android/app/build/reports/`. It requires a positive successful test count: a
zero-exit instrumentation process with no tests/failures is rejected.

For a cloud-synced Mac checkout, use
`AGILE_ANDROID_BUILD_ROOT=/private/tmp/agile-android-build` to keep generated files
outside Documents; the scripts then use that location for app output and caches.
The optional Gradle property is `-PagileBuildRoot=/absolute/path`. A generated
class in the synced checkout stalled a build during this session; moving output
resolved it. The final source is unchanged by that storage choice.

## Delivery limits

The debug-signed APK is suitable for direct installation/evaluation and contains
no controller address, bearer key or Homely credentials. Enter the existing NAS
HTTPS address/key in Settings, then test/reload on Heating. Play Store signing,
publication, physical-device acceptance and validation of metered heat-pump cost
are separate. The log displays server estimates, not measured consumption. A full
qualifying production heating slot remains an operational observation task.
