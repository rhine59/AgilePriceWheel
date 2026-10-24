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
