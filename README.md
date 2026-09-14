# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile electricity prices, solar irradiance forecasts, a local PV Forecast and a solar-adjusted Net Electricity Price.

The first dashboard page is presented to the user as **Octopus Agile Prices**. The Xcode project and GitHub repository remain named `AgilePriceWheel`.

The app uses Apple frameworks only (`SwiftUI`, `Foundation`, `Combine`, `CoreLocation`) and has no third-party package dependencies.

For user operation see `USER_GUIDE.md`. The same core guidance is built into the app in `AgilePriceWheel/DocumentationView.swift`.

---

## Main page navigation

The app has six pages:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. App Settings
6. User Guide

Horizontal swipe navigation is deliberately disabled so dragging around an interactive wheel cannot accidentally change the main page.

A fixed six-button navigation bar is shown at the bottom of every page. Any page can be opened directly:

| Button | SF Symbol | Page |
|---|---|---|
| Prices | `bolt.fill` | Octopus Agile Prices |
| Solar | `sun.max.fill` | Solar Forecast |
| PV | `bolt.sun.fill` | PV Forecast |
| Net | `sterlingsign.circle.fill` | Net Electricity Price |
| Settings | `slider.horizontal.3` | App Settings |
| Guide | `book.closed.fill` | User Guide |

The current page button is highlighted in orange. The previous Back/Next controls, page-dot indicator and page-number indicator have been removed. Obsolete swipe instructions have also been removed from the Solar Forecast, PV Forecast, Net Electricity Price and Settings pages.

The first four metric pages additionally show a **Now** button. Tapping Now returns the shared selected date to today and selects the half-hour containing the current time.

---

## Octopus Agile Prices

The first page displays the selected Octopus Energy Agile import tariff as an interactive half-hour wheel.

Features include dynamic Agile tariff discovery, regional tariff selection, 46/48/50-period UK DST support, touch/drag wheel selection, selected/lowest/highest/average prices, Prices/Chart/Details views, live-server/local-cache status and persistent tariff selection.

Negative Agile prices are blue. Positive prices use a day-relative green-to-red scale.

---

## Solar Forecast

Solar Forecast displays global horizontal irradiance (GHI / shortwave radiation) in W/m² for the selected day. Open-Meteo 15-minute `shortwave_radiation` samples are combined into half-hour values.

The page shows an interactive solar wheel, selected irradiance, peak irradiance/time, daylight average, forecast-site coordinates and source/cache status.

Solar Forecast remains available even when the property is configured as having no PV panels installed.

### Solar-site selection

The solar site can be set in three ways:

1. **Use Current Location** — requests iOS When-In-Use permission only when tapped;
2. place/postcode search through Open-Meteo geocoding;
3. manual latitude/longitude.

The app does not continuously track location. Search and manual entry remain available if location permission is denied.

---

## PV Forecast

PV Forecast converts the solar irradiance forecast into a first-order estimate of PV electrical output for the configured array. Each wheel sector represents estimated kWh during that half-hour.

The page shows estimated day total, peak output/time, selected half-hour energy, selected half-hour average power and effective array capacity used.

For each half-hour:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective array kWp × irradiance factor
loss-adjusted power = raw power × (1 - system loss % / 100)
estimated power = min(loss-adjusted power, inverter maximum)  [if set]
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority. If blank, capacity can be derived from panel count × panel watts / 1000.

Tilt and azimuth are stored but are not yet applied because the current weather input is horizontal GHI rather than plane-of-array irradiance. Shading, temperature, snow/soiling, detailed inverter efficiency, mismatch, degradation, horizon obstruction and albedo are not explicitly modelled.

When **Solar PV panels installed** is off, PV Forecast is greyed and disabled while saved PV settings are retained.

---

## Net Electricity Price

This page combines Agile price, forecast PV and a configured controllable load.

```text
load energy = load kW × period hours
forecast PV = forecast PV energy for the same period
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net effective price = slot cost / complete load energy
```

The default optimiser load is **3.0 kW**. The model assumes all forecast PV is available to the controllable load, does not yet subtract normal household background demand first, and does not credit export revenue.

Fixed net-price colour bands are:

```text
< 0 p/kWh     dark green
0–5           green
5–10          lime
10–20         light green
20–30         yellow
30–40         orange
40–50         red
>= 50         dark red
```

---

## App Settings

App Settings contains Agile tariff/region, selected day, Agile refresh, solar site and refresh, current-location site option, Solar PV panels installed, Solar PV array settings and optimiser load.

When **Solar PV panels installed** is off, PV-array fields and optimiser controls are disabled, PV Forecast and Net Electricity Price are greyed, Solar Forecast remains active, and saved values are retained.

### Solar PV array units

Engineering units remain visible beside editable values:

| Setting | Unit |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

`Number of panels` is dimensionless. Unit labels are presentation-only and are not stored as part of the numeric value.

Azimuth convention: 0° North, 90° East, 180° South, 270° West.

---

## Now button

The Now button appears on Octopus Agile Prices, Solar Forecast, PV Forecast and Net Electricity Price.

Tapping it changes the shared selected date to today, loads today's Agile/solar source data if needed, selects the period satisfying `validFrom <= now < validTo`, and refreshes the derived PV Forecast and Net Electricity Price selections.

---

## Architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        +--> ContentView / PriceWheelView
        +--> SolarForecastView / SolarWheelView
        +--> GenerationEstimateView / GenerationWheelView
        +--> NetEffectivePriceView / NetPriceWheelView
        +--> AppSettingsView
        +--> SolarSiteSettingsView
        +--> DocumentationView
```

`SwipeDashboardView` keeps its historical type name but no longer installs a horizontal page-swipe gesture. It owns the fixed six-button bottom navigation bar and direct page selection.

The user-facing page is named **PV Forecast**, while the implementation type remains `GenerationEstimateView`.

---

## APIs and persistence

Octopus public tariff/rate endpoints are used without account credentials or API key. Open-Meteo supplies forecast and geocoding data.

`AgileCacheStore` persists tariff/rate snapshots. `SolarForecastCache` persists site/date solar forecasts. PV Forecast and Net Electricity Price are derived locally from source data and settings.

Stored locally: selected tariff, solar site coordinates, PV-installed state, PV-array settings, optimiser load and cached Agile/solar data.

---

## UK time and DST

The app uses `Europe/London` and actual timestamps/durations. Normal days contain 48 half-hours; spring/autumn clock changes can contain 46 or 50.

---

## Build and setup

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

Configure Signing & Capabilities, choose the Apple Developer team and run on a simulator or physical device.

Current metadata includes:

```text
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
```

---

## Testing checklist

Before release verify:

- clean Xcode build;
- all six bottom buttons are visible on every page;
- each button directly opens the correct page;
- selected button highlighting follows the current page;
- horizontal dragging never changes pages;
- wheel dragging selects sectors without navigating;
- no obsolete swipe or Back/Next instructions remain in page footers;
- Now works on all four metric pages;
- tariff discovery and 46/48/50-period days;
- solar site by current location, search and manual coordinates;
- PV-installed state and greyed dependent features;
- persistent PV-array unit labels;
- PV Forecast and Net Electricity Price calculations;
- offline cache behaviour;
- in-app documentation matches README and USER_GUIDE.

---

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application. Solar irradiance, PV Forecast and Net Electricity Price are forecasts/derived planning estimates and may differ from actual generation, energy flows and bills.
