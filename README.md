# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile electricity prices, solar irradiance forecasts, a local PV Forecast, a solar-adjusted Net Electricity Price and forecast PV Cost Savings.

The first dashboard page is presented to the user as **Octopus Agile Prices**. The Xcode project and GitHub repository remain named `AgilePriceWheel`.

The app uses Apple frameworks only (`SwiftUI`, `Foundation`, `Combine`, `CoreLocation`) and has no third-party package dependencies.

## Documentation index

- [Main page navigation](#main-page-navigation)
- [Octopus Agile Prices](#octopus-agile-prices)
- [Solar Forecast](#solar-forecast)
- [PV Forecast](#pv-forecast)
- [Net Electricity Price](#net-electricity-price)
- [Cost Savings](#cost-savings)
- [App Settings](#app-settings)
- [Now button](#now-button)
- [Architecture](#architecture)
- [APIs and persistence](#apis-and-persistence)
- [Build and setup](#build-and-setup)
- [Testing checklist](#testing-checklist)
- [`USER_GUIDE.md`](USER_GUIDE.md) — complete user guide
- [`docs/INDEX.md`](docs/INDEX.md) — central documentation index
- [`DOCUMENTATION_POLICY.md`](DOCUMENTATION_POLICY.md) — documentation maintenance policy

The same core guidance is built into the app in `AgilePriceWheel/DocumentationView.swift`.

---

## Main page navigation

The app defines seven pages:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings
6. App Settings
7. User Guide

Horizontal swipe navigation is deliberately disabled so dragging around an interactive wheel cannot accidentally change the main page.

When **Solar PV panels installed** is **ON**, the bottom navigation shows all seven buttons:

| Button | SF Symbol | Page |
|---|---|---|
| Prices | `bolt.circle.fill` | Octopus Agile Prices |
| Solar | `sun.max.fill` | Solar Forecast |
| PV | `bolt.fill` | PV Forecast |
| Net | `sterlingsign.circle.fill` | Net Electricity Price |
| Save | `banknote.fill` | Cost Savings |
| Settings | `slider.horizontal.3` | App Settings |
| Guide | `book.closed.fill` | User Guide |

The PV button deliberately uses the simple filled lightning-bolt SF Symbol so it matches the visual weight and style of the other bottom-navigation controls.

When **Solar PV panels installed** is **OFF**, the PV-dependent buttons **PV**, **Net** and **Save** are hidden, leaving four visible buttons: **Prices**, **Solar**, **Settings** and **Guide**. Turning PV back on immediately restores the three hidden pages and buttons. Saved PV-array and optimiser values are retained while PV is off.

The selected page button is highlighted in orange. The previous Back/Next controls, page dots and page-number indicator remain removed.

The visible metric pages show a **Now** button. With PV enabled there are five metric pages; with PV disabled only Prices and Solar remain visible.

---

## Octopus Agile Prices

The first page displays the selected Octopus Energy Agile import tariff as an interactive half-hour wheel.

Features include dynamic Agile tariff discovery, regional tariff selection, 46/48/50-period UK DST support, touch/drag wheel selection, selected/lowest/highest/average prices, Prices/Chart/Details views, live-server/local-cache status and persistent tariff selection.

Negative Agile prices are blue. Positive prices use a day-relative green-to-red scale.

---

## Solar Forecast

Solar Forecast displays global horizontal irradiance (GHI / shortwave radiation) in W/m² for the selected day. Open-Meteo 15-minute `shortwave_radiation` samples are combined into half-hour values.

The page shows an interactive solar wheel, selected irradiance, peak irradiance/time, daylight average, forecast-site coordinates and source/cache status.

The solar site can be set using Current Location, place/postcode search or manual latitude/longitude. Current-location access is opt-in and When-In-Use only.

When **Use Current Location** is selected, the app reverse-geocodes the returned coordinates using Apple's geocoding service and saves a familiar locality/town name as the solar-site label. If no suitable place name can be resolved, the label falls back to **Current location**. The saved site name can then be edited by the user without changing the latitude or longitude used for the forecast.

Solar Forecast remains available even when the property is configured as having no PV panels installed.

---

## PV Forecast

PV Forecast converts the solar irradiance forecast into a first-order estimate of PV electrical output for the configured array. Each wheel sector represents estimated kWh during that half-hour.

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective array kWp × irradiance factor
loss-adjusted power = raw power × (1 - system loss % / 100)
estimated power = min(loss-adjusted power, inverter maximum)  [if set]
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority. If blank, capacity can be derived from panel count × panel watts / 1000.

Tilt and azimuth are stored but are not yet applied because the current weather input is horizontal GHI rather than plane-of-array irradiance.

PV Forecast is hidden from navigation when **Solar PV panels installed** is off and returns when it is turned on again.

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

The selected wheel sector also displays its **PV cost saving** in pence. The same figure appears in the Selected half-hour breakdown.

PV cost saving is:

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The default optimiser load is **3.0 kW**. The model assumes forecast PV is first available to the configured controllable load. Household background consumption and export revenue are not separately included.

Fixed net-price colour bands remain:

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

Net Electricity Price is hidden from navigation when **Solar PV panels installed** is off and returns when it is turned on again.

---

## Cost Savings

Cost Savings is a separate half-hour wheel showing the forecast monetary saving from PV energy that offsets the configured load.

For each half-hour:

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The page shows:

- saving for each half-hour;
- selected half-hour saving;
- forecast total saving for the selected day;
- best-saving half-hour;
- total avoided grid import;
- selected Agile price, PV generation and PV used against the load.

Only PV that offsets the configured load is treated as an import-cost saving. Surplus PV export income is **not** included.

When Agile prices are negative, the calculated saving can be negative. In that situation importing electricity would have been financially beneficial, so PV generation can reduce that benefit. Negative saving sectors are shown red; positive saving sectors use green intensity.

Cost Savings is hidden from navigation when **Solar PV panels installed** is off and returns when it is turned on again.

---

## App Settings

App Settings contains Agile tariff/region, selected day, source refresh, solar site, PV availability, Solar PV array settings and optimiser load.

The Current solar site section includes an editable site-name field. Editing the site name changes only the display label; the saved forecast coordinates remain unchanged.

When **Solar PV panels installed** is off:

- PV Forecast, Net Electricity Price and Cost Savings are hidden from bottom navigation;
- the navigation contracts from seven buttons to four;
- PV-array fields and optimiser controls are disabled;
- Solar Forecast remains active;
- saved PV and optimiser values are retained.

Turning **Solar PV panels installed** back on restores the PV, Net and Save buttons immediately and reuses the retained settings.

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

`Number of panels` is dimensionless. Unit labels are presentation-only.

---

## Now button

The Now button is available on the metric pages that are currently visible:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast — when PV is enabled
4. Net Electricity Price — when PV is enabled
5. Cost Savings — when PV is enabled

Tapping it changes the shared selected date to today, loads today's Agile/solar source data if needed, selects the period satisfying `validFrom <= now < validTo`, and refreshes derived metric views.

The button is part of the adaptive page layout rather than a floating overlay, so SwiftUI reserves space for it and it should not cover descriptions, wheels or metric cards on supported iPhone sizes.

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
        +--> CostSavingsView / CostSavingsWheelView
        +--> AppSettingsView
        +--> SolarSiteSettingsView
        +--> DocumentationView
```

`SwipeDashboardView` keeps its historical type name but no longer installs a page-swipe gesture. It owns conditional bottom navigation, shared Now behaviour, and the rule that PV-dependent pages are hidden when PV is disabled.

---

## APIs and persistence

Octopus public tariff/rate endpoints are used without account credentials or API key. Open-Meteo supplies forecast and place/postcode search data. Apple's reverse-geocoding service is used only after the user taps **Use Current Location**, to turn the returned coordinates into a readable solar-site name.

`AgileCacheStore` persists tariff/rate snapshots. `SolarForecastCache` persists site/date solar forecasts. PV Forecast, Net Electricity Price and Cost Savings are calculated locally from source data and settings.

The app uses `Europe/London` and actual period timestamps/durations, supporting normal 48-period days and 46/50-period DST days.

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
- with PV enabled, all seven bottom buttons are visible on supported iPhone sizes;
- the PV button uses the simple filled lightning-bolt icon;
- with PV disabled, only Prices, Solar, Settings and Guide are visible;
- turning PV back on restores PV, Net and Save immediately;
- saved PV-array and optimiser values survive an off/on cycle;
- each visible button directly opens the correct page;
- selected button highlighting follows the current page;
- horizontal dragging never changes pages;
- wheel dragging selects sectors without navigating;
- Now works on every visible metric page and does not cover data;
- Use Current Location resolves a familiar place name when reverse geocoding succeeds;
- unresolved current-location names fall back to `Current location`;
- editing the solar-site name changes only the label and preserves the saved coordinates;
- Cost Savings wheel has one sector per matched half-hour;
- selected Cost Savings value matches `min(PV, load) × Agile price`;
- selected Net Electricity Price sector shows the same PV saving value;
- negative Agile prices produce a negative saving when PV offsets load;
- day saving equals the sum of half-hour savings;
- surplus PV above the configured load is not counted as import-cost saving;
- tariff discovery and 46/48/50-period days;
- solar-site selection and caching;
- documentation index and in-app guide match the implementation.

---

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application. Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecasts/derived planning estimates and may differ from actual generation, energy flows and bills.
