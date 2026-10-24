# Agile Price Wheel — Android

Native Android implementation using Kotlin and Jetpack Compose. It is intended to track the iOS app's user-facing calculations and navigation rather than being a WebView or cross-platform wrapper.

## Current feature parity

- Octopus Agile half-hour price page and interactive wheel.
- Solar Forecast using Open-Meteo 15-minute shortwave radiation combined into half-hours.
- PV Forecast using the same first-order GHI, array capacity, system-loss and inverter-clipping model as iOS.
- Net Electricity Price using configured load and forecast PV.
- Cost Savings using avoided grid import × Agile price; the Net page also surfaces selected-sector PV saving.
- Prices, Solar, PV, Net, Save, Settings and Guide navigation.
- PV, Net and Save are automatically hidden when **Solar PV panels installed** is off and return when it is on.
- **Now** on metric pages returns to today/current settlement period.
- **Use Current Location** is opt-in, reverse-geocodes a common place name using Android Geocoder, and leaves the site label editable.
- Width-limited, responsive Compose layout for phones and tablets.
- 46/48/50-period handling follows actual Europe/London timestamps returned by the APIs.

## Build

Open the repository's `android` directory in Android Studio and let Gradle sync. The module uses `compileSdk 36`, `targetSdk 36`, `minSdk 26`, Kotlin/Compose, Material 3, Lifecycle, DataStore and Google Play Services Location. Compose dependencies are aligned with the stable Compose BOM.

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

The Android app uses Jetpack Compose's declarative state-driven UI. Bottom navigation is derived from the PV-installed state, so switching PV off removes the three PV-dependent destinations without discarding configuration. The content column is centred and constrained on wide screens to avoid tablet over-stretching.

Current Location requests fine/coarse location permission only when the user asks for it. Android's asynchronous Geocoder API is used on Android 13+; an IO-thread compatibility path is retained for older supported versions.

## Verification checklist

Before release, build and test at least a compact phone, normal phone, large phone and tablet; portrait and landscape where practical; PV on/off navigation; current-location permission allowed/denied; common-name editing; Now selection; 46/48/50 period days; negative Agile prices; and agreement between Net selected-sector saving and Cost Savings.

The Android implementation should be kept in parity whenever the iOS implementation changes.

## Heating controller parity

The Apple app now includes a Heating page for an authenticated, plan-only Synology controller. Android does not include this feature yet; existing Android pages are unchanged.
