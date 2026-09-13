# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application that combines:

- Octopus Energy Agile half-hour electricity prices;
- same-day solar irradiance forecasts;
- estimated half-hour PV generation;
- persistent tariff, site and PV-array settings;
- offline caching for previously downloaded price and solar data.

The app uses Swift, SwiftUI, Foundation and Combine only. It has no third-party package dependencies.

For the complete operating guide, see `USER_GUIDE.md`. The same user documentation is also available inside the app from the information button.

---

## Main swipe navigation

The app has four horizontally swiped pages in this order:

```text
1. Agile Prices
        ↓ swipe left
2. Solar Forecast
        ↓ swipe left
3. PV Generation
        ↓ swipe left
4. App Settings
```

Swipe right to move back:

```text
App Settings → PV Generation → Solar Forecast → Agile Prices
```

App Settings is deliberately the final swipe page so the three day-information pages remain together before configuration.

The four page dots show the current page position. The selected calendar day is shared by Agile Prices, Solar Forecast and PV Generation.

The gear buttons on the Solar Forecast and PV Generation pages jump directly to App Settings.

---

# User-facing features

## Page 1 — Agile Prices

The Agile Prices page displays the selected Octopus Energy Agile tariff as an interactive 24-hour wheel.

Each wheel sector represents one published half-hour settlement period. The wheel is dynamic and can display 46, 48 or 50 periods depending on UK daylight-saving transitions.

Users can:

- touch or drag around the wheel to select a half-hour;
- see the selected price and time in the wheel centre;
- see the day's lowest price and time;
- see the day's highest price and time;
- see the average price;
- see the currently chosen half-hour;
- switch between Prices, Chart and Details views.

### Price colours

Negative prices are blue.

Positive prices are coloured relative to the selected day:

- green = cheaper positive periods;
- yellow/orange = mid-range periods;
- red = more expensive periods.

This is a relative daily colour scale, not a fixed universal threshold.

### Price data-source status

The page shows one of:

```text
SERVER DATA · updated <time>
LOCAL CACHE · saved <time>
NO DATA
```

The app restores cached data first when available, then attempts a live Octopus refresh.

---

## Page 2 — Solar Forecast

Swiping left from Agile Prices opens the Solar Forecast page for the same selected UK calendar day.

The solar wheel shows **global horizontal irradiance (GHI)**, also described as shortwave solar radiation, in **W/m²**.

The page shows:

- one interactive sector per half-hour;
- selected half-hour irradiance;
- peak irradiance and its time;
- daylight-average irradiance;
- forecast-site latitude and longitude;
- server/local-cache status.

Touch or drag around the solar wheel to inspect a half-hour.

### Solar data source

Solar data comes from the Open-Meteo Forecast API using 15-minute `shortwave_radiation` values. Consecutive 15-minute samples are combined into half-hour values so they align with Agile settlement periods.

### Solar site

A solar site must be configured before a forecast can be downloaded. The site can be set by:

1. searching for a place name or postcode through Open-Meteo geocoding; or
2. manually entering latitude and longitude.

The app currently does not request live iPhone GPS permission.

---

## Page 3 — PV Generation

Swiping left from Solar Forecast opens the PV Generation page.

This is another interactive half-hour wheel, but each sector represents the estimated electrical energy produced during that period in **kWh**.

The page displays:

- estimated total generation for the selected day in kWh;
- peak estimated output in kW and its time;
- selected half-hour energy in kWh;
- selected half-hour average power in kW;
- effective PV-array capacity used in the estimate;
- a summary of the active calculation and limitations.

Touch or drag around the wheel to inspect any half-hour.

The generation page has no separate server API. It is derived locally from the loaded solar forecast and the stored PV settings.

---

## Page 4 — App Settings

App Settings is the final swipe page and centralises all application configuration.

It contains:

- selected Agile tariff;
- selected calendar day;
- Refresh Agile prices;
- solar forecast site;
- Refresh solar forecast;
- Agile and solar data-source status;
- PV-array configuration.

Changing the selected date updates the price, solar and generation views together.

Changing PV settings immediately changes the locally calculated generation estimate.

---

# Solar PV array configuration

`AppSettingsStore` persists the following PV-array fields in `UserDefaults`:

- array name;
- rated peak power in kWp;
- panel count;
- individual panel power in watts;
- panel tilt in degrees;
- panel azimuth in degrees;
- inverter maximum AC output in kW;
- estimated system losses in percent;
- free-text notes.

Azimuth convention:

```text
0°   North
90°  East
180° South
270° West
```

If panel count and individual panel power are entered, the app calculates:

```text
panel-derived kWp = panel count × panel watts / 1000
```

For generation estimates, explicitly entered rated kWp takes priority. If rated kWp is blank, the panel-derived kWp value is used when available.

---

# PV generation calculation

For each `SolarHalfHour`, the current generation model calculates:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power (kW) = effective array kWp × irradiance factor
loss-adjusted power = raw PV power × generation loss factor
```

Where:

```text
generation loss factor = 1 - (system loss % / 100)
```

The configured loss percentage is clamped to a valid range before use. A blank loss field means no additional loss correction.

If a positive inverter maximum is configured:

```text
estimated power = min(loss-adjusted power, inverter max kW)
```

Otherwise:

```text
estimated power = loss-adjusted power
```

Then:

```text
period hours = (validTo - validFrom) / 3600
estimated energy (kWh) = estimated power (kW) × period hours
```

Using the actual period duration avoids hard-coding every period to exactly 0.5 hours.

## Current model limitations

The weather input is currently **GHI on a horizontal surface**, not plane-of-array irradiance.

Therefore the current model does not yet apply stored:

- panel tilt;
- panel azimuth.

It also does not yet explicitly model:

- local shading;
- panel temperature effects;
- snow or soiling;
- detailed inverter efficiency curves;
- string/mismatch losses;
- degradation;
- horizon obstruction;
- albedo/reflection effects.

The result should be treated as a first-order forecast estimate rather than guaranteed generation.

---

# How the app works

## High-level architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +--------------------+---------------------+----------------------+------------------+
        |                    |                     |                      |
        v                    v                     v                      v
ContentView          SolarForecastView   GenerationEstimateView   AppSettingsView
        |                    |                     |                      |
        v                    v                     |                      v
AgileViewModel       SolarForecastModel           |              AppSettingsStore
        |                    |                     |
        |                    |                     +--> Solar forecast + PV settings
        |                    |
        +--> OctopusAPI      +--> SolarForecastAPI
        |                    |       |
        |                    |       +--> Open-Meteo Forecast API
        |                    |       +--> Open-Meteo Geocoding API
        |                    |
        +--> AgileCacheStore +--> SolarForecastCache
```

### `AgilePriceWheelApp.swift`

Application entry point. Creates the shared `AgileViewModel` and launches `SwipeDashboardView`.

### `SwipeDashboardView.swift`

Coordinates the four-page horizontal navigation in this order:

```text
Agile Prices → Solar Forecast → PV Generation → App Settings
```

It owns:

- `SolarForecastModel`;
- `AppSettingsStore`;
- current swipe page state.

It also:

- reloads solar data when the selected Agile date changes;
- keeps price, solar and generation on the same day;
- presents the in-app documentation;
- lets solar/generation gear buttons jump directly to Settings.

### `ContentView.swift`

Main Agile price dashboard. Handles:

- price wheel;
- summary tiles;
- Chart and Details tabs;
- data-source badge;
- tariff/date settings sheet;
- documentation button.

### `PriceWheelView.swift`

Draws the price wheel and maps touch/drag position to the selected half-hour.

### `AgileViewModel.swift`

Owns:

- discovered tariffs;
- selected tariff;
- selected date;
- half-hour rates;
- selected rate;
- loading state;
- errors and sync messages;
- server/cache origin.

Startup is offline-first: cached data is restored when available and then replaced by server data when refresh succeeds.

### `OctopusAPI.swift`

Native `URLSession` networking layer for public Octopus Energy REST endpoints.

It dynamically discovers Agile import tariffs and downloads standard unit rates for a UK calendar day.

### `AgileCacheStore.swift`

Stores:

- latest Agile tariff catalogue;
- downloaded tariff/date rate snapshots.

Data is stored as JSON in Application Support.

### `SolarForecast.swift`

Contains:

- `SiteLocation`;
- `SolarHalfHour`;
- `SiteSearchResult`;
- `SolarForecastModel`;
- `SolarForecastAPI`;
- `SolarForecastCache`;
- Open-Meteo response models and errors.

### `SolarForecastView.swift`

Displays the solar irradiance wheel and solar summary tiles.

### `SolarSiteSettingsView.swift`

Provides place/postcode search and manual latitude/longitude editing.

### `AppSettingsStore.swift`

Persists PV-array settings and exposes parsed values used by the generation model, including effective kWp, loss factor and inverter limit.

### `GenerationEstimateView.swift`

Defines:

- `GenerationHalfHour`;
- `GenerationEstimateView`;
- `GenerationWheelView`.

It converts loaded solar forecast values plus PV settings into half-hour electrical power/energy estimates locally.

### `AppSettingsView.swift`

Final swipe page containing tariff, date, refresh, solar-site and PV-array controls.

### `DocumentationView.swift`

Complete user-facing guide compiled into the app and available offline.

---

# Octopus Energy integration

Base URL:

```text
https://api.octopus.energy/v1/
```

The app dynamically discovers current Agile products/tariffs instead of embedding a single historical tariff code.

Rates are requested from an endpoint of the form:

```text
/v1/products/{product-code}/electricity-tariffs/{tariff-code}/standard-unit-rates/
```

Requests use UTC ISO-8601 period bounds derived from the selected `Europe/London` calendar day.

The public endpoints used do not require:

- Octopus account number;
- Octopus API key;
- MPAN;
- meter serial number;
- Octopus login credentials.

---

# Open-Meteo integration

Solar forecast endpoint:

```text
https://api.open-meteo.com/v1/forecast
```

The app requests 15-minute `shortwave_radiation` values for the selected site/date and combines them into half-hour periods.

Geocoding endpoint:

```text
https://geocoding-api.open-meteo.com/v1/search
```

The configured latitude/longitude is sent to Open-Meteo when requesting a forecast.

---

# UK time and daylight-saving handling

The app uses `Europe/London` calendar logic.

Typical day sizes are:

```text
Normal day          48 half-hours
Spring DST change   46 half-hours
Autumn DST change   50 half-hours
```

The app works from actual timestamps rather than assuming every day has exactly 48 periods.

Generation energy uses each solar period's actual duration.

---

# Offline behaviour

## Agile cache

`AgileCacheStore` persists:

- tariff catalogue;
- each successfully downloaded tariff/date price set.

## Solar cache

`SolarForecastCache` persists each successfully downloaded site/date solar forecast, keyed by site coordinates and date.

## Generation offline behaviour

Generation is calculated locally and has no separate network dependency.

If the selected day/site solar forecast is already cached and PV settings are stored, PV Generation can be recalculated offline.

Offline mode cannot obtain data that has never previously been downloaded.

---

# Persistence

`UserDefaults` stores lightweight settings:

- selected tariff;
- solar-site name and coordinates;
- PV-array configuration.

Application Support JSON stores:

- tariff metadata;
- Agile rate snapshots;
- solar forecast snapshots.

Generation estimates are calculated on demand rather than stored separately.

---

# Privacy

The app does not currently require:

- Octopus account credentials;
- API key;
- MPAN;
- meter serial number;
- payment information;
- live device GPS permission.

PV settings and derived generation estimates remain local in the current implementation.

Site coordinates are sent to Open-Meteo only when required for forecast/geocoding operations.

---

# Dependencies

## Third-party packages

**None.**

## Apple frameworks

- SwiftUI
- Foundation
- Combine

Networking uses `URLSession`.

JSON uses `Codable`, `JSONEncoder` and `JSONDecoder`.

---

# Build and setup

Current project metadata includes:

```text
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
```

Clone and open:

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

In Xcode:

1. select the AgilePriceWheel target;
2. open Signing & Capabilities;
3. enable automatic signing;
4. select the correct Apple Developer team;
5. choose a simulator or connected iPhone;
6. press `⌘R` to run.

No Octopus or Open-Meteo API secret is required by the public endpoints currently used.

---

# Refresh behaviour

App Settings contains:

```text
Refresh Agile prices
Refresh solar forecast
```

A successful refresh updates the appropriate cache.

A failed refresh leaves an existing cached copy available.

PV Generation has no separate refresh because it automatically recalculates from the current solar forecast and current PV settings.

---

# Troubleshooting

## No Agile prices

Check:

- selected tariff;
- selected date;
- whether Octopus has published that day's rates;
- network availability;
- data-source badge.

Try **Refresh Agile prices**.

## Solar Forecast empty

Check:

- solar site is configured;
- coordinates are valid;
- network availability;
- selected date is within available Open-Meteo data.

Try **Refresh solar forecast**.

## PV Generation empty

Check:

- solar forecast exists for the selected day;
- rated kWp is set, or panel count plus panel watts are set;
- inverter/loss settings are valid.

## Generation appears too high or too low

Check:

- rated kWp;
- panel count and rating;
- inverter limit;
- loss percentage.

Remember that the current model does not yet apply tilt, azimuth, shading or temperature corrections.

---

# Testing checklist

Before releasing a functional update, test at least:

- project builds cleanly;
- app launches online;
- app launches offline after caches are populated;
- swipe Prices → Solar → Generation → Settings;
- swipe Settings → Generation → Solar → Prices;
- page dots match the current page;
- vertical scrolling does not accidentally change pages;
- solar/generation gear buttons jump to Settings;
- tariff discovery, selection and persistence;
- selected day remains consistent across price, solar and generation pages;
- 46/48/50-period days;
- price-wheel selection;
- lowest/highest time display;
- solar site search;
- manual coordinate validation;
- solar-wheel selection;
- Agile and solar server/cache badges;
- PV settings persist after restart;
- explicit kWp overrides panel-derived kWp;
- loss percentage affects generation;
- inverter clipping works;
- generation day total equals the sum of half-hour estimates;
- cached solar data can drive generation offline;
- in-app documentation and `USER_GUIDE.md` match current behaviour.

---

# Documentation maintenance

Documentation is part of the implementation.

Every functional change must review and update all relevant documentation:

```text
README.md
USER_GUIDE.md
AgilePriceWheel/DocumentationView.swift
DOCUMENTATION_POLICY.md (when the documentation process itself changes)
```

See `DOCUMENTATION_POLICY.md` for the maintenance rule.

---

# Planned improvements

Potential next steps include:

- direct/diffuse irradiance components;
- solar-position calculation;
- plane-of-array irradiance;
- use of stored tilt and azimuth;
- temperature correction;
- shading/horizon loss modelling;
- improved inverter-efficiency modelling;
- measured-generation comparison;
- combined Agile-price + PV-generation optimisation for batteries, EV charging, hot water and flexible loads.

---

# Disclaimer

Agile Price Wheel is an independent application using publicly available Octopus Energy and Open-Meteo information. It is not an official application of either service.

Electricity prices should be verified against the user's actual Octopus tariff/account before billing or financial decisions.

Solar irradiance values are weather-model forecasts. PV Generation values are derived estimates and may differ materially from actual generation.
