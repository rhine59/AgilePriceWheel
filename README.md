# Agile Price Wheel

Agile Price Wheel is a native SwiftUI iPhone/iPad application for viewing Octopus Energy Agile electricity prices, solar irradiance forecasts, a local PV output forecast and a solar-adjusted net electricity price.

The first dashboard page is presented to the user as **Octopus Agile Prices**. The Xcode project and GitHub repository remain named `AgilePriceWheel`.

The app uses Apple frameworks only (`SwiftUI`, `Foundation`, `Combine`, `CoreLocation`) and has no third-party package dependencies.

For user operation see `USER_GUIDE.md`. The same core guidance is built into the app in `AgilePriceWheel/DocumentationView.swift`.

---

## Main page navigation

The app has six pages:

```text
1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. App Settings
6. User Guide
```

Page changes are made only with the fixed **Back** and **Next** controls at the bottom of the screen. Horizontal swipe navigation has been deliberately removed because wheel-sector touching and dragging could otherwise be misinterpreted as a page swipe.

The first page has Back disabled. Next advances through the sequence. On the User Guide page the right-hand button is labelled **Prices** and returns to Octopus Agile Prices.

The bottom navigation bar also shows six page dots plus the current page number (`1 of 6`, etc.).

The first four pages are metric pages and show a **Now** button. Tapping Now returns the shared selected date to today and highlights the half-hour containing the current time.

---

## 1. Octopus Agile Prices

This page displays the selected Octopus Energy Agile import tariff as an interactive half-hour wheel.

Features include:

- dynamic discovery of currently available Agile import tariffs;
- regional tariff selection;
- 46/48/50 settlement-period support for UK daylight-saving days;
- touch/drag half-hour selection;
- selected, lowest, highest and average prices;
- Prices, Chart and Details views;
- live-server/local-cache status;
- persistent tariff selection;
- a **Now** button to select the current half-hour.

Negative Agile prices are blue. Positive prices use a day-relative green-to-red scale.

---

## 2. Solar Forecast

Solar Forecast displays global horizontal irradiance (GHI / shortwave radiation) in W/m² for the selected day.

The app requests Open-Meteo 15-minute `shortwave_radiation` data and combines consecutive samples into half-hour values.

The page shows:

- interactive solar wheel;
- selected half-hour irradiance;
- peak irradiance and time;
- daylight average;
- forecast-site coordinates;
- server/cache status;
- **Now** selection.

Solar Forecast remains available even when the property is configured as having no PV panels installed.

### Solar-site selection

The solar site can be set in three ways:

1. **Use Current Location** — requests iOS When-In-Use location permission only when the button is tapped;
2. search by place or postcode using Open-Meteo geocoding;
3. enter latitude and longitude manually.

Current-location use is optional. If permission is denied, search and manual coordinates remain available.

The app stores the chosen site coordinates locally. The coordinates are sent to Open-Meteo when requesting forecast data.

---

## 3. PV Forecast

The page previously called **PV Generation** is now called **PV Forecast**.

It converts the loaded solar irradiance forecast into a first-order estimate of PV electrical output for the configured array. Each wheel sector represents estimated kWh during that half-hour.

The page shows:

- estimated daily energy total;
- peak estimated output and time;
- selected half-hour energy;
- selected half-hour average power;
- effective array capacity used;
- **Now** selection.

When **Solar PV panels installed** is off, PV Forecast is greyed and disabled, but stored PV configuration is retained.

### PV forecast model

For each half-hour:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power (kW) = effective array kWp × irradiance factor
loss-adjusted power = raw power × (1 - system loss % / 100)
```

If an inverter maximum is configured:

```text
estimated power = min(loss-adjusted power, inverter maximum)
```

Then:

```text
estimated energy (kWh) = estimated power × actual period duration in hours
```

Rated kWp takes priority. If it is blank, array capacity can be derived from:

```text
panel count × panel watts / 1000
```

Tilt and azimuth are currently stored but are not yet applied because the present weather input is horizontal GHI rather than plane-of-array irradiance. The model also does not explicitly model shading, temperature, snow/soiling, detailed inverter efficiency, mismatch, degradation, horizon obstruction or albedo.

---

## 4. Net Electricity Price

This page combines:

- Octopus Agile price for each half-hour;
- forecast PV output for the same half-hour;
- a configured controllable load.

For each period:

```text
load energy = load kW × period hours
forecast PV = forecast PV energy for the same period
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net effective price = slot cost / complete load energy
```

The default optimiser load is **3.0 kW**, matching the established nightly email optimiser.

Example:

```text
Agile price             20 p/kWh
3 kW load for 30 min     1.5 kWh
Forecast PV              0.9 kWh
Expected grid import     0.6 kWh
Slot cost               12 p
Net effective price      8 p/kWh
```

The model assumes all forecast PV is available to the controllable load. It does not yet subtract normal household background demand first and does not credit surplus-export revenue.

The Net Electricity Price wheel uses fixed colour bands:

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

The page also has a **Now** button.

---

## 5. App Settings

App Settings contains:

- Agile tariff and region;
- selected day;
- Agile refresh;
- solar site and solar refresh;
- current-location solar-site option;
- Solar PV panels installed switch;
- Solar PV array configuration;
- net-price optimiser load;
- source-data status.

### Solar PV availability

`AppSettingsStore.hasPVPanelsInstalled` is persisted in `UserDefaults` under:

```text
solarArray.isInstalled
```

If the key has never been stored, the setting defaults to `true` for backward compatibility.

When PV is switched off:

- Solar PV array fields are greyed and disabled;
- optimiser controls are greyed and disabled;
- PV Forecast is greyed and disabled;
- Net Electricity Price is greyed and disabled;
- Solar Forecast remains available;
- saved PV and optimiser values are retained.

### Solar PV array units

PV-array numeric fields keep their engineering units visibly displayed beside the editable value, rather than relying on placeholder text that disappears after entry.

The persistent unit presentation is:

| Setting | Unit shown |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt from horizontal | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

`Number of panels` is dimensionless.

Azimuth convention:

```text
0°   North
90°  East
180° South
270° West
```

The underlying stored values remain numeric strings in `AppSettingsStore`; the unit labels are presentation only and are not stored as part of the number.

---

## Now button and current-time selection

The four metric pages show a **Now** button:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price

Tapping Now:

- changes the shared selected date to today;
- loads today's Agile prices if required;
- loads today's solar forecast if required;
- selects the period satisfying `validFrom <= now < validTo`;
- refreshes the derived PV Forecast and Net Electricity Price selections.

If no matching current period exists, the first available period is used as a fallback.

See `docs/NOW_BUTTON_AND_CURRENT_TIME.md` for the dedicated implementation/testing note.

---

## Architecture

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +--> ContentView / PriceWheelView
        |       +--> AgileViewModel
        |               +--> OctopusAPI
        |               +--> AgileCacheStore
        |
        +--> SolarForecastView / SolarWheelView
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
        |       +--> AppSettingsStore
        |
        +--> SolarSiteSettingsView
        |       +--> CoreLocation
        |
        +--> DocumentationView
```

`SwipeDashboardView` retains its historical type name but no longer installs a horizontal page-swipe gesture. It owns the fixed bottom navigation bar and changes the `DashboardPage` only from explicit buttons (or direct jumps such as the settings gear).

The user-facing page is named **PV Forecast**, while the existing implementation type remains `GenerationEstimateView` to avoid an unnecessary source-file/type rename.

---

## APIs

### Octopus Energy

Base URL:

```text
https://api.octopus.energy/v1/
```

The app uses public product/tariff/rate endpoints and does not require Octopus account credentials or an API key for those requests.

### Open-Meteo forecast

```text
https://api.open-meteo.com/v1/forecast
```

Used for 15-minute shortwave-radiation data.

### Open-Meteo geocoding

```text
https://geocoding-api.open-meteo.com/v1/search
```

Used for place/postcode search.

---

## UK time and DST

The app uses `Europe/London` calendar logic.

Typical day lengths:

```text
normal day          48 half-hours
spring DST day      46 half-hours
autumn DST day      50 half-hours
```

Actual period timestamps and durations are used throughout.

---

## Offline behaviour

`AgileCacheStore` persists tariff metadata and downloaded tariff/date rate sets.

`SolarForecastCache` persists downloaded site/date solar forecasts.

PV Forecast and Net Electricity Price are derived locally and can be recalculated from cached source data when the required settings and source datasets are available.

The in-app User Guide is compiled into the app and remains available offline.

---

## Persistence and privacy

Stored locally:

- selected Agile tariff;
- selected solar site name and coordinates;
- PV-installed state;
- PV-array values;
- optimiser load;
- cached Agile rates;
- cached solar forecasts.

The app does not require Octopus login details, MPAN, meter serial number or payment details.

Location permission is requested only if the user taps **Use Current Location** in Solar Site. The permission is When-In-Use only. Location is used to set the forecast coordinates; the app does not continuously track location.

---

## Build and setup

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

Configure Signing & Capabilities in Xcode, select the correct Apple Developer team and run on a simulator or physical device.

The project uses a filesystem-synchronised Xcode group, so Swift files placed under `AgilePriceWheel/` are normally included automatically.

---

## Testing checklist

Before release verify:

- clean Xcode build;
- page order: Octopus Agile Prices → Solar Forecast → PV Forecast → Net Electricity Price → App Settings → User Guide;
- Back is disabled on Octopus Agile Prices;
- Next advances through the page sequence;
- User Guide right-hand button is Prices and returns to Octopus Agile Prices;
- horizontal swipes on the page background do not change pages;
- dragging around each wheel cannot change pages;
- six page dots and the page-number indicator update correctly;
- Now button appears on all four metric pages and nowhere else;
- Now returns a non-today selection to today and selects the current half-hour;
- tariff discovery and selection;
- 46/48/50-period days;
- wheel touch/drag selection;
- solar site by place/postcode;
- solar site by manual coordinates;
- solar site by Use Current Location with permission allowed;
- denied location permission leaves search/manual entry usable;
- PV-installed setting defaults correctly and persists;
- PV Forecast and Net Electricity Price grey correctly when PV is off;
- Solar Forecast stays usable when PV is off;
- PV values survive an off/on toggle;
- PV-array unit suffixes remain visible before, during and after editing;
- `kWp`, `W`, `°`, `kW` and `%` are attached to the correct fields;
- PV Forecast calculation and inverter clipping;
- Net Electricity Price calculation, including negative Agile prices and zero grid import when forecast PV exceeds load;
- offline cache behaviour;
- in-app documentation matches `README.md` and `USER_GUIDE.md`.

---

## Documentation policy

Documentation is part of the implementation. Functional changes must review and update, as appropriate:

- `README.md`;
- `USER_GUIDE.md`;
- `AgilePriceWheel/DocumentationView.swift`;
- `DOCUMENTATION_POLICY.md`;
- any focused documents under `docs/`.

See `DOCUMENTATION_POLICY.md` for the required maintenance rules.

---

## Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.

Electricity prices should be checked against the user's actual tariff. Solar irradiance, PV Forecast and net-price values are forecasts/derived planning estimates and may differ from actual generation, energy flows and bills.
