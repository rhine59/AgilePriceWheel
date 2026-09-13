# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application that combines Octopus Energy Agile electricity prices, solar irradiance forecasts, PV-generation estimates and a solar-adjusted effective electricity-price optimiser.

The app uses only Apple frameworks (`SwiftUI`, `Foundation`, `Combine`) and has no third-party package dependencies.

For operating instructions see `USER_GUIDE.md`. The same user guide is also available inside the app from the information button.

---

# Main swipe navigation

The application has five horizontal pages, with **App Settings always last**:

```text
1. Agile Prices
        ↓ swipe left
2. Solar Forecast
        ↓ swipe left
3. PV Generation
        ↓ swipe left
4. Net Electricity Price
        ↓ swipe left
5. App Settings
```

Swipe right to move back in the opposite direction.

The five page dots show the current position. The selected date is shared across the price, solar, generation and net-price pages. Gear buttons on the solar, generation and net-price pages jump directly to App Settings.

---

# What each page does

## 1. Agile Prices

Displays the selected Octopus Energy Agile import tariff as an interactive half-hour wheel.

Features:

- dynamic discovery of currently available Agile import tariffs;
- one wheel sector per returned settlement period;
- 46/48/50-period support for UK daylight-saving days;
- touch/drag half-hour selection;
- selected, lowest, highest and average prices;
- lowest/highest period times;
- Prices, Chart and Details views;
- server/local-cache status;
- persistent selected tariff.

Negative prices are blue. Positive prices use a day-relative green-to-red scale.

## 2. Solar Forecast

Displays same-day forecast global horizontal irradiance (GHI / shortwave radiation) in **W/m²**.

Features:

- Open-Meteo 15-minute shortwave-radiation input;
- 15-minute samples combined into half-hour values;
- interactive half-hour solar wheel;
- peak irradiance and time;
- daylight average;
- selected period;
- configured site coordinates;
- server/local-cache status.

A solar site can be set by place/postcode search or manual latitude/longitude.

## 3. PV Generation

Converts the solar forecast into a first-order estimate of PV electrical generation.

Each wheel sector represents estimated **kWh generated during that half-hour**.

The page shows:

- estimated day total (kWh);
- peak estimated output (kW) and time;
- selected half-hour energy (kWh);
- selected half-hour average power (kW);
- effective array capacity used.

## 4. Net Electricity Price

This page reproduces the established logic used by the nightly Agile + solar optimiser email.

It combines:

- Octopus Agile price for each half-hour;
- the configured controllable load;
- forecast PV generation for the same half-hour.

The result is an **effective / adjusted price in p/kWh** for running that complete load after forecast self-generation has reduced expected grid import.

The page contains another interactive half-hour wheel and shows:

- best net price and time;
- highest net price and time;
- average net price;
- configured optimiser load;
- selected published Agile price;
- selected load energy;
- selected forecast PV energy;
- selected expected grid import;
- selected expected slot cost;
- selected net/effective p/kWh.

## 5. App Settings

The final swipe page contains all application configuration:

- Agile tariff and region;
- selected date;
- Agile refresh;
- solar site;
- solar refresh;
- PV-array details;
- optimiser controllable-load power;
- Agile and solar source status.

---

# Net / adjusted electricity-price model

The model intentionally follows the same method used in the nightly email optimiser.

For each half-hour:

```text
period hours = (validTo - validFrom) / 3600
load energy (kWh) = configured load kW × period hours
forecast PV energy (kWh) = PV generation estimate for the same period
grid import (kWh) = max(load energy - forecast PV energy, 0)
slot cost (pence) = grid import × Agile price (p/kWh)
net effective price (p/kWh) = slot cost / load energy
```

Example using the established 3 kW workload:

```text
Agile price             20 p/kWh
3 kW load for 30 min     1.5 kWh
Forecast PV              0.9 kWh
Expected grid import     0.6 kWh
Slot cost               12 p
Net effective price      8 p/kWh
```

The configured optimiser load defaults to **3.0 kW**, matching the historical nightly email model, but can be changed in App Settings.

### Important optimiser assumptions

The model assumes all forecast PV generation is available to the controllable load being evaluated.

It does **not** yet subtract ordinary background household demand before allocating PV to that load. It also does not credit surplus PV export income. Therefore the result is a planning/optimisation figure, not an exact billing forecast.

### Fixed net-price colour bands

The Net Electricity Price wheel uses the same fixed bands as the established email optimiser so colours can be compared between days:

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

# PV system settings

`AppSettingsStore` persists:

- array name;
- rated peak power (kWp);
- panel count;
- panel watts;
- panel tilt;
- panel azimuth;
- inverter maximum AC power (kW);
- system loss percentage;
- optimiser controllable load (kW);
- notes.

Azimuth convention:

```text
0°   North
90°  East
180° South
270° West
```

If rated kWp is blank, the app can derive array capacity from:

```text
panel count × panel watts / 1000
```

An explicitly entered rated kWp value takes priority.

---

# PV generation model

For each solar half-hour:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power (kW) = effective array kWp × irradiance factor
loss-adjusted power = raw PV power × (1 - system loss % / 100)
```

If an inverter maximum is configured:

```text
estimated power = min(loss-adjusted power, inverter max kW)
```

Then:

```text
estimated energy (kWh) = estimated power × actual period duration in hours
```

The model uses actual timestamps rather than hard-coding 0.5 hours.

### Current PV-model limitations

The weather input is GHI on a horizontal surface. Stored tilt and azimuth are not yet applied because the app does not yet calculate plane-of-array irradiance.

The model also does not explicitly include shading, panel temperature, snow/soiling, detailed inverter efficiency, mismatch, degradation, horizon obstruction or albedo.

---

# Architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +--> ContentView / PriceWheelView
        |       |
        |       +--> AgileViewModel
        |               +--> OctopusAPI
        |               +--> AgileCacheStore
        |
        +--> SolarForecastView / SolarWheelView
        |       |
        |       +--> SolarForecastModel
        |               +--> SolarForecastAPI
        |               +--> SolarForecastCache
        |
        +--> GenerationEstimateView / GenerationWheelView
        |       +--> SolarForecastModel
        |       +--> AppSettingsStore
        |
        +--> NetEffectivePriceView / NetPriceWheelView
        |       +--> AgileViewModel
        |       +--> SolarForecastModel
        |       +--> AppSettingsStore
        |
        +--> AppSettingsView
                +--> AppSettingsStore
```

## Key source files

- `AgilePriceWheelApp.swift` — application entry point.
- `SwipeDashboardView.swift` — five-page swipe navigation and shared coordination.
- `ContentView.swift` — Agile dashboard.
- `PriceWheelView.swift` — Agile wheel rendering/selection.
- `AgileViewModel.swift` — tariff/rate state and refresh logic.
- `OctopusAPI.swift` — Octopus REST client.
- `AgileCacheStore.swift` — tariff/rate JSON cache.
- `SolarForecast.swift` — solar site, API, model and cache.
- `SolarForecastView.swift` — irradiance wheel.
- `GenerationEstimateView.swift` — generation calculation and wheel.
- `NetEffectivePriceView.swift` — Agile + PV optimiser calculation and net-price wheel.
- `AppSettingsStore.swift` — persistent PV and optimiser settings.
- `AppSettingsView.swift` — final settings page.
- `SolarSiteSettingsView.swift` — geocoding/manual-coordinate editor.
- `DocumentationView.swift` — in-app user guide.

---

# Data flow

## Agile

```text
Octopus public API → OctopusAPI → AgileViewModel → Price UI
                                      ↓
                               AgileCacheStore
```

## Solar

```text
Open-Meteo → SolarForecastAPI → SolarForecastModel → Solar UI
                                      ↓
                              SolarForecastCache
```

## PV generation

```text
SolarForecastModel + AppSettingsStore → local PV calculation → Generation wheel
```

## Net electricity price

```text
AgileViewModel rates
        +
Solar forecast / PV settings
        +
configured optimiser load
        ↓
local half-hour optimiser
        ↓
NetPriceHalfHour → Net Price wheel
```

No separate server or cache is needed for generation or net-price results because both are deterministically recalculated from the loaded price/solar data and local settings.

---

# APIs

## Octopus Energy

Base URL:

```text
https://api.octopus.energy/v1/
```

The app dynamically discovers Agile import products/tariffs and retrieves standard unit rates. The public endpoints used do not require an Octopus API key or account credentials.

## Open-Meteo forecast

```text
https://api.open-meteo.com/v1/forecast
```

The app requests 15-minute `shortwave_radiation` data for the selected coordinates/date.

## Open-Meteo geocoding

```text
https://geocoding-api.open-meteo.com/v1/search
```

Used for place/postcode site search.

---

# UK time and DST

The app uses `Europe/London` calendar logic.

Typical day lengths:

```text
normal day          48 half-hours
spring DST day      46 half-hours
autumn DST day      50 half-hours
```

Actual timestamps and period durations are used throughout.

---

# Offline behaviour

`AgileCacheStore` persists the tariff catalogue and downloaded tariff/date rate sets.

`SolarForecastCache` persists downloaded site/date solar forecasts.

When both required source datasets are cached, PV Generation and Net Electricity Price can be recalculated offline because their calculations are local.

Offline mode cannot fetch a tariff/day/site that was never previously downloaded.

---

# Persistence and privacy

`UserDefaults` stores:

- selected tariff code;
- solar site name/coordinates;
- PV-array configuration;
- optimiser load.

Application Support JSON stores Agile and solar cache snapshots.

The app does not require Octopus login credentials, API key, MPAN, meter serial number, payment details or live GPS permission.

Configured coordinates are sent to Open-Meteo for forecast/geocoding requests. PV settings, optimiser load, generation estimates and net-price calculations remain local.

---

# Build and setup

Current project metadata includes:

```text
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
```

Clone/open:

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

In Xcode configure Signing & Capabilities, choose the Apple Developer team, select an iPhone/simulator and run with `⌘R`.

The project uses a filesystem-synchronised Xcode group, so new Swift source files in `AgilePriceWheel/` are normally picked up automatically.

---

# Refresh behaviour

App Settings provides:

```text
Refresh Agile prices
Refresh solar forecast
```

PV Generation and Net Electricity Price recalculate automatically when prices, solar data or settings change.

If an online refresh fails and a cache exists, the cached source data remains available.

---

# Testing checklist

Before release test:

- clean Xcode build;
- five-page order Prices → Solar → Generation → Net Price → Settings;
- reverse swiping;
- Settings remains last;
- page dots show 1–5 correctly;
- vertical scrolling does not trigger page changes;
- tariff discovery/selection;
- selected date synchronization;
- 46/48/50-period days;
- price-wheel selection;
- solar site search/manual coordinates;
- solar-wheel selection;
- PV settings persistence;
- PV generation totals/selection;
- optimiser-load persistence and default 3.0 kW;
- net-price half-hour alignment;
- net-price formula against a hand-worked example;
- fixed net-price colour bands;
- negative Agile prices;
- PV greater than load (grid import floors at zero);
- inverter clipping and system losses;
- online and cached/offline source data;
- in-app documentation matches the implementation.

---

# Documentation maintenance

Every functional change must review and update:

```text
README.md
USER_GUIDE.md
AgilePriceWheel/DocumentationView.swift
```

See `DOCUMENTATION_POLICY.md`.

---

# Disclaimer

Agile Price Wheel is an independent application using public Octopus Energy and Open-Meteo data. It is not an official application of either service.

Agile prices should be verified against the user's actual tariff before financial decisions. Solar and PV figures are forecasts/estimates. The Net Electricity Price page is an optimisation aid and does not yet include household background load allocation or export revenue.
