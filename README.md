# Agile Price Wheel

Agile Price Wheel now contains two native clients for the same energy-planning model:

- **iPhone/iPad:** Swift + SwiftUI in `AgilePriceWheel/` and `AgilePriceWheel.xcodeproj`.
- **Android phones/tablets:** Kotlin + Jetpack Compose in `android/`.

Both clients cover Octopus Agile prices, Solar Forecast, PV Forecast, Net Electricity Price and PV Cost Savings. The Android implementation was added to bring the current iOS feature set across to Android without using a WebView or cross-platform wrapper.

## Documentation index

- [`USER_GUIDE.md`](USER_GUIDE.md) — cross-platform operating guide and platform notes.
- [`android/README.md`](android/README.md) — Android setup, architecture, calculations and verification.
- [`docs/ANDROID.md`](docs/ANDROID.md) — Android/iOS parity contract.
- [`docs/INDEX.md`](docs/INDEX.md) — central documentation index.
- [`docs/NOW_BUTTON_AND_CURRENT_TIME.md`](docs/NOW_BUTTON_AND_CURRENT_TIME.md) — Now/current-period behaviour.
- [`docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) — iOS responsive-layout rules and test matrix.
- [`DOCUMENTATION_POLICY.md`](DOCUMENTATION_POLICY.md) — documentation/parity maintenance policy.
- `AgilePriceWheel/DocumentationView.swift` — offline guide compiled into the Apple app.

## Main navigation and PV state

The logical page order on both platforms is:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings
6. App Settings
7. User Guide

With **Solar PV panels installed = ON**, all seven destinations are available. With it **OFF**, PV, Net and Save are hidden, leaving Prices, Solar, Settings and Guide. Re-enabling PV restores the three destinations. Saved PV configuration is intended to be retained.

The PV navigation control uses a simple lightning-bolt treatment on both platforms.

## Shared calculations

PV Forecast:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective array kWp × irradiance factor
loss-adjusted power = raw × (1 - system loss % / 100)
estimated power = min(loss-adjusted power, inverter maximum) if configured
estimated energy = estimated power × actual period duration
```

Net Electricity Price:

```text
load energy = configured load kW × period hours
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net effective price = slot cost / complete load energy
```

Cost Savings:

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The Net selected period also surfaces the same PV-saving value. Export revenue and household background load are not separately modelled.

## Data sources

Both clients use public Octopus Energy tariff/rate endpoints and Open-Meteo solar forecast data. They use `Europe/London` settlement timestamps so normal and UK clock-change days can contain 48, 46 or 50 periods.

Current Location is opt-in. The Apple app uses Core Location for the requested fix and MapKit `MKReverseGeocodingRequest` for the readable site label on its current iOS 26.5 deployment target. The Android app uses Fused Location Provider and Android Geocoder. In both cases the resulting site name is editable independently of the coordinates.

## Apple build

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

The Apple target is iPhone/iPad (`TARGETED_DEVICE_FAMILY = 1,2`) and currently targets iOS 26.5. Configure Signing & Capabilities and select the required simulator/device.

## Android build

Open the repository's `android/` directory in Android Studio and let Gradle sync. The Android client uses Kotlin, Jetpack Compose, Material 3, Lifecycle and Google Play Services Location. It currently declares `minSdk 26`, `compileSdk 36`, `targetSdk 36`, and Compose BOM `2026.08.00`.

Android's official guidance describes Compose as the modern native UI toolkit and recommends adaptive layouts for phones, tablets and other display sizes. The Compose BOM is used to align compatible Compose library versions.

## Responsive layout

The Apple dashboard uses SwiftUI adaptive layout, width-limited content and `ViewThatFits` navigation/header fallbacks. The Android dashboard uses Compose constraints, width-limited centred content and state-derived navigation for phones/tablets. Neither platform should position Now as a floating overlay over metric content.

## Current Android parity status

The Android source now includes the recent iOS features that had been missing: Cost Savings, PV saving on Net, seven/four destination navigation, PV-dependent hiding/restoration, Now on metric pages, editable reverse-geocoded Current Location naming, a simple lightning-bolt PV control and responsive phone/tablet layout.

This commit establishes source-level parity for that current core feature set. It has **not yet been verified by an Android Studio build or physical Android-device test in this conversation**, so Android release readiness should not be claimed until Gradle sync/build and the device matrix in `android/README.md` have passed.

## Release verification

For Apple, test compact/standard/Max iPhones and an iPad, PV on/off, Now, current location, 46/48/50-period days and larger Dynamic Type. For Android, test compact/normal/large phones and a tablet/emulator, location permission allowed/denied, PV on/off, Now, negative prices and agreement between Net PV saving and Cost Savings.

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application. Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecast/derived planning estimates and can differ from actual generation, energy flows and bills.

## Agile heating (iOS only)

The **Heating** tab opens **Agile heating**. Connection details live in
**App Settings → Agile heating connection**: save the HTTPS address and key,
then use **Test connection / reload controller policy** on Heating. The key stays
in Keychain. Updating the app preserves existing settings and connection.

Two separate coloured lines show **Heating policy** (price permission) and
**Heating state** (Homely's report): ON red, OFF green, unavailable when data is
missing or stale. Older sensor data is marked last reported. Neither line proves
physical compressor operation. Activation and recovery/manual-hold status are
shown separately. The app accepts both plan-only and automatic controller modes.

**Heating on** and **Heating off** offer −20 through +20 p/kWh, including zero.
Existing values outside the menu remain Current. Both values can be negative;
negative rates mean payment for grid-imported electricity. Off must be >= on.
For example, on=−5p/off=−1p starts at −5p or below, holds through −1p once
permitted, and stops above −1p. Homely retains its own temperature targets; the
app has no target/ceiling controls. Information is blue and errors are red.

The **Automation** switch is the persistent policy on/off control. OFF requests
boost cancellation and heating disable, then leaves later manual Homely use alone.
The app shows **shutdown pending** until confirmed. ON requires prior controller
activation and confirmation in the app, then waits for a new half-hour decision.
Switch state survives app/NAS restarts. A failed request is reloaded, not blindly
repeated. The switch never changes your saved price thresholds.

The NAS evaluates effective Agile-plus-forecast-PV prices at :00 and :30. Each
boost ends at the next slot boundary. It explicitly disables normal heating when
permission ends; native boost expiry alone is not an off command. A forecast
refresh inside the slot cannot renew a boost. A mid-slot restart or recovered
failure waits for the next boundary. API outages can delay an off command.

Copy this app's tariff/site/PV settings into the draft only when desired, then
review and confirm Save policy. Saving never changes activation. If already
active, it stops the current owned boost, releases a manual-change hold and
applies the policy from the next half-hour. A hold preserves external Homely
changes; there is no observed atomic ownership token, so simultaneous app writes
cannot be fully excluded. Temperature and sensor freshness do not gate the policy.

The controller runs without the iPhone app. Status polls every 30 seconds while
Heating is open. **Automatic heating remains disabled on the deployed NAS until
separately approved**. The app cannot grant the controller its initial administrative activation.
Android does not yet implement this Heating page.

Verification: nine iOS model checks and one navigation check passed; the signed
build was installed on the paired iPhone. The native driver passed 129 backend
tests and is deployed with activation off. One earlier half-hour pilot verified
native API-record expiry; an unattended live cycle of the new driver has not
been authorised. See the backend service catalogue for the full recovery and
outage limits.
