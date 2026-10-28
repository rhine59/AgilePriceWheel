# Agile Price Wheel

One project for energy planning and Homely heating automation. The iPhone/iPad app already manages the heating policy, automation switch and weekly sessions; the supporting Homely service now lives in this repository.

## Project components

| Component | Location | Runs on |
|---|---|---|
| iPhone/iPad app | `AgilePriceWheel/` and `AgilePriceWheel.xcodeproj` | iOS/iPadOS |
| Android app | `android/` | Android |
| Homely heating and hot-water services | `services/homely/` | NAS/home server |

The service keeps automation running when the phone app is closed. Consolidation does not change your saved controller URL, access key, policy, schedules or deployed container. See [the consolidation and migration guide](docs/HOMELY-CONSOLIDATION.md) and [controller services](services/homely/controller/SERVICES.md).

### Controller development from this repository

```bash
python3 -m venv .venv-homely
.venv-homely/bin/python -m pip install -r services/homely/requirements.txt
PYTHON="$PWD/.venv-homely/bin/python" ./scripts/test-homely.sh
./scripts/rebuild-homely.sh          # build + isolated container verification
./scripts/package-homely.sh /tmp/homely-source.tar.gz
```

These commands do not restart the deployed service. Keep runtime secrets and persistent data outside Git. Existing detailed Homely commands remain valid after `cd services/homely`.

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
6. Agile heating
7. App Settings
8. User Guide

With **Solar PV panels installed = ON**, all eight destinations are available. With it **OFF**, PV, Net and Save are hidden, leaving Prices, Solar, Heating, Settings and Guide. Re-enabling PV restores the three destinations. Saved PV configuration is intended to be retained.

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

Open the repository's `android/` directory in Android Studio and let Gradle sync. The Android client uses Kotlin, Jetpack Compose, Material 3, Lifecycle and Google Play Services Location. It currently declares `minSdk 26`, `compileSdk 37`, `targetSdk 36`, and Compose BOM `2026.08.00`.

Android's official guidance describes Compose as the modern native UI toolkit and recommends adaptive layouts for phones, tablets and other display sizes. The Compose BOM is used to align compatible Compose library versions.

## Responsive layout

The Apple dashboard uses SwiftUI adaptive layout, width-limited content and `ViewThatFits` navigation/header fallbacks. The Android dashboard uses Compose constraints, width-limited centred content and state-derived navigation for phones/tablets. Neither platform should position Now as a floating overlay over metric content.

## Current Android parity status

The Android app now includes Heating policy/state, signed price menus,
Automation ON/OFF, secure connection settings and weekly sessions with estimated
cost/payment. Native pricing and solar pages remain available. Tabs scroll on
narrow screens. See [Android verification](docs/ANDROID-HEATING-VERIFICATION.md)
for build/test/device evidence and remaining distribution limits.

## Release verification

For Apple, test compact/standard/Max iPhones and an iPad, PV on/off, Now, current location, 46/48/50-period days and larger Dynamic Type. For Android, test compact/normal/large phones and a tablet/emulator, location permission allowed/denied, PV on/off, Now, negative prices and agreement between Net PV saving and Cost Savings.

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application. Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecast/derived planning estimates and can differ from actual generation, energy flows and bills.

## Agile heating (iOS and Android)

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
Heating is open. Ongoing controller activation and Automation have been approved
and enabled. The app cannot grant initial administrative activation.

Verification includes 172 backend tests, 14 focused iOS checks and 62 offline
walkthrough checks. Real overnight ON/OFF entries are retained. The weekly log
exposed a short setup timeout; boundary attempts now have up to 60 seconds to
finish setup while keeping the original half-hour end. See the backend service
catalogue for recovery and outage limits.

## Weekly heating log — iOS and Android

On **Heating**, connect and tap **Weekly heating log**. It opens the current
Monday–Sunday week; use the arrows for previous weeks and Reload or pull to
refresh. ON is red and OFF green. Each entry shows the confirmed action time,
effective price, saved on/off thresholds and reason. Times use Europe/London
and include GMT/BST to distinguish the repeated autumn hour. Logging began on
25 October 2026; earlier weeks contain no reconstructed events.

The controller retains 366 days independently of the phone. A pending-storage
warning means confirmed events are awaiting a database retry. Manual Homely
changes and compressor cycles are outside this automation log. Existing
pre-update entries may say “Price data unavailable” where a slow setup exceeded
the former 15-second budget; new entries distinguish “Heating setup timed out.”
Android now provides Heating and the weekly session/action log; see [Android parity](docs/ANDROID.md).

The owner has approved ongoing operation and enabled Automation. New installs
still default OFF; use the app switch to pause/resume this installation without
changing its saved price policy. Heating depends on each half-hour decision.

## Heating sessions and estimated cost

**Heating → Weekly heating log** now groups each ON with its matching OFF in a
Heating sessions section. It shows elapsed duration, effective rate at each action,
raw Agile and effective unit rates for each half-hour, configured electrical load,
estimated kWh and estimated cost. Negative totals are labelled **Estimated payment**.
Individual actions remain below for investigation. Existing records pair by action
order; cost stays unavailable where historical load/rates were not saved.

Costs assume the configured electrical load throughout the confirmed enabled
interval and use effective prices after forecast solar. They are not metered
consumption or a supplier bill. Missing intervals or an unconfirmed OFF leave the
total unavailable. Sessions crossing weeks appear with the same ID in both weeks;
do not add duplicate appearances. Manual changes do not fabricate an OFF.
This feature is available on iOS and Android.


Android heating controls are implemented. See [requirements and delivery status](docs/ANDROID-HEATING-REQUIREMENTS.md) and [verification](docs/ANDROID-HEATING-VERIFICATION.md).


[26 October heating checkpoint](docs/CHECKPOINT-2026-10-26.md) records the deployed baseline, verification and outstanding Android delivery.


[26 October bug audit](docs/BUG-AUDIT-2026-10-26.md) records corrected price-display and history edge cases, regression evidence and remaining limits.
