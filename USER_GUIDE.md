# Agile Price Wheel — Complete User Guide

This guide explains how to operate every part of Agile Price Wheel.

The same guide is built directly into the app as the final swipe page and can also be opened from the **ⓘ** information buttons.

---

# 1. What the app does

Agile Price Wheel brings together six swipe pages:

1. Octopus Energy Agile half-hour electricity prices.
2. Solar irradiance forecast in W/m².
3. Estimated half-hour PV generation in kWh.
4. Net/effective electricity price after forecast PV offsets a chosen load.
5. Settings for tariff, day, solar site, PV array and optimiser load.
6. The complete User Guide.

The forward page sequence is circular, so continuing to swipe left from the User Guide returns to Agile Prices.

---

# 2. Moving between pages

Swipe left through:

```text
Agile Prices
    ↓
Solar Forecast
    ↓
PV Generation
    ↓
Net Electricity Price
    ↓
App Settings
    ↓
User Guide
    ↓
Agile Prices
```

Swipe right to move back one page. A right swipe from Agile Prices does not wrap.

Six page dots show the current position.

Gear buttons on Solar Forecast, PV Generation and Net Electricity Price jump directly to App Settings.

The User Guide can also be opened from any **ⓘ** information button. In that case it appears as a sheet with a Done button.

---

# 3. Agile Prices

This is the first page when the app launches.

Each sector of the wheel represents one Agile settlement period. On a normal day there are 48 half-hours. UK clock-change days can contain 46 or 50.

Touch or drag around the wheel to choose a half-hour.

The page shows:

- selected Agile price;
- selected time;
- lowest price and time;
- highest price and time;
- average price;
- chosen half-hour.

Use the bottom controls for:

- **Prices** — wheel and summary cards;
- **Chart** — chronological half-hour bars;
- **Details** — selected-period and tariff information.

Negative prices are blue. Positive prices progress from green through yellow/orange to red relative to that day.

The data-source label shows whether the values are live server data, local cached data, or unavailable.

---

# 4. Solar Forecast

Swipe left from Agile Prices.

The solar page follows the same selected day.

Each wheel sector shows forecast **global horizontal irradiance (GHI)** in W/m². Touch or drag around the wheel to inspect a period.

The page shows selected irradiance, peak irradiance and time, daylight average, forecast site coordinates and server/cache status.

Solar data comes from Open-Meteo 15-minute `shortwave_radiation` forecasts. The app combines consecutive 15-minute values into half-hour values.

The Solar Forecast page remains available even if you configure the app as having **no PV panels installed**. It is a weather/irradiance view and does not itself require a PV system.

### Setting the solar site

Go to App Settings and choose **Set solar site** or **Change solar site**. Search by place/postcode or enter latitude/longitude manually.

The app does not currently require live iPhone GPS permission.

---

# 5. PV Generation

Swipe left from Solar Forecast.

This page estimates electrical energy from your configured PV array. Each wheel sector represents estimated kWh generated during that half-hour.

The page shows estimated day total, peak estimated power and time, selected half-hour energy, selected half-hour average power and effective array capacity used.

### If no PV panels are installed

In App Settings, turn **Solar PV panels installed** off.

When that setting is off:

- the PV Generation page is greyed;
- the page cannot be interacted with;
- a message explains that PV generation is disabled;
- your existing PV-array details are retained rather than erased.

Turn the setting back on to restore normal PV Generation operation.

---

# 6. How PV generation is estimated

For each half-hour:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = array kWp × irradiance factor
loss-adjusted power = raw PV power × (1 - loss percentage)
```

If an inverter maximum is set:

```text
estimated power = min(loss-adjusted power, inverter maximum)
```

Then:

```text
estimated energy = estimated power × actual period duration
```

The model uses actual timestamps, not a hard-coded half hour.

The current model uses horizontal GHI. Tilt and azimuth are stored but not yet applied because the app does not yet calculate plane-of-array irradiance. It also does not yet explicitly model shading, panel temperature, snow, soiling, detailed inverter efficiency, mismatch, degradation, horizon obstruction or albedo.

Treat the result as a planning forecast, not guaranteed generation.

---

# 7. Net Electricity Price

Swipe left from PV Generation.

This page uses the same optimiser idea as the nightly Agile + solar email. It answers:

> What is the effective p/kWh cost of running my configured load in each half-hour after forecast PV has reduced the amount bought from the grid?

Each wheel sector shows that net/effective price in p/kWh.

The page shows best net price and time, highest net price and time, average net price, configured load power, selected published Agile price, selected load energy, selected forecast PV generation, expected grid import, expected slot cost and net/adjusted p/kWh.

### If no PV panels are installed

When **Solar PV panels installed** is off:

- the Net Electricity Price calculation area is greyed;
- the net-price wheel is greyed;
- the wheel and related controls are disabled;
- an overlay explains that the feature requires PV to be enabled.

This prevents a solar-adjusted net price from appearing active for a property without PV.

---

# 8. Net-price calculation

For each half-hour:

```text
load energy = configured load kW × period hours
forecast PV = estimated PV generation for that period
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net price = slot cost / complete load energy
```

Example:

```text
Agile price             20 p/kWh
Configured load          3 kW
30-minute load energy    1.5 kWh
Forecast PV              0.9 kWh
Expected grid import     0.6 kWh
Expected slot cost      12 p
Net effective price      8 p/kWh
```

The optimiser load defaults to **3.0 kW**, matching the previous nightly email model, but you can change it in App Settings while PV is enabled.

The calculation assumes all forecast PV is available to the configured load. It does not yet subtract household background demand first, and it does not add export revenue when generation exceeds the load.

---

# 9. Net-price wheel colours

Unlike the Agile wheel, the net-price wheel uses fixed bands so one day can be compared with another:

```text
below 0 p/kWh   dark green
0–5             green
5–10            lime
10–20           light green
20–30           yellow
30–40           orange
40–50           red
50+             dark red
```

---

# 10. App Settings

Swipe left from Net Electricity Price.

App Settings is page 5 of 6. Swipe left again to reach the User Guide.

## Agile electricity

Choose the Agile tariff/region, selected day and **Refresh Agile prices**.

## Solar site

Set or change the site by search or coordinates. Use **Refresh solar forecast** to request a fresh forecast.

## Solar PV availability

The setting:

```text
Solar PV panels installed
```

controls whether PV-derived features are active.

It is on by default for an installation that has never stored this setting before, preserving existing app behaviour.

When switched off:

- PV-array fields are greyed and disabled;
- Net price optimiser fields are greyed and disabled;
- PV Generation is greyed and disabled;
- Net Electricity Price is greyed and disabled;
- Solar Forecast remains available;
- saved PV and optimiser values are retained.

When switched back on, the saved PV configuration becomes available again immediately.

## PV array

Available fields include array name, rated peak power in kWp, number of panels, panel watts, tilt, azimuth, inverter maximum AC power, estimated system losses and notes.

Azimuth convention:

```text
0° North
90° East
180° South
270° West
```

## Net price optimiser

Set **Controllable load power (kW)**. The default is 3.0 kW. This section is disabled when Solar PV panels installed is off.

### Navigation from Settings

- swipe right to return to Net Electricity Price;
- swipe left to open the User Guide.

---

# 11. User Guide page

The User Guide is page 6 of 6 and is the final page in the normal left-swipe sequence.

It contains the same complete operating information as this file and is bundled with the app, so it is available without a network connection.

Navigation from the User Guide:

- swipe right to return to App Settings;
- swipe left to wrap directly back to Agile Prices.

The guide can still be opened as a sheet from **ⓘ** buttons elsewhere in the app. That sheet version includes a Done button; the swipe-page version does not.

---

# 12. Refresh and automatic recalculation

Online refresh buttons exist only for source data:

- Refresh Agile prices;
- Refresh solar forecast.

PV Generation and Net Electricity Price recalculate from their underlying data and settings when PV is enabled. When PV is disabled, those pages remain greyed and non-interactive.

---

# 13. Offline use

Previously downloaded Agile and solar data are cached locally.

PV Generation and Net Electricity Price are local calculations and can work from cached source data when PV is enabled.

The PV-installed switch is stored locally, so its enabled/disabled state persists without a network connection.

The User Guide is part of the app itself and is always available offline.

---

# 14. UK daylight-saving days

The app uses `Europe/London` time.

Typical day lengths:

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

The app works from actual timestamps and durations.

---

# 15. Privacy

The app does not require Octopus login, Octopus API key, MPAN, meter serial number, payment details or live GPS permission.

Stored locally:

- selected tariff;
- site name/coordinates;
- whether PV panels are installed;
- PV-array settings;
- optimiser load;
- cached Agile prices;
- cached solar forecasts.

Coordinates are sent to Open-Meteo when required for geocoding/forecast requests. PV settings, the PV-installed switch, optimiser load and derived calculations remain local.

---

# 16. Troubleshooting

## No Agile prices

Check tariff, date, publication status and network/cache availability. Try **Refresh Agile prices**.

## No solar forecast

Check the solar site and date. Try **Refresh solar forecast**.

## PV Generation is greyed out

Open App Settings and check **Solar PV panels installed**. If the property has PV, turn it on. If the property does not have PV, the greyed state is intentional.

## Net Electricity Price wheel is greyed out

Open App Settings and check **Solar PV panels installed**. The net-price optimiser depends on forecast self-generation, so it is intentionally disabled when PV is configured as not installed.

## PV is enabled but no generation appears

Check that solar data exists and rated kWp or panel count + panel watts are configured.

## PV is enabled but no net-price wheel appears

Check Agile prices, solar forecast, PV capacity and optimiser load.

## Swipe navigation does not move pages

Use a clearly horizontal swipe. The app deliberately requires horizontal movement to dominate vertical movement so ordinary scrolling does not accidentally change pages.

---

# 17. How the app works internally

```text
AgilePriceWheelApp
        ↓
SwipeDashboardView
        ├─ Agile Prices
        │    └─ AgileViewModel → OctopusAPI / AgileCacheStore
        ├─ Solar Forecast
        │    └─ SolarForecastModel → SolarForecastAPI / SolarForecastCache
        ├─ PV Generation
        │    └─ SolarForecastModel + AppSettingsStore
        ├─ Net Electricity Price
        │    └─ AgileViewModel + SolarForecastModel + AppSettingsStore
        ├─ App Settings
        │    └─ AppSettingsStore
        └─ User Guide
             └─ DocumentationView
```

`AppSettingsStore.hasPVPanelsInstalled` is the feature-state switch. `SwipeDashboardView` observes it and dims/disables the PV Generation and Net Electricity Price content when false. `AppSettingsView` uses the same value to disable PV-array and optimiser controls.

Agile and solar are source-data pipelines. Generation and net price are local derived calculations. The guide is local static app content.

---

# 18. Documentation

The project keeps these synchronized:

- `README.md` — technical/developer reference;
- `USER_GUIDE.md` — complete operating guide;
- `AgilePriceWheel/DocumentationView.swift` — in-app offline guide and sixth swipe page.

Future functional changes must update the relevant documentation in the same change.

---

# 19. Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo app.

Electricity prices should be checked against the user's actual tariff. Solar, generation and net-price values are forecasts/derived planning estimates and can differ from actual energy flows and bills.
