# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application that combines Octopus Energy Agile half-hour electricity prices, same-day solar irradiance forecasting, persistent PV-system settings and a derived half-hour PV generation estimate.

The app is deliberately lightweight. It uses Swift, SwiftUI, Foundation and Combine only, with no third-party package dependencies.

---

## Main navigation

The main interface now has four horizontally swiped pages:

1. **Agile Prices** — interactive half-hour electricity-price wheel.
2. **Solar Forecast** — half-hour global horizontal irradiance (GHI) in W/m².
3. **App Settings** — tariff/day/site/PV configuration and refresh controls.
4. **PV Generation** — derived half-hour estimated electrical generation in kWh.

Swipe left to move:

```text
Agile Prices → Solar Forecast → App Settings → PV Generation
```

Swipe right to move back in the opposite direction.

The selected calendar day is shared across the price, solar and generation views.

---

## Main features

### Agile electricity prices

- Dynamically discovers currently available Octopus Energy Agile import tariffs.
- Supports all UK Octopus electricity regions represented by the API.
- Downloads half-hour rates including and excluding VAT.
- Displays rates as an interactive circular wheel.
- Touch or drag around the wheel to select a half-hour.
- Shows selected, lowest, highest and average prices.
- Shows the time of selected, lowest and highest price periods.
- Uses a day-relative colour scale:
  - blue for negative prices,
  - green for lower positive prices,
  - yellow/orange through red for progressively higher prices.
- Provides Prices, Chart and Details views.
- Persists the chosen tariff.
- Handles 46-, 48- and 50-period UK days correctly.
- Supports persistent local cache fallback and explicit server/local-data status.

### Solar irradiance forecast

- Swipe left from Agile Prices to open Solar Forecast.
- Uses the same selected UK calendar day.
- Displays one solar sector per half-hour.
- Shows global horizontal irradiance (GHI / shortwave solar radiation) in **W/m²**.
- Shows selected half-hour irradiance, peak irradiance/time, daylight average and site coordinates.
- Touch or drag around the solar wheel to inspect a period.
- Supports persistent offline cached solar forecasts.

### App Settings

The third swipe page centralises configuration and refresh actions:

- selected Agile tariff,
- selected calendar day,
- refresh Agile prices,
- solar forecast site,
- refresh solar forecast,
- PV-array details,
- current Agile and solar source/status information.

The gear button on the Solar Forecast and PV Generation screens also opens this settings page.

### PV Generation estimate

Swipe left once more from App Settings to open **PV Generation**.

The page contains another interactive half-hour wheel. Each sector represents the estimated electrical energy generated during that period, in **kWh**.

The generation page shows:

- estimated whole-day generation total in kWh,
- peak estimated output in kW and its half-hour,
- selected half-hour generation in kWh,
- selected half-hour average estimated power in kW,
- the effective array capacity used in the calculation,
- an explanation of the active model and its limitations.

Touch or drag around the wheel to select a half-hour.

---

## Solar site setup

Solar forecasts require latitude and longitude.

Within App Settings, choose **Set solar site** or **Change solar site**. The location can be set by:

1. searching by place name or postcode using Open-Meteo geocoding, or
2. entering latitude and longitude manually.

The site name and coordinates are stored locally on the device.

The current implementation does not request the iPhone's live GPS location permission.

---

## PV array settings

`AppSettingsStore` persists the following PV-array information in `UserDefaults`:

- array name,
- rated peak power in kWp,
- panel count,
- individual panel rating in watts,
- panel tilt from horizontal in degrees,
- azimuth in degrees,
- inverter maximum AC output in kW,
- estimated system losses in percent,
- free-text notes.

Azimuth convention:

```text
0°   North
90°  East
180° South
270° West
```

If panel count and panel rating are entered, the app calculates the implied panel-array peak capacity:

```text
calculated kWp = panel count × panel watts / 1000
```

For generation estimates, an explicitly entered rated peak-power value takes priority. If that field is blank, the calculated panel capacity is used when panel count and panel watts are both available.

---

## PV generation model

### Purpose

The current generation page is a first-order estimate intended to translate the weather-model solar forecast into a useful half-hour electrical-energy forecast for the configured PV system.

It is deliberately simple and transparent rather than pretending to provide a fully physical plane-of-array model.

### Half-hour calculation

For each `SolarHalfHour`, the app calculates:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power (kW) = array peak power (kWp) × irradiance factor
loss-adjusted power = raw PV power × (1 - system loss % / 100)
```

If a positive inverter maximum is configured:

```text
estimated power = min(loss-adjusted power, inverter max kW)
```

Otherwise:

```text
estimated power = loss-adjusted power
```

Finally:

```text
period hours = (validTo - validFrom) / 3600
estimated energy (kWh) = estimated power (kW) × period hours
```

Using actual `validFrom`/`validTo` duration rather than hard-coding `0.5` hours keeps the calculation robust around unusual time periods.

### System losses

The loss percentage is supplied by the user in App Settings.

A blank loss field means no additional loss correction is applied. Values are clamped to the range 0–100% before they are used.

### Inverter clipping

When a positive inverter maximum is entered, the estimate cannot exceed that AC power value.

This approximates inverter clipping at high irradiance.

### Current limitations

The weather input is currently **global horizontal irradiance (GHI)**, not plane-of-array irradiance.

Therefore the current generation calculation does **not yet apply** the stored:

- panel tilt,
- panel azimuth.

Those settings are retained because a future revision can use direct/diffuse radiation and a transposition model to calculate irradiance on the actual panel plane.

The current model also does not explicitly model:

- local shading,
- panel temperature coefficient,
- snow or soiling,
- detailed inverter efficiency curve,
- mismatch/string losses,
- degradation,
- horizon obstruction,
- reflection/albedo effects.

The output should therefore be interpreted as a useful forecast estimate, not a guaranteed generation value.

---

## Architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +------------------+------------------+--------------------+
        |                  |                  |                    |
        v                  v                  v                    v
ContentView        SolarForecastView     AppSettingsView   GenerationEstimateView
        |                  |                  |                    |
        v                  v                  v                    +--> AppSettingsStore
AgileViewModel     SolarForecastModel     AppSettingsStore          +--> SolarForecastModel
        |                  |                  |
        +--> OctopusAPI    +--> SolarForecastAPI                  local calculation
        |       |          |       |
        |       v          |       +--> Open-Meteo Forecast API
        |  Octopus REST    |       +--> Open-Meteo Geocoding API
        |                  |
        +--> AgileCache    +--> SolarForecastCache
```

Main state responsibilities:

- `AgileViewModel` owns Agile tariff/rate/date state.
- `SolarForecastModel` owns solar site, irradiance forecast, source status and cache loading.
- `AppSettingsStore` owns persistent PV-system settings.
- `GenerationEstimateView` derives half-hour electrical power/energy from `SolarForecastModel.forecast` plus `AppSettingsStore`.
- `SwipeDashboardView` coordinates the four pages and the shared selected date.

The PV generation estimate does not have its own network API or cache. It is recalculated locally whenever the underlying solar forecast or PV settings change.

---

## Source files

### `AgilePriceWheelApp.swift`

Application entry point. Creates the shared `AgileViewModel` and launches `SwipeDashboardView`.

### `SwipeDashboardView.swift`

Top-level four-page navigation. It:

- displays Agile Prices,
- displays Solar Forecast after the first left swipe,
- displays App Settings after the second left swipe,
- displays PV Generation after the third left swipe,
- supports reverse right swipes,
- owns `SolarForecastModel` and `AppSettingsStore`,
- reloads solar data when the Agile selected date changes,
- presents in-app documentation.

Horizontal page changes require a strongly horizontal drag so normal vertical scrolling is not treated as navigation.

### `ContentView.swift`

Main Agile-price dashboard including price wheel, summaries, chart/details, source status and documentation access.

### `PriceWheelView.swift`

Interactive Agile price wheel. Sector count is based on the actual settlement periods returned rather than assuming 48.

### `AgileViewModel.swift`

Owns tariff/date/rate state, offline-first loading, source status and Octopus refresh behaviour.

### `OctopusAPI.swift`

Native `URLSession` client for public Octopus product/tariff/rate endpoints.

### `AgileCacheStore.swift`

Persists tariff catalogue and downloaded tariff/date rate sets as JSON beneath Application Support.

### `Models.swift`

Octopus API and app tariff/rate data models plus UK region mapping.

### `PriceColour.swift`

Calculates the day-relative electricity-price colour scale and descriptive bands.

### `SolarForecast.swift`

Contains:

- `SiteLocation`,
- `SolarHalfHour`,
- `SiteSearchResult`,
- `SolarForecastModel`,
- `SolarForecastAPI`,
- `SolarForecastCache`,
- Open-Meteo response models and errors.

### `SolarForecastView.swift`

Solar irradiance dashboard and interactive `SolarWheelView`.

### `SolarSiteSettingsView.swift`

Place/postcode search and manual latitude/longitude editor.

### `AppSettingsStore.swift`

Persistent general settings store for PV configuration.

It provides parsed numeric helpers plus:

- `calculatedPanelPeakKWp`,
- `effectivePeakPowerKWp`,
- `generationLossFactor`,
- `effectiveInverterMaxKW`.

### `AppSettingsView.swift`

Third swipe page containing tariff/day controls, refresh actions, solar site controls and PV-array configuration.

### `GenerationEstimateView.swift`

Fourth swipe page.

Defines:

- `GenerationHalfHour`,
- `GenerationEstimateView`,
- `GenerationWheelView`,
- wheel-sector outline rendering.

It calculates generation locally from the active solar forecast and PV settings and provides day/peak/selected-period summaries.

### `DocumentationView.swift`

Comprehensive user-facing guide bundled inside the app and available offline.

### `DOCUMENTATION_POLICY.md`

Project rule requiring functional changes to keep repository and in-app documentation synchronized.

---

## Octopus Energy API

Base URL:

```text
https://api.octopus.energy/v1/
```

Agile products/tariffs are discovered dynamically rather than hard-coded.

Half-hour standard unit rates are requested for the selected UK day using UTC ISO-8601 period boundaries derived from `Europe/London` calendar logic.

The public endpoints used here require no Octopus account credentials or API key.

---

## Open-Meteo solar forecast

Forecast endpoint:

```text
https://api.open-meteo.com/v1/forecast
```

The app requests 15-minute `shortwave_radiation`, using `Europe/London` time handling, then combines consecutive 15-minute samples into half-hour `SolarHalfHour` values.

The solar screen displays **GHI in W/m²**.

The generation screen uses those half-hour GHI values as an input to the local PV estimate described above.

---

## Location discovery

Geocoding endpoint:

```text
https://geocoding-api.open-meteo.com/v1/search
```

Users can search by place/postcode or enter coordinates manually.

Manual bounds:

- latitude `-90...90`,
- longitude `-180...180`.

---

## UK daylight-saving handling

The app uses a Gregorian calendar configured to `Europe/London`.

Typical period counts are:

- normal day: 48 half-hours,
- spring clock change: 46 half-hours,
- autumn clock change: 50 half-hours.

Agile and solar pipelines use actual returned timestamps. PV energy calculation uses each period's actual duration.

---

## Offline behaviour

### Agile cache

`AgileCacheStore` stores the tariff catalogue and each successfully downloaded tariff/date rate set.

### Solar cache

`SolarForecastCache` stores successfully downloaded site/date forecasts, keyed by coordinates and date.

### Generation offline behaviour

PV generation is calculated entirely on-device. Therefore, if a solar forecast for the selected site/day is already cached and PV settings are stored, the generation wheel can be calculated while offline.

No separate generation cache is required because it is deterministic from the currently loaded solar forecast plus settings.

---

## Data-source indicators

Agile and solar pipelines expose statuses such as:

```text
SERVER DATA · updated 21:15
LOCAL CACHE · saved 12 Sep 16:42
NO DATA
```

PV Generation is not labelled as a separate server source because its values are locally derived. Its effective freshness follows the solar forecast that feeds it.

---

## Persistence

`UserDefaults` stores lightweight preferences/settings including:

- selected Agile tariff,
- selected solar site name/coordinates,
- PV-array configuration.

Application Support JSON stores:

- tariff metadata,
- Agile rate snapshots,
- solar forecast snapshots.

PV generation values are calculated on demand rather than persisted separately.

---

## Privacy

The app does not require:

- Octopus login credentials,
- Octopus API key,
- Octopus account number,
- MPAN,
- meter serial number,
- payment details.

Configured site coordinates are sent to Open-Meteo only for forecast/geocoding requests.

PV-array configuration and derived generation calculations remain local in the current implementation and are not sent to Octopus or Open-Meteo.

The app does not currently request live device GPS access.

---

## Dependencies

### Third-party packages

**None.**

### Apple frameworks

- SwiftUI
- Foundation
- Combine

Networking uses `URLSession`. JSON uses `Codable`, `JSONEncoder` and `JSONDecoder`.

---

## Setup

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

Configure **Signing & Capabilities** in Xcode with automatic signing and the correct Apple Developer team.

Run with `⌘R` on a simulator or connected iPhone.

---

## Typical user workflow

1. Launch Agile Price Wheel.
2. Review Agile Prices.
3. Swipe left to Solar Forecast.
4. Swipe left to App Settings.
5. Select the required tariff/day.
6. Set or change the solar site.
7. Enter PV-array capacity and any inverter/loss information.
8. Swipe left again to PV Generation.
9. Inspect the estimated daily total.
10. Touch/drag the generation wheel to inspect individual half-hours.
11. Swipe right to return through Settings, Solar and Prices.

---

## Refresh behaviour

App Settings centralises online refresh actions:

```text
Refresh Agile prices
Refresh solar forecast
```

PV Generation has no separate refresh action. It recalculates from whatever solar forecast is currently loaded and from the current local PV settings.

If a solar refresh succeeds, the generation estimate updates automatically because the source forecast changes.

---

## Testing checklist

Before releasing a functional update, test at least:

- project builds cleanly,
- app launches online,
- app launches offline after caches have been populated,
- swipe Prices → Solar → Settings → Generation,
- swipe Generation → Settings → Solar → Prices,
- vertical scrolling does not accidentally change pages,
- tariff discovery/selection/persistence,
- selected date remains consistent across all pages,
- Agile price-wheel interaction,
- lowest/highest time display,
- solar site search and manual coordinates,
- solar-wheel interaction,
- Agile and solar server/local-cache indicators,
- PV fields persist after app restart,
- explicit kWp overrides panel-derived kWp,
- panel count × panel watts fallback produces expected kWp,
- loss percentage changes generation appropriately,
- inverter limit clips estimated power,
- blank loss field applies no extra loss correction,
- generation day total equals sum of half-hour energy values,
- generation wheel selection displays correct kWh/time,
- cached solar data can drive generation while offline,
- 46/48/50-period DST days,
- in-app documentation matches current behaviour.

---

## Documentation maintenance policy

Documentation is part of the implementation.

Every functional change must review/update both:

```text
README.md
AgilePriceWheel/DocumentationView.swift
```

See also:

```text
DOCUMENTATION_POLICY.md
```

Changes to calculations, settings, APIs, caching, privacy, navigation, build requirements or distribution are incomplete until the documentation reflects them.

---

## Planned improvements to PV modelling

The next useful improvements would be:

- request/use direct and diffuse radiation components,
- calculate plane-of-array irradiance from site latitude, date/time, tilt and azimuth,
- use solar position for each half-hour,
- incorporate temperature effects,
- support configurable shading/horizon losses,
- improve inverter efficiency/clipping modelling,
- compare forecast generation against measured historical output,
- combine generation forecasts with Agile prices to identify optimal battery, EV, hot-water and flexible-load windows.

---

## Disclaimer

Agile Price Wheel is an independent application using publicly available Octopus Energy and Open-Meteo information. It is not an official application of either service.

Electricity prices should be verified against the user's actual Octopus tariff/account before billing or financial decisions.

Solar irradiance values are weather-model forecasts. PV generation values are derived estimates and may differ materially from actual electrical generation, especially because the current model does not yet transform GHI for array tilt/azimuth or account for all site/system effects.
