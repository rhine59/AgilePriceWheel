# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile half-hour electricity prices, same-day solar irradiance forecasts and site/PV configuration.

The main interface now has three horizontally swiped pages:

1. **Agile Prices** — interactive electricity-price wheel.
2. **Solar Forecast** — same-day half-hour solar irradiance in W/m².
3. **App Settings** — all core application settings, including tariff, day, solar site and stored PV-array details.

Swipe left to move from Prices → Solar → Settings. Swipe right to move back.

The application uses Swift, SwiftUI, Foundation and Combine only, with no third-party package dependencies.

---

## Main features

### Electricity prices

- Dynamically discovers currently available Octopus Energy Agile import tariffs.
- Supports all UK Octopus electricity regions represented by the API.
- Downloads half-hour unit rates including and excluding VAT.
- Displays prices as an interactive circular wheel.
- Touch or drag around the wheel to select a half-hour.
- Shows selected, lowest, highest and average prices.
- Shows the time of the selected, lowest and highest price periods.
- Uses a day-relative colour scale:
  - blue for negative prices,
  - green for lower positive prices,
  - yellow/orange through red for progressively higher prices.
- Provides Prices, Chart and Details views.
- Persists the chosen tariff.
- Handles 46-, 48- and 50-period UK days correctly.
- Uses server/local-cache status indicators and offline cache fallback.

### Solar irradiance forecast

- Swipe left from Agile Prices to open Solar Forecast.
- Uses the same selected calendar day as the Agile price screen.
- Displays one half-hour solar sector for each forecast period.
- Shows global horizontal irradiance (GHI / shortwave solar radiation) in **W/m²**.
- Shows selected half-hour irradiance, peak irradiance/time, daylight average and forecast-site coordinates.
- Touch or drag around the solar wheel to inspect an individual half-hour.
- Supports persistent offline cached solar forecasts.
- Swipe right for prices or swipe left again for App Settings.

### Comprehensive App Settings page

The third swipe page centralises the application configuration rather than exposing solar location as a separate settings destination.

It currently contains:

- selected Agile tariff,
- selected calendar day,
- Agile-price refresh,
- solar forecast site,
- solar forecast refresh,
- stored PV-array information,
- Agile and solar source/status information.

The gear button on the Solar Forecast screen opens this same App Settings page.

### Solar site setup

Within App Settings, choose **Set solar site** or **Change solar site**.

The site can be configured by:

1. searching by place name or postcode using Open-Meteo geocoding, or
2. entering latitude and longitude manually.

The selected site name and coordinates are stored locally. The current implementation does not request iPhone GPS permission.

### Solar PV array settings

The app now stores PV-array information for later use in generation forecasting/optimisation.

Available fields are:

- array name,
- rated peak power in kWp,
- number of panels,
- panel rating in watts each,
- panel tilt from horizontal in degrees,
- azimuth in degrees,
- inverter maximum AC output in kW,
- estimated system losses in percent,
- free-text notes.

Azimuth convention:

```text
0°   = North
90°  = East
180° = South
270° = West
```

If panel count and panel rating are entered, the settings screen also displays the implied panel-array peak capacity in kWp.

These fields are **stored only at present**. They do not yet modify the W/m² solar irradiance forecast. A later PV model can use them to estimate electrical generation.

---

## Architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +------------------+------------------+
        |                  |                  |
        v                  v                  v
ContentView        SolarForecastView     AppSettingsView
        |                  |                  |
        v                  v                  +--> AppSettingsStore
AgileViewModel     SolarForecastModel          |
        |                  |                   +--> UserDefaults
        +--> OctopusAPI    +--> SolarForecastAPI
        |       |          |       |
        |       v          |       +--> Open-Meteo Forecast API
        |  Octopus REST    |       +--> Open-Meteo Geocoding API
        |                  |
        +--> AgileCache    +--> SolarForecastCache
```

The main state areas are intentionally separated:

- `AgileViewModel` owns electricity tariff/rate state.
- `SolarForecastModel` owns solar-site/irradiance state.
- `AppSettingsStore` owns persistent PV-array settings.
- `SwipeDashboardView` keeps all three pages coordinated and keeps price/solar data on the same selected day.

---

## Source files

### `AgilePriceWheelApp.swift`

Application entry point. Creates the shared `AgileViewModel` and starts `SwipeDashboardView`.

### `SwipeDashboardView.swift`

Top-level three-page navigation.

It:

- displays `ContentView` for Agile Prices,
- displays `SolarForecastView` after the first left swipe,
- displays `AppSettingsView` after the second left swipe,
- supports reverse right swipes,
- owns `SolarForecastModel` and `AppSettingsStore`,
- reloads solar data when the selected Agile date changes,
- presents the in-app documentation.

Horizontal swipe detection requires a strongly horizontal gesture so normal vertical scrolling is not treated as page navigation.

### `ContentView.swift`

Main electricity-price dashboard, including price wheel, summaries, chart/details, source status and documentation access.

### `PriceWheelView.swift`

Interactive Agile price wheel. The sector count follows the actual number of settlement periods rather than assuming 48.

### `AgileViewModel.swift`

Owns tariff/date/rate state, source status, offline-first loading and Octopus refresh behaviour.

### `OctopusAPI.swift`

Native `URLSession` client for public Octopus Energy product/tariff/rate endpoints.

### `AgileCacheStore.swift`

Persists tariff catalogue and downloaded tariff/date rate sets as JSON in Application Support.

### `Models.swift`

Octopus API and application tariff/rate data models plus UK region names.

### `PriceColour.swift`

Calculates the day-relative electricity-price colour scale and descriptive bands.

### `SolarForecast.swift`

Solar data layer containing:

- `SiteLocation`,
- `SolarHalfHour`,
- `SiteSearchResult`,
- `SolarForecastModel`,
- `SolarForecastAPI`,
- `SolarForecastCache`,
- Open-Meteo response models/error handling.

### `SolarForecastView.swift`

Solar dashboard and interactive `SolarWheelView`.

### `SolarSiteSettingsView.swift`

Site search/manual coordinate editor launched from App Settings.

### `AppSettingsStore.swift`

Persistent general settings store for PV-array configuration.

Values are stored in `UserDefaults`. Parsed numeric helper properties are also provided so a later PV-output model can use the configuration directly.

### `AppSettingsView.swift`

Third swipe page containing the central settings UI for:

- Agile tariff,
- selected day,
- Agile refresh,
- solar site,
- solar refresh,
- PV-array details,
- stored-data/source status.

### `DocumentationView.swift`

User-facing guide stored in the app so it remains available offline.

### `DOCUMENTATION_POLICY.md`

Defines the rule that functional changes must update both repository and in-app documentation.

---

## Octopus Energy API

Base URL:

```text
https://api.octopus.energy/v1/
```

Agile products/tariffs are discovered dynamically. Half-hour standard unit rates are requested for the selected UK calendar day using UTC ISO-8601 bounds.

The public endpoints used here do not require an Octopus account number or API key.

---

## Solar forecast API

Solar data is obtained from Open-Meteo:

```text
https://api.open-meteo.com/v1/forecast
```

The app requests 15-minute `shortwave_radiation` with `Europe/London` timezone handling and combines consecutive 15-minute values into half-hour values.

The displayed value is global horizontal irradiance in **W/m²**. It is not yet predicted PV electrical output.

Current irradiance does not yet account for the configured array's:

- kWp,
- panel count/rating,
- tilt,
- azimuth,
- inverter limit,
- losses,
- shading/clipping.

Those settings are now captured specifically so a later PV-generation model can use them.

---

## Location discovery

Location search uses:

```text
https://geocoding-api.open-meteo.com/v1/search
```

A user can enter a place or postcode and select a result, or enter coordinates manually.

Manual validation accepts:

- latitude: `-90...90`
- longitude: `-180...180`

No live device GPS permission is required in the current implementation.

---

## UK daylight-saving handling

The application uses `Europe/London` calendar logic.

Therefore:

- normal day: 48 half-hours,
- spring clock change: 46 half-hours,
- autumn clock change: 50 half-hours.

Both electricity and solar displays use the actual returned period count.

---

## Offline behaviour and caching

### Electricity cache

`AgileCacheStore` stores the latest tariff catalogue and each successfully downloaded tariff/date rate set.

### Solar cache

`SolarForecastCache` stores each successfully downloaded site/date solar forecast. Cache keys include site coordinates and date.

### Source indicators

Both pipelines expose their source, for example:

```text
SERVER DATA · updated 21:15
LOCAL CACHE · saved 12 Sep 16:42
NO DATA
```

Existing cached data remains displayed when a refresh fails.

---

## Persistence

`UserDefaults` stores lightweight preferences/settings including:

- selected Agile tariff,
- selected solar-site name and coordinates,
- PV-array configuration.

Application Support stores JSON cache files for tariff metadata, Agile rates and solar forecasts.

PV-array settings are intentionally persistent even though they are not yet used in the irradiance calculation.

---

## Privacy

The app does not require Octopus credentials, API key, account number, MPAN, meter serial number or payment details.

Configured solar-site coordinates are sent to Open-Meteo for forecast requests.

PV-array information is currently stored locally on the device and is not sent to Octopus or Open-Meteo.

The current implementation does not request access to the phone's live GPS location.

---

## Dependencies

### Third-party packages

**None.**

### Apple frameworks

- SwiftUI
- Foundation
- Combine

Networking uses `URLSession`; JSON uses `Codable`, `JSONEncoder` and `JSONDecoder`.

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

In Xcode, configure **Signing & Capabilities** with automatic signing and the appropriate Apple Developer team.

Run with `⌘R` on a simulator or connected iPhone.

An internet connection is needed for new tariff, rate, geocoding and solar-forecast data; cached data remains available offline.

---

## User workflow

Typical setup/use:

1. Launch Agile Price Wheel.
2. Review the Agile Prices page.
3. Swipe left to Solar Forecast.
4. Swipe left again to App Settings.
5. Select the required Agile tariff and date.
6. Configure/change the solar forecast site.
7. Enter PV-array details for later modelling if desired.
8. Swipe right to Solar Forecast.
9. Inspect half-hour W/m² values.
10. Swipe right again to return to Agile Prices.

---

## Refresh behaviour

The third App Settings page centralises refresh controls:

```text
Refresh Agile prices
Refresh solar forecast
```

Each refresh attempts the online service and retains cached data if the request fails.

---

## Testing checklist

Before releasing a functional update, test at least:

- project builds cleanly,
- app launches online and offline after caching,
- swipe Prices → Solar → Settings,
- swipe Settings → Solar → Prices,
- vertical scrolling does not accidentally change pages,
- tariff discovery/selection/persistence,
- selected date synchronises prices and solar,
- price-wheel interaction,
- lowest/highest time display,
- solar site search/manual coordinates,
- solar-wheel interaction,
- server/local-cache indicators,
- PV-array fields persist after app restart,
- panel count × panel rating displays the expected implied kWp,
- clearing PV details works,
- 46/48/50-period DST days,
- in-app documentation reflects the current controls.

---

## Documentation maintenance policy

Documentation is part of every functional change.

Every feature change must review/update both:

```text
README.md
AgilePriceWheel/DocumentationView.swift
```

See also `DOCUMENTATION_POLICY.md`.

---

## Planned future use of PV settings

The stored PV configuration is intended to support later features such as:

- convert irradiance into estimated PV electrical power,
- account for tilt and azimuth,
- apply inverter clipping and system losses,
- estimate half-hour PV energy in kWh,
- combine PV generation with Agile prices,
- identify optimal charging/heating/load windows,
- compare forecast generation with measured generation.

Until that model is implemented, the Solar Forecast page should continue to be interpreted strictly as **irradiance in W/m²**.

---

## Disclaimer

Agile Price Wheel is an independent application using publicly available Octopus Energy and Open-Meteo data. It is not an official application of either service.

Electricity prices should be verified against the user's actual Octopus tariff/account before billing or financial decisions.

Solar values are weather-model forecasts and may differ materially from measured irradiance or actual PV generation.
