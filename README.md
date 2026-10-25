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
In **App Settings → Agile heating connection**, enter its private HTTPS origin
and controller key, then tap **Save connection**. Return to Agile heating and
tap **Test connection / reload controller policy**. The key is kept
in iOS Keychain; redirects and insecure HTTP are refused. This page remains
available whether PV display pages are shown or hidden.

Load the controller policy, set **Switch on at or below** and **Switch off above**
(in effective p/kWh). Off must be >= on. Existing temperature targets remain
managed in Homely. The **Use this app's tariff, solar site and PV
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
app distinguishes the **price decision** from the supervisor status. It shows
saved-recovery warnings and flags heating checks older than 45 seconds or dated
in the future. If the controller supplies optional Homely observations, the app
labels reported temperature and heating state separately and warns that the
sensor is not yet verified for automatic safety checks. Without an observer it
explicitly reports that live Homely readings are not connected.

After the first successful connection, returning to Heating reconnects using the
saved HTTPS address and Keychain key. Editing either connection field clears the
old connection and draft; requests completing for a previous connection are not
applied to the new one. Saving policy still requires confirmation. Live heating
remains disabled; the app has no activation switch or direct Homely commands.
Closing the app does not stop the NAS worker. Simulator tests and an app install
do not by themselves establish a physical phone-to-NAS acceptance test.

This feature is implemented for iOS only. Android navigation and functionality
are unchanged; no Android Heating screen or controller client is included.


### Policy number selectors (iOS)

The Heating policy uses dropdown lists instead of a numeric keyboard: both
price points offer **1–20 p/kWh** in 1p steps. A saved price outside those
choices, including a zero/negative or fractional price, remains visible as **Current**
until explicitly replaced. Values are not rounded or clamped on load. Choosing
a number edits the draft only; saving still requires confirmation and validates
off price >= on price. Android has no Heating page.


The iOS policy dropdown labels are **Heating on** and **Heating off**. Informational/help and saved/copied messages use blue; errors and
safety warnings use red. Action messages include an information or warning icon
so their meaning does not rely on colour alone. Ranges and save behaviour are unchanged.


### Agile heating: separate policy and reported state

The iOS page is titled **Agile heating** and has two coloured lines at the top:
**Heating policy** shows price permission; **Heating state** shows the
Homely-reported flag from the controller's optional read-only observer. ON is
red and OFF is green. An older sensor sample is marked **last reported**;
missing observations or stale/failed API checks show unavailable, never a guessed OFF. The old Always-running controller line is
removed. Automatic control remains separately labelled disabled; an ON policy
is not proof of physical heating. The observer does not issue control commands.


Connection address/key fields are located only in App Settings. Agile heating
retains the Test connection / reload controller policy button. Existing saved
addresses and Keychain keys are reused; saving connection details does not write
policy or issue heating commands. A saved key change on the same address is
reloaded on return to the Heating page.


### Price-window boost strategy (current direction)

Temperature controls have been removed from the iOS Heating page. Only Heating
on and Heating off price selectors remain; Homely retains its existing targets
and schedules. The temperature fields remain in the wire document for API
compatibility and are preserved unchanged by the price editor.

The agreed active-control strategy is evaluation at :00 and :30, with a timed
boost for each permitted half-hour and renewal only for a permitted next slot.
On-policy requires enabling heating if disabled; an off-policy boundary requires
cancelling boost and disabling normal heating, because boost expiry alone is
not proof that normal heating stops. Starting mid-slot must not create a boost
that spills into an unapproved next slot; wait for the next boundary unless a
shorter duration has been verified. This strategy is not yet activated. The
natural-expiry test has not started, and automatic control remains disabled.
