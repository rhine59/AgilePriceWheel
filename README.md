# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile electricity prices, solar irradiance forecasts, a local PV Forecast, a solar-adjusted Net Electricity Price and forecast PV Cost Savings.

The first dashboard page is presented to the user as **Octopus Agile Prices**. The Xcode project and GitHub repository remain named `AgilePriceWheel`.

The app uses Apple frameworks only (`SwiftUI`, `Foundation`, `Combine`, `CoreLocation`, `MapKit`) and has no third-party package dependencies.

## Documentation index

- [Main page navigation](#main-page-navigation)
- [Adaptive screen handling](#adaptive-screen-handling)
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
- [`USER_GUIDE.md`](USER_GUIDE.md) — complete indexed user guide
- [`docs/INDEX.md`](docs/INDEX.md) — central documentation index
- [`docs/NOW_BUTTON_AND_CURRENT_TIME.md`](docs/NOW_BUTTON_AND_CURRENT_TIME.md) — current-time behaviour
- [`docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) — responsive layout rules and test matrix
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

When **Solar PV panels installed** is **ON**, the bottom navigation exposes all seven pages:

| Button | SF Symbol | Page |
|---|---|---|
| Prices | `bolt.circle.fill` | Octopus Agile Prices |
| Solar | `sun.max.fill` | Solar Forecast |
| PV | `bolt.fill` | PV Forecast |
| Net | `sterlingsign.circle.fill` | Net Electricity Price |
| Save | `banknote.fill` | Cost Savings |
| Settings | `slider.horizontal.3` | App Settings |
| Guide | `book.closed.fill` | User Guide |

When **Solar PV panels installed** is **OFF**, **PV**, **Net** and **Save** are hidden, leaving **Prices**, **Solar**, **Settings** and **Guide**. Turning PV back on immediately restores the three hidden pages. Saved PV-array and optimiser values are retained.

The selected page button is highlighted in orange.

---

## Adaptive screen handling

The top-level dashboard is designed to adapt across compact iPhone widths, larger iPhones and regular-width iPad layouts without device-specific positioning.

`SwipeDashboardView` now uses:

- `ViewThatFits(in: .horizontal)` for bottom navigation;
- normal icon + label navigation when space permits;
- compact icon + label navigation on narrower widths;
- icon-only navigation as a final narrow-width fallback while preserving accessibility labels;
- minimum 44-point navigation tap height;
- `ViewThatFits` for metric and Settings headers, switching from a single-row header to a stacked layout when necessary;
- smaller horizontal margins in compact width and wider margins in regular width;
- centred, width-limited metric content on large displays rather than stretching indefinitely;
- normal layout flow for the Now button rather than floating overlays;
- a scalable Octopus Agile Prices title overlay that reserves space for the gear and information controls.

Current content limits are 680 points on compact-width layouts and 760 points on regular-width layouts.

See [`docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) for the detailed rules and release test matrix.

---

## Octopus Agile Prices

The first page displays the selected Octopus Energy Agile import tariff as an interactive half-hour wheel.

Features include dynamic Agile tariff discovery, regional tariff selection, 46/48/50-period UK DST support, touch/drag wheel selection, selected/lowest/highest/average prices, Prices/Chart/Details views, live-server/local-cache status and persistent tariff selection.

Negative Agile prices are blue. Positive prices use a day-relative green-to-red scale.

---

## Solar Forecast

Solar Forecast displays global horizontal irradiance (GHI / shortwave radiation) in W/m² for the selected day. Open-Meteo 15-minute `shortwave_radiation` samples are combined into half-hour values.

The solar site can be set using Current Location, place/postcode search or manual latitude/longitude. Current-location access is opt-in and When-In-Use only.

When **Use Current Location** is selected, the app reverse-geocodes the coordinates using Apple geocoding APIs and saves a familiar locality/town name as the site label. On iOS 26 and later it uses MapKit `MKReverseGeocodingRequest`; older supported systems use the legacy Core Location geocoder only in the compatibility path. If no suitable name is resolved, the label falls back to **Current location**. The user can edit the saved site name without changing latitude or longitude.

Solar Forecast remains available when PV is disabled.

---

## PV Forecast

PV Forecast converts solar irradiance into a first-order estimate of PV electrical output for the configured array.

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective array kWp × irradiance factor
loss-adjusted power = raw power × (1 - system loss % / 100)
estimated power = min(loss-adjusted power, inverter maximum)  [if set]
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority. If blank, capacity can be derived from panel count × panel watts / 1000. Tilt and azimuth are stored but not yet applied by the current GHI-based model.

PV Forecast is hidden from navigation when PV is off and returns when PV is turned on again.

---

## Net Electricity Price

```text
load energy = load kW × period hours
forecast PV = forecast PV energy for the same period
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net effective price = slot cost / complete load energy
```

The selected wheel sector also displays its **PV cost saving** in pence.

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The default optimiser load is **3.0 kW**. Household background demand and export revenue are not separately included.

Net Electricity Price is hidden from navigation when PV is off.

---

## Cost Savings

Cost Savings shows the forecast monetary value of PV generation that offsets the configured controllable load.

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The page shows half-hour saving, day total, best-saving half-hour, total avoided grid import and a selected-period breakdown. Surplus export income is not included. Negative Agile prices can produce a negative saving.

Cost Savings is hidden from navigation when PV is off.

---

## App Settings

App Settings contains Agile tariff/region, selected day, source refresh, solar site, PV availability, Solar PV array settings and optimiser load.

The Current solar site section includes an editable site name plus stored latitude/longitude.

When **Solar PV panels installed** is off:

- PV Forecast, Net Electricity Price and Cost Savings are hidden from navigation;
- the navigation contracts from seven buttons to four;
- PV-array fields and optimiser controls are disabled;
- Solar Forecast remains active;
- saved PV and optimiser values are retained.

Turning PV back on restores the three hidden pages immediately.

### Solar PV array units

| Setting | Unit |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

`Number of panels` is dimensionless.

---

## Now button

The Now button is available on every visible metric page. It returns the shared selected date to today, loads today's source data if needed and selects the half-hour satisfying:

```text
validFrom <= now < validTo
```

The button is part of normal layout flow and does not use fixed vertical offsets.

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

`SwipeDashboardView` owns conditional navigation, adaptive screen layout, shared Now behaviour and PV-dependent page visibility.

---

## APIs and persistence

Octopus public tariff/rate endpoints are used without account credentials or API key. Open-Meteo supplies forecast and place/postcode search data. Current-location coordinates come from Core Location after explicit user action. Reverse geocoding uses MapKit `MKReverseGeocodingRequest` on iOS 26 and later, with a legacy Core Location compatibility path for earlier supported systems. The app no longer calls the global Location Services availability check synchronously on the main thread; authorization changes are handled through `CLLocationManagerDelegate`.

`AgileCacheStore` persists tariff/rate snapshots. `SolarForecastCache` persists site/date solar forecasts. PV Forecast, Net Electricity Price and Cost Savings are calculated locally.

The app uses `Europe/London` and actual period timestamps/durations, supporting 46/48/50-period days.

---

## Build and setup

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

Configure Signing & Capabilities, choose the Apple Developer team and run on a simulator or physical device.

Current metadata:

```text
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
```

---

## Testing checklist

Before release verify:

- clean Xcode build;
- no location-related deprecation warnings on the current Xcode/iOS 26 SDK path;
- no Core Location main-thread responsiveness warning from the current-location button;
- small iPhone, standard iPhone, Max-size iPhone and regular-width iPad layouts;
- at least one larger Dynamic Type setting;
- no header/title collisions;
- no clipped bottom navigation;
- navigation correctly falls back from normal labels to compact labels or icons only when required;
- all visible navigation targets remain at least 44 points high;
- with PV enabled, all seven page buttons are available;
- with PV disabled, only Prices, Solar, Settings and Guide are visible;
- turning PV back on restores PV, Net and Save;
- the PV button uses `bolt.fill`;
- wheel dragging never changes page;
- Now never overlays page content;
- Use Current Location resolves a familiar name when possible and falls back safely;
- editing the site name preserves coordinates;
- Cost Savings and Net selected-sector PV saving agree;
- negative Agile prices can produce negative savings;
- tariff discovery and 46/48/50-period days work;
- documentation matches the implementation.

---

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application. Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecast/derived planning estimates and may differ from actual generation, energy flows and bills.
