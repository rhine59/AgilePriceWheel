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

## Heating controller (iOS only)

The iOS **Heating** page connects to the separate always-running Synology
controller in `rhine59/Homely` ([service documentation](https://github.com/rhine59/Homely/blob/main/controller/README.md)).
Enter its private HTTPS origin and controller key, then connect. The key is kept
in iOS Keychain; redirects and insecure HTTP are refused. This page remains
available whether PV display pages are shown or hidden.

Load the controller policy, set **Switch on at or below** and **Switch off above**
(in effective p/kWh), plus room target and safety limit. Off must be >= on;
require 5 <= target <= limit <=25°C. The **Use this app's tariff, solar site and PV
settings** button copies the app's existing selected tariff, site coordinates,
capacity, losses, inverter limit and optimiser electrical load into the draft.
Review the draft and explicitly confirm saving to the controller. Configure the
load to represent heat-pump electrical consumption. On/off prices use the same
Agile + forecast-PV cost model as the Net Electricity Price page, calculated by
the controller independently of the phone. There is no automatic upload just
from opening the page. Policy updates are revision-checked; reload after a
conflict or an uncertain network response before saving again.

Status refreshes every 30 seconds while the page is open and labels its last
check. Source failure/staleness clears price permission at the controller. The
app displays a **price decision**, never an actual heating/room-temperature
measurement. Live heating is disabled; temperature settings are stored but no
room sensor or Homely control adapter is connected. Closing the app does not
stop the controller's worker. NAS HTTPS routing and on-device acceptance remain
separate deployment work; do not treat a simulator build as a phone-to-NAS test.

This feature is implemented for iOS only. Android navigation and functionality
are unchanged; no Android Heating screen or controller client is included.
