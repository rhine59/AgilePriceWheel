# Agile Price Wheel — Android

Native Android implementation using Kotlin and Jetpack Compose. It is intended to track the iOS app's user-facing calculations and navigation rather than being a WebView or cross-platform wrapper.

## Current feature parity

- Octopus Agile half-hour price page and interactive wheel.
- Solar Forecast using Open-Meteo 15-minute shortwave radiation combined into half-hours.
- PV Forecast using the same first-order GHI, array capacity, system-loss and inverter-clipping model as iOS.
- Net Electricity Price using configured load and forecast PV.
- Cost Savings using avoided grid import × Agile price; the Net page also surfaces selected-sector PV saving.
- Prices, Solar, PV, Net, Save, Heating, Settings and Guide navigation.
- PV, Net and Save are automatically hidden when **Solar PV panels installed** is off and return when it is on.
- **Now** on metric pages returns to today/current settlement period.
- **Use Current Location** is opt-in, reverse-geocodes a common place name using Android Geocoder, and leaves the site label editable.
- Width-limited, responsive Compose layout for phones and tablets.
- 46/48/50-period handling follows actual Europe/London timestamps returned by the APIs.

## Build

Open the repository's `android` directory in Android Studio and let Gradle sync. The module uses `compileSdk 37`, `targetSdk 36`, `minSdk 26`, Kotlin/Compose, Material 3, Lifecycle, DataStore and Google Play Services Location. Compose dependencies are aligned with the stable Compose BOM.

The current project uses the Compose BOM `2026.08.00`. Android's official documentation recommends the BOM for keeping Compose libraries mutually compatible.

Run the `app` configuration on an Android phone, tablet or emulator. Location testing is best performed on hardware or an emulator with a configured location.

## Calculations

PV:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective array kWp × irradiance factor
loss-adjusted power = raw × (1 - system loss % / 100)
estimated power = min(loss-adjusted power, inverter maximum) if configured
estimated energy = estimated power × actual period duration
```

Net:

```text
load energy = load kW × period hours
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net effective price = slot cost / complete load energy
```

Savings:

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

Surplus export income and household background load are not separately modelled.

## Android-specific notes

The Android app uses Jetpack Compose's declarative state-driven UI. Scrollable tab navigation is derived from the PV-installed state, so switching PV off removes the three PV-dependent destinations without discarding configuration. The content column is centred and constrained on wide screens to avoid tablet over-stretching.

Current Location requests fine/coarse location permission only when the user asks for it. Android's asynchronous Geocoder API is used on Android 13+; an IO-thread compatibility path is retained for older supported versions.

## Verification checklist

Before release, build and test at least a compact phone, normal phone, large phone and tablet; portrait and landscape where practical; PV on/off navigation; current-location permission allowed/denied; common-name editing; Now selection; 46/48/50 period days; negative Agile prices; and agreement between Net selected-sector saving and Cost Savings.

The Android implementation should be kept in parity whenever the iOS implementation changes.

## Agile heating

The native Heating page now supports the controller connection, signed price
menus, revision-aware saves, persistent Automation ON/OFF, separate policy/state
indicators and the weekly session/action log. Connection details live in Settings;
no temperature selectors or direct Homely credentials are on the phone.
See [operation and security](../docs/ANDROID.md).

## Reproducible build and install

Requirements: JDK 17 or newer supported by Gradle 9.6.0, Android SDK platform 37,
network access for initial dependencies, and `ANDROID_HOME` pointing to the SDK.
The checked-in Gradle wrapper pins 9.6.0. AGP 9.4.1 uses built-in Kotlin; Compose
compiler plugin is 2.3.21 and BOM 2026.08.00. `minSdk` is 26; target remains 36.

```sh
./gradlew :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
# Or, from the repository root:
scripts/verify-android.sh
# Also exercise offline screens/storage on an already-running unconfigured emulator:
scripts/verify-android.sh --device emulator-5554
```

Output: `app/build/outputs/apk/debug/app-debug.apk`. Install for evaluation with
`adb install -r app/build/outputs/apk/debug/app-debug.apk`. Android may ask to
allow installation from the chosen file source. The app needs no special Homely
permission: use Settings to enter the NAS HTTPS origin/key, then test/reload on
Heating. The debug APK contains no deployment keys or household details.

For a distributable release, configure a private Android signing key outside Git
and a release signing configuration; never commit keystores/passwords. Do not
replace an installed app with a differently signed APK without planning how to
retain its configuration. Uninstalling clears the saved encrypted connection.
Play Store publication is not part of this change.

Unit tests use fake controller responses, and emulator UI/storage tests use fixture
state. They never call live heating. Espresso 3.7.0 is explicitly pinned for the
Android 17 input-manager API change. The script checks actual positive test counts
because an instrumentation process can exit zero after failure/no tests.
[Verification evidence](../docs/ANDROID-HEATING-VERIFICATION.md) records the tested matrix.

For the screen matrix, run `scripts/verify-android-layouts.sh emulator-5554`
from the repository root. It tests the emulator's normal size, then compact
320×640dp, large 480×960dp and landscape tablet 1280×800dp, restoring display
overrides afterwards. Logs and fixture screenshots go under the module's
`build/reports/` folder. Use a disposable, unconfigured emulator: storage tests
refuse to overwrite an existing controller connection.

On a cloud-synced checkout, set `AGILE_ANDROID_BUILD_ROOT=/private/tmp/agile-android-build`
to keep generated classes/caches outside Documents. The verification scripts
then put the APK under `$AGILE_ANDROID_BUILD_ROOT/app/outputs/apk/debug/`.
Android Studio can use the equivalent Gradle property `-PagileBuildRoot=/absolute/path`.
The wrapper verifies its downloaded distribution against the official SHA-256.
