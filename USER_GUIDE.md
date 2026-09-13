# Agile Price Wheel — Complete User Guide

This guide explains how to operate every part of Agile Price Wheel.

The same user-facing help is also available inside the app from the **ⓘ** information button.

---

# 1. What the app does

Agile Price Wheel brings together five views for the same selected UK day:

1. Octopus Energy Agile half-hour electricity prices.
2. Solar irradiance forecast in W/m².
3. Estimated half-hour PV generation in kWh.
4. Net/effective electricity price after forecast PV offsets a chosen load.
5. Settings for tariff, day, solar site, PV array and optimiser load.

Settings is deliberately the final swipe page.

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
```

Swipe right to move back in reverse.

Five page dots show the current position.

Gear buttons on Solar Forecast, PV Generation and Net Electricity Price jump directly to App Settings.

---

# 3. Agile Prices

This is the first page when the app launches.

Each sector of the wheel represents one Agile settlement period.

On a normal day there are 48 half-hours. UK clock-change days can contain 46 or 50.

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

### Colours

- negative prices: blue;
- cheaper positive periods: green;
- progressively higher positive periods: yellow/orange/red.

The positive colour scale is relative to that day.

### Data source

The page reports:

```text
SERVER DATA
LOCAL CACHE
NO DATA
```

Cached data can be used when the network is unavailable.

---

# 4. Solar Forecast

Swipe left from Agile Prices.

The solar page follows the same selected day.

Each wheel sector shows forecast **global horizontal irradiance (GHI)** in:

```text
W/m²
```

Touch or drag around the wheel to inspect a period.

The page shows:

- selected half-hour irradiance;
- peak irradiance and time;
- daylight average;
- forecast site coordinates;
- server/cache status.

Solar data comes from Open-Meteo 15-minute `shortwave_radiation` forecasts. The app combines consecutive 15-minute values into half-hour values.

### Setting the solar site

Go to App Settings and choose **Set solar site** or **Change solar site**.

You can search by place/postcode or enter latitude/longitude manually.

The app does not currently need live iPhone GPS permission.

---

# 5. PV Generation

Swipe left from Solar Forecast.

This page estimates electrical energy from your configured PV array.

Each wheel sector represents:

```text
estimated kWh generated during that half-hour
```

The page shows:

- estimated day total;
- peak estimated power and time;
- selected half-hour energy;
- selected half-hour average power;
- effective array capacity used.

Touch or drag around the wheel to inspect a period.

### Required setup

Generation needs:

1. a solar site;
2. a solar forecast for the selected day;
3. an effective PV-array capacity.

Capacity comes from either rated kWp or panel count × panel watts. Rated kWp takes priority when entered.

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

### Important limitations

The current model uses horizontal GHI. Tilt and azimuth are stored but not yet applied because the app does not yet calculate plane-of-array irradiance.

It also does not yet model shading, panel temperature, snow, soiling, detailed inverter efficiency, mismatch, degradation, horizon obstruction or albedo.

Treat the result as a planning forecast, not guaranteed generation.

---

# 7. Net Electricity Price

Swipe left from PV Generation.

This page uses the same optimiser idea as the nightly Agile + solar email.

It answers:

> What is the effective p/kWh cost of running my configured load in each half-hour after forecast PV has reduced the amount bought from the grid?

Each sector of the wheel shows that net/effective price in **p/kWh**.

The page shows:

- best net price and time;
- highest net price and time;
- average net price;
- configured load power;
- selected published Agile price;
- selected load energy;
- selected forecast PV generation;
- expected grid import;
- expected slot cost;
- net/adjusted p/kWh.

Touch or drag around the wheel to inspect a half-hour.

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

The optimiser load defaults to **3.0 kW**, matching the previous nightly email model, but you can change it in App Settings.

### What the net price means

The net price is not the published tariff. It is an effective cost for the complete configured load after allowing for forecast self-generation.

A period with a higher published Agile rate can therefore be cheaper overall if enough solar is expected.

### Important assumptions

The calculation assumes all forecast PV is available to the configured load.

It does not yet subtract household background demand first, and it does not add export revenue when generation exceeds the load.

If forecast PV is greater than the configured load, expected grid import is floored at zero.

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

These bands reproduce the established nightly email optimiser colouring.

---

# 10. App Settings

Swipe left from Net Electricity Price.

This is the **last swipe page**.

It contains all application configuration.

## Agile electricity

Choose:

- Agile tariff/region;
- selected day;
- **Refresh Agile prices**.

Changing the day updates all day-based pages.

## Solar site

Set or change the site by search or coordinates.

Use **Refresh solar forecast** to request a fresh forecast.

## PV array

Available fields:

- array name;
- rated peak power in kWp;
- number of panels;
- panel watts;
- tilt;
- azimuth;
- inverter maximum AC power;
- estimated system losses;
- notes.

Azimuth:

```text
0° North
90° East
180° South
270° West
```

## Net price optimiser

Set **Controllable load power (kW)**.

The default is 3.0 kW. The settings page also shows the equivalent energy for a normal 30-minute slot.

Change this value to model a different appliance or flexible load.

---

# 11. Refresh and automatic recalculation

Online refresh buttons exist only for source data:

- Refresh Agile prices;
- Refresh solar forecast.

PV Generation recalculates automatically from solar data and PV settings.

Net Electricity Price recalculates automatically when any of these change:

- Agile rates;
- solar forecast;
- PV-array settings;
- system losses;
- inverter maximum;
- optimiser load.

---

# 12. Offline use

The app stores previously downloaded Agile and solar data.

### Agile cache

Previously downloaded tariff/day prices can be displayed offline.

### Solar cache

Previously downloaded site/day forecasts can be displayed offline.

### PV Generation offline

Generation is calculated locally, so it can be recalculated from cached solar data and saved PV settings.

### Net Price offline

Net price is also calculated locally. If both Agile prices and solar data for the selected day are cached, the net-price wheel can be recalculated offline.

Offline mode cannot obtain new data that was never downloaded.

---

# 13. UK daylight-saving days

The app uses `Europe/London` time.

Typical day lengths:

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

The app works from actual timestamps and durations.

---

# 14. Privacy

The app does not require:

- Octopus login;
- Octopus API key;
- MPAN;
- meter serial number;
- payment details;
- live GPS permission.

Stored locally:

- selected tariff;
- site name/coordinates;
- PV-array settings;
- optimiser load;
- cached Agile prices;
- cached solar forecasts.

Coordinates are sent to Open-Meteo when required for geocoding/forecast requests. PV settings, optimiser load and derived calculations remain local.

---

# 15. Troubleshooting

## No Agile prices

Check tariff, date, publication status and network/cache availability. Try **Refresh Agile prices**.

## No solar forecast

Check the solar site and date. Try **Refresh solar forecast**.

## No PV generation

Check that solar data exists and rated kWp or panel count + panel watts are configured.

## No net-price wheel

Check:

- Agile prices exist for the selected day;
- solar forecast exists for the same day;
- PV-array capacity is configured;
- optimiser load is greater than zero.

## Net price seems too low/high

Check:

- optimiser load kW;
- PV kWp;
- system losses;
- inverter maximum;
- selected Agile tariff/day.

Remember that the model currently assumes all forecast PV is available to the evaluated load and ignores background household consumption/export income.

---

# 16. How the app works internally

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
        └─ App Settings
             └─ AppSettingsStore
```

Agile and solar are source-data pipelines. Generation and net price are local derived calculations.

---

# 17. Documentation

The project keeps these synchronized:

- `README.md` — technical/developer reference;
- `USER_GUIDE.md` — complete operating guide;
- `AgilePriceWheel/DocumentationView.swift` — in-app offline guide.

Future functional changes must update the relevant documentation in the same change.

---

# 18. Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo app.

Electricity prices should be checked against the user's actual tariff. Solar, generation and net-price values are forecasts/derived planning estimates and can differ from actual energy flows and bills.
