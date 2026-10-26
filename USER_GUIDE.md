# Agile Price Wheel — User Guide

This guide covers the shared behaviour of the Apple and Android clients. Platform-specific setup is documented in the root README and `android/README.md`.

## Index

1. Main navigation
2. Now
3. Octopus Agile Prices
4. Solar Forecast and solar site
5. PV Forecast
6. Net Electricity Price
7. Cost Savings
8. PV installed switch
9. Screen sizes
10. Privacy and location
11. UK clock changes
12. Platform notes and troubleshooting

## 1. Main navigation

The logical destinations are Prices, Solar, PV, Net, Save, Settings and Guide. With PV enabled all seven are available. With **Solar PV panels installed** off, PV, Net and Save disappear; Prices, Solar, Settings and Guide remain. Turning PV on restores the three PV-dependent destinations.

## 2. Now

Now appears on metric pages. It returns the selected day to today and selects the period satisfying:

```text
validFrom <= now < validTo
```

Now is kept in normal layout flow so it does not cover headings, wheels or cards.

## 3. Octopus Agile Prices

Each wheel sector represents one settlement period. A normal UK day contains 48 half-hours; clock-change days can contain 46 or 50. Negative prices are visually distinct. Touch/tap a wheel sector to select it.

## 4. Solar Forecast and solar site

Solar Forecast shows global horizontal irradiance (shortwave radiation) in W/m². Open-Meteo 15-minute values are combined into half-hour values.

The solar site can use a requested current-location fix. The app then attempts to derive a familiar locality/town name and stores it as the display label. The label can be edited without changing latitude/longitude. Current Location is opt-in and is not continuous tracking.

Apple currently uses Core Location plus MapKit reverse geocoding. Android uses Fused Location Provider plus Android Geocoder. If no suitable place name is found, **Current location** is the fallback.

The Apple client additionally retains its established place/postcode search and manual-coordinate workflow. Android's current parity addition focuses on the requested Current Location path; additional Android site-entry polish should be verified before release.

## 5. PV Forecast

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective array kWp × irradiance factor
loss-adjusted power = raw × (1 - system loss % / 100)
estimated power = min(loss-adjusted power, inverter maximum) if configured
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority over panel-count-derived capacity where supported. PV Forecast is hidden when PV is off.

## 6. Net Electricity Price

```text
load energy = configured load kW × period hours
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net price = slot cost / complete load energy
```

The selected period also shows PV saving in pence.

## 7. Cost Savings

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

Only PV that offsets the configured load is counted. Export income is not included. A negative Agile price can legitimately produce a negative saving. The Net selected-period saving and Cost Savings value should agree for the same period.

## 8. PV installed switch

When PV is off, PV Forecast, Net Electricity Price and Cost Savings are removed from navigation. Solar Forecast remains available. Re-enabling PV restores the three destinations.

## 9. Screen sizes

The Apple client adapts across compact/large iPhones and iPads. The Android client uses responsive Compose content for phones and tablets. Release testing should include both narrow and wide devices because wheels, metric cards and bottom navigation are dense UI.

## 10. Privacy and location

Public tariff/rate use does not require Octopus account credentials. Location permission is requested only when the user asks to use Current Location. Coordinates are used to obtain a readable place label and request solar forecast data. The app is not designed to continuously track location.

## 11. UK clock changes

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

Both implementations use actual timestamps/durations in the Europe/London timezone.

## 12. Platform notes and troubleshooting

**Apple:** if current location fails, check Location Services and Agile Price Wheel's permission. The current iOS deployment path uses MapKit reverse geocoding and should not emit the removed CLGeocoder compatibility error. If PV/Net/Save are missing unexpectedly, check the PV-installed switch.

**Android:** open `android/` in Android Studio. If Gradle sync fails, verify the installed Android SDK/JDK and dependency access. If Current Location fails, check Android location permission and that the device/emulator has a location fix. The Android source has been brought to current core-feature parity but still requires Android Studio/device verification before release.

If Now overlays content, bottom navigation becomes unusable, PV-dependent pages fail to return, or Net saving differs from Cost Savings for the same period, treat that as a defect.

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application. Forecast and derived values are planning estimates, not billing measurements.

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
Heating is open. Ongoing controller activation and Automation have been approved
and enabled. The app cannot grant initial administrative activation.

Verification includes 159 backend tests, 13 focused iOS checks and 62 offline
walkthrough checks. Real overnight ON/OFF entries are retained. The weekly log
exposed a short setup timeout; boundary attempts now have up to 60 seconds to
finish setup while keeping the original half-hour end. See the backend service
catalogue for recovery and outage limits.

## Weekly heating log — iOS

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
Android does not yet provide Heating or this log.

The owner has approved ongoing operation and enabled Automation. New installs
still default OFF; use the app switch to pause/resume this installation without
changing its saved price policy. Heating depends on each half-hour decision.
