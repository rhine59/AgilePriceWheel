# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile half-hour electricity prices and a same-day solar irradiance forecast.

The main electricity screen presents Agile prices as an interactive circular wheel. Swiping left opens a solar forecast screen for the same selected calendar day, with one half-hour sector per forecast period and values shown as global horizontal irradiance in watts per square metre (W/m²). Swiping right returns to electricity prices.

The application is deliberately lightweight: it uses Swift, SwiftUI, Foundation and Combine only, with no third-party package dependencies.

---

## Main features

### Electricity prices

- Dynamically discovers currently available Octopus Energy Agile import tariffs.
- Supports all UK Octopus electricity regions represented by the API.
- Downloads half-hour unit rates including and excluding VAT.
- Displays prices as an interactive circular wheel.
- Touch or drag around the wheel to select a half-hour.
- Shows the selected half-hour price and time.
- Shows lowest, highest and average prices for the selected day.
- Shows the time of the lowest and highest price periods.
- Uses a day-relative colour scale:
  - blue for negative prices,
  - green for lower positive prices,
  - yellow/orange through red for progressively higher prices.
- Provides Prices, Chart and Details views.
- Persists the chosen tariff.
- Handles 46-, 48- and 50-period UK days correctly.

### Solar irradiance forecast

- Swipe left from the electricity-price screen to open the solar screen.
- Uses the same selected calendar day as the Agile price screen.
- Displays one half-hour solar sector for each forecast period.
- Shows global horizontal irradiance (GHI / shortwave solar radiation) in **W/m²**.
- Shows:
  - selected half-hour irradiance,
  - peak irradiance and time,
  - daylight average,
  - forecast-site latitude and longitude.
- Touch or drag around the solar wheel to inspect an individual half-hour.
- Swipe right to return to electricity prices.
- Supports offline cached solar forecasts.

### Solar site setup

Solar forecasts require a site latitude and longitude. On the Solar Forecast screen, open the gear button to access **Solar Site** settings.

The site can be set in two ways:

1. Search by **place name or postcode** using the Open-Meteo geocoding API, then select the best match.
2. Enter **latitude and longitude manually**.

The selected site name and coordinates are stored locally on the device.

The current implementation does **not** request the iPhone's GPS location permission. Site discovery is performed through place/postcode search or manual coordinate entry.

---

## Architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +-----------------------------+
        |                             |
        v                             v
ContentView                    SolarForecastView
        |                             |
        v                             v
AgileViewModel                 SolarForecastModel
        |                             |
        +--> OctopusAPI               +--> SolarForecastAPI
        |       |                     |       |
        |       v                     |       +--> Open-Meteo Forecast API
        |  Octopus REST API           |       +--> Open-Meteo Geocoding API
        |                             |
        +--> AgileCacheStore          +--> SolarForecastCache
                |                             |
                v                             v
       Application Support JSON      Application Support JSON
```

The two data pipelines are intentionally separate:

- `AgileViewModel` owns electricity-price state.
- `SolarForecastModel` owns solar-site and irradiance state.
- `SwipeDashboardView` keeps the two screens tied to the same selected calendar day.

---

## Source files

### `AgilePriceWheelApp.swift`

Application entry point. Creates the shared `AgileViewModel` and starts `SwipeDashboardView`.

### `SwipeDashboardView.swift`

Top-level navigation between electricity prices and solar forecast.

It:

- displays `ContentView` for electricity prices,
- displays the solar screen after a left swipe,
- returns to prices after a right swipe,
- reloads solar data when the Agile selected date changes,
- presents Solar Site settings,
- presents the in-app documentation from the solar screen.

Horizontal swipe detection intentionally requires a strong horizontal gesture so ordinary vertical scrolling is not treated as page navigation.

### `ContentView.swift`

Main electricity-price dashboard.

Responsibilities include:

- tariff/date settings,
- price wheel,
- price chart,
- tariff/details display,
- selected/lowest/highest/average summaries,
- server/local-cache status,
- Octopus refresh,
- access to the in-app documentation.

### `PriceWheelView.swift`

Renders the interactive Agile price wheel using SwiftUI drawing primitives.

The sector count is based on the actual number of returned settlement periods rather than a fixed 48.

### `AgileViewModel.swift`

Central state manager for Agile tariff and rate data.

It publishes:

- available tariffs,
- selected tariff,
- selected date,
- rates,
- selected rate,
- loading state,
- errors/sync messages,
- data origin (server or local cache).

Startup is offline-first: cached data is restored immediately when available, followed by an attempted server refresh.

### `OctopusAPI.swift`

Native `URLSession` client for the public Octopus Energy REST API.

It dynamically discovers Agile products and tariffs and retrieves half-hour standard unit rates.

No Octopus account credentials or API key are required for the public endpoints used by this application.

### `AgileCacheStore.swift`

Persists:

- the latest tariff catalogue,
- each previously downloaded tariff/date rate set.

Files are JSON snapshots stored beneath the application's Application Support directory.

### `Models.swift`

Octopus API models and app tariff/rate models, including UK region-name mapping.

### `PriceColour.swift`

Calculates the day-relative electricity-price colour scale and descriptive bands.

### `SolarForecast.swift`

Contains the solar data layer:

- `SiteLocation`
- `SolarHalfHour`
- `SiteSearchResult`
- `SolarForecastModel`
- `SolarForecastAPI`
- `SolarForecastCache`
- Open-Meteo response models and error handling.

### `SolarForecastView.swift`

Contains the solar dashboard and interactive `SolarWheelView`.

The solar wheel uses one sector per half-hour and allows touch/drag selection in the same style as the electricity wheel.

### `SolarSiteSettingsView.swift`

Solar-site configuration interface.

Supports:

- place/postcode search,
- selecting an Open-Meteo geocoding result,
- manual latitude/longitude entry,
- clearing the site,
- explicit solar refresh.

### `DocumentationView.swift`

Comprehensive user-facing guide stored inside the app, so it remains available offline.

### `DOCUMENTATION_POLICY.md`

Defines the project rule that functional changes must update both the repository documentation and the in-app documentation.

---

## Octopus Energy API

Base URL:

```text
https://api.octopus.energy/v1/
```

The app discovers products and tariffs dynamically instead of embedding a single historical Agile product code.

For a selected tariff, rates are retrieved from an endpoint of the form:

```text
/v1/products/{product-code}/electricity-tariffs/{tariff-code}/standard-unit-rates/
```

Requests use UTC ISO-8601 period bounds derived from the selected UK local calendar day.

The API client follows pagination and sorts the returned periods chronologically.

---

## Solar forecast API

Solar data is obtained from the Open-Meteo Forecast API:

```text
https://api.open-meteo.com/v1/forecast
```

The app requests:

```text
minutely_15=shortwave_radiation
timezone=Europe/London
timeformat=unixtime
start_date=YYYY-MM-DD
end_date=YYYY-MM-DD
```

Open-Meteo defines shortwave solar radiation as global horizontal irradiance at the surface, expressed in **W/m²**.

The API provides 15-minute radiation values. Agile Price Wheel combines consecutive 15-minute values into half-hour values so that the solar display aligns naturally with Agile half-hour settlement periods.

The result is a weather-model irradiance forecast, not predicted PV electrical output. It does not account for a particular array's:

- panel area,
- panel efficiency,
- roof pitch,
- azimuth,
- inverter limits,
- shading,
- clipping,
- system losses.

Those factors could be added in a future PV-output model.

---

## Location discovery

Location search uses:

```text
https://geocoding-api.open-meteo.com/v1/search
```

A user can enter a town, village or postcode. Returned search results include latitude and longitude, and choosing one stores those coordinates as the solar site.

Manual coordinate entry is also available and validates:

- latitude: `-90...90`
- longitude: `-180...180`

No device GPS permission is required by the current implementation.

---

## UK daylight-saving handling

The application uses a Gregorian calendar configured to:

```text
Europe/London
```

The end of a selected day is calculated as the next local calendar day, not by blindly adding 24 hours.

Therefore:

- normal day: 48 half-hours,
- spring clock change: 46 half-hours,
- autumn clock change: 50 half-hours.

Both price and solar displays use the actual data count returned for the selected day.

---

## Offline behaviour and caching

The application is designed to remain useful without a network connection.

### Electricity cache

`AgileCacheStore` stores:

- the latest tariff catalogue,
- every successfully downloaded tariff/date set of rates viewed by the user.

### Solar cache

`SolarForecastCache` stores every successfully downloaded site/date solar forecast.

Solar cache filenames are keyed using the site coordinates and date, so forecasts from different sites do not overwrite one another.

### Source indicators

Both data types explicitly indicate their source.

Typical electricity labels:

```text
SERVER DATA · updated 21:15
LOCAL CACHE · saved 12 Sep 16:42
NO DATA
```

Typical solar labels:

```text
SERVER DATA · updated 21:15
LOCAL CACHE · saved 12 Sep 16:42
NO SOLAR DATA
```

If a server refresh fails but a cached copy exists, the cached copy remains displayed.

Offline mode cannot create data that has never previously been downloaded.

---

## Persistence

`UserDefaults` stores lightweight preferences such as:

- selected Agile tariff code,
- selected solar-site name and coordinates.

Application Support stores JSON cache files for:

- tariff metadata,
- Agile rates,
- solar forecasts.

Cache write failures are non-fatal; live server data must remain usable even if persistence fails.

---

## Dependencies

### Third-party packages

**None.**

The project currently has no Swift Package Manager, CocoaPods or Carthage dependencies.

### Apple frameworks

- SwiftUI
- Foundation
- Combine

Networking uses `URLSession`.

JSON encoding/decoding uses `Codable`, `JSONEncoder` and `JSONDecoder`.

---

## Privacy

The application does not require:

- Octopus login credentials,
- Octopus API key,
- Octopus account number,
- MPAN,
- meter serial number,
- payment information.

For solar forecasts, the configured latitude and longitude are sent to Open-Meteo when requesting forecast data.

The current implementation does not request access to the phone's live GPS location.

---

## Setup

### Requirements

The repository currently targets the modern Xcode/iOS toolchain used to create the project. Check the checked-in Xcode project settings for the exact deployment target before building for an older device.

Current project metadata includes:

```text
MARKETING_VERSION = 1.0
CURRENT_PROJECT_VERSION = 1
PRODUCT_BUNDLE_IDENTIFIER = KRH.AgilePriceWheel
```

### Clone

```bash
git clone https://github.com/rhine59/AgilePriceWheel.git
cd AgilePriceWheel
open AgilePriceWheel.xcodeproj
```

### Signing

In Xcode:

1. Select the AgilePriceWheel project.
2. Select the AgilePriceWheel target.
3. Open **Signing & Capabilities**.
4. Leave **Automatically manage signing** enabled.
5. Select the appropriate Apple Developer team.
6. Change the bundle identifier if your developer account requires a unique identifier.

No Octopus or Open-Meteo API secret is required by the current public endpoints.

### Run

Select an iPhone simulator or connected iPhone and press:

```text
⌘R
```

An internet connection is required for new tariff, price, site-search and solar-forecast data. Previously cached data can be displayed offline.

---

## User workflow

A typical first-time workflow is:

1. Launch Agile Price Wheel.
2. Select the required Agile tariff/region if the default is not correct.
3. Select the required date.
4. Review the electricity-price wheel.
5. Swipe left to Solar Forecast.
6. Tap the solar gear button.
7. Search for the installation place/postcode or enter latitude/longitude manually.
8. Select/save the site.
9. Return to the solar screen.
10. Inspect the W/m² value for each half-hour by touching or dragging around the solar wheel.
11. Swipe right to return to electricity prices.

---

## Refresh behaviour

Electricity data:

```text
Settings → Refresh from Octopus
```

Solar data:

```text
Solar Forecast → gear → Refresh solar forecast
```

Refresh always attempts the server. Existing cached data is retained if the new request fails.

---

## Testing checklist

Before releasing a functional update, test at least:

- project builds cleanly,
- app launches with network available,
- app launches without network after data has been cached,
- tariff discovery,
- tariff persistence,
- price wheel selection,
- lowest/highest time display,
- chart/details views,
- left swipe from price screen,
- right swipe from solar screen,
- solar place/postcode search,
- manual coordinate validation,
- changing solar site,
- solar wheel selection,
- solar server/local-cache indicator,
- electricity server/local-cache indicator,
- solar and electricity remain on the same selected date,
- normal 48-period day,
- spring 46-period DST day,
- autumn 50-period DST day,
- in-app documentation opens from both screens.

---

## Distribution

To create a distribution archive:

1. Select the appropriate generic iOS device destination.
2. Choose **Product → Archive**.
3. Open the resulting archive in Organizer.
4. Choose **Distribute App**.

Available distribution methods depend on the active Apple Developer membership and signing configuration.

---

## Documentation maintenance policy

Documentation is part of the feature implementation, not a later optional task.

Every functional change must review and, where applicable, update both:

```text
README.md
AgilePriceWheel/DocumentationView.swift
```

The detailed rule is also recorded in:

```text
DOCUMENTATION_POLICY.md
```

Changes affecting controls, calculations, APIs, caching, networking, site settings, privacy, setup, dependencies, build behaviour or distribution are incomplete until the relevant documentation has been updated.

---

## Possible future enhancements

- Convert irradiance into predicted PV electrical output using array size, efficiency, tilt and azimuth.
- Add global tilted irradiance for a configured roof orientation.
- Overlay Agile price and solar irradiance to identify attractive load/charging windows.
- Add configurable alerts for low prices, negative prices or high solar periods.
- Add cache management controls.
- Add widgets and Apple Watch support.
- Add export to CSV/JSON.
- Expand automated unit/UI tests.

---

## Disclaimer

Agile Price Wheel is an independent application using publicly available Octopus Energy and Open-Meteo data. It is not an official application of either service.

Electricity prices should be verified against the user's actual Octopus tariff/account before being relied upon for billing or financial decisions.

Solar values are weather-model forecasts and may differ materially from measured irradiance or actual PV generation.
