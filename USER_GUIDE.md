# Agile Price Wheel — Complete User Guide

This guide explains how to operate Agile Price Wheel and what each screen means.

The same user-facing information is also available inside the app from the **ⓘ** information button.

---

## 1. What the app does

Agile Price Wheel brings together four related views for the same selected UK day:

1. Octopus Energy Agile half-hour electricity prices.
2. Solar irradiance forecast in W/m².
3. Estimated half-hour PV electrical generation in kWh.
4. Settings for tariff, date, solar site and PV array.

The app is designed so that the three information pages come first and **App Settings is always the final swipe page**.

---

## 2. Moving between pages

The page order is:

```text
Agile Prices
    ↓ swipe left
Solar Forecast
    ↓ swipe left
PV Generation
    ↓ swipe left
App Settings
```

Swipe right to go back:

```text
App Settings
    ↓ swipe right
PV Generation
    ↓ swipe right
Solar Forecast
    ↓ swipe right
Agile Prices
```

The four small page dots indicate which page is active.

The gear buttons on Solar Forecast and PV Generation jump directly to App Settings.

---

## 3. Agile Prices page

This is the first page shown when the app starts.

### Price wheel

Each coloured sector represents one published Agile settlement period.

On a normal UK day there are 48 half-hour periods. On daylight-saving clock-change days there can be 46 or 50.

Touch or drag around the wheel to select a half-hour.

The centre of the wheel shows:

- selected price;
- p/kWh;
- selected time range.

### Summary tiles

The page shows:

- **Lowest price** — cheapest half-hour and time;
- **Highest price** — most expensive half-hour and time;
- **Average price** — average of all returned periods;
- **Chosen slot** — currently selected half-hour.

### Price colours

- negative prices: blue;
- cheaper positive periods: green;
- middle periods: yellow/orange;
- more expensive periods: red.

Colours are relative to the current day. Green does not represent a fixed p/kWh threshold.

### Prices / Chart / Details

Use the three controls at the bottom of the electricity page:

- **Prices** — wheel and summary tiles;
- **Chart** — half-hour price bars;
- **Details** — selected-period and tariff information.

### Data source label

The page reports where the displayed data came from:

```text
SERVER DATA
LOCAL CACHE
NO DATA
```

If the network is unavailable but the day has already been downloaded, the app can show the saved local copy.

---

## 4. Solar Forecast page

Swipe left once from Agile Prices.

The Solar Forecast page uses the **same selected day** as the Agile price page.

### Solar wheel

Each sector represents forecast global horizontal irradiance (GHI) for a half-hour, displayed in:

```text
W/m²
```

Touch or drag around the wheel to inspect a half-hour.

The page shows:

- selected half-hour irradiance;
- peak irradiance and time;
- daylight average;
- forecast-site coordinates.

### Where the solar data comes from

The app uses Open-Meteo 15-minute `shortwave_radiation` data.

Consecutive 15-minute values are combined into half-hour periods.

The result is a weather-model solar-radiation forecast, not measured irradiance and not PV electrical output.

### Setting the solar site

A site is required before a solar forecast can be fetched.

Go to App Settings and choose **Set solar site** or **Change solar site**.

You can:

- search by place name;
- search by postcode;
- enter latitude manually;
- enter longitude manually.

Manual limits are:

```text
Latitude:  -90 to 90
Longitude: -180 to 180
```

The current app does not require live iPhone GPS permission.

---

## 5. PV Generation page

Swipe left from Solar Forecast.

This page estimates how much electrical energy the configured PV array may generate in each half-hour.

### Generation wheel

Each sector represents:

```text
estimated kWh generated during that period
```

Touch or drag around the wheel to inspect a half-hour.

### Summary information

The page shows:

- estimated total generation for the selected day;
- peak estimated output in kW and its time;
- selected half-hour energy in kWh;
- selected half-hour average power in kW;
- effective PV-array capacity used.

### What is required before generation can be calculated

The app needs:

1. a configured solar site;
2. a solar forecast for the selected day;
3. an effective PV-array capacity.

Effective array capacity comes from either:

- rated peak power in kWp; or
- panel count × panel wattage.

If rated kWp is entered, it takes priority.

---

## 6. How the generation estimate is calculated

For each solar half-hour:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = effective kWp × irradiance factor
loss-adjusted power = raw PV power × (1 - loss percentage)
```

If an inverter maximum is configured:

```text
estimated power = min(loss-adjusted power, inverter maximum)
```

Then:

```text
estimated energy = estimated power × actual period duration
```

The app uses the real `validFrom` and `validTo` timestamps rather than assuming every period is exactly 30 minutes.

### Important limitations

The current model uses **horizontal GHI**.

It does not yet transform irradiance onto the panel plane, so stored panel tilt and azimuth are not yet used in the estimate.

It also does not yet explicitly model:

- shading;
- panel temperature;
- snow;
- soiling;
- detailed inverter efficiency;
- panel mismatch;
- degradation;
- horizon obstruction;
- albedo/reflection effects.

Use the PV Generation page as a planning estimate rather than a guaranteed production forecast.

---

## 7. App Settings page

Swipe left from PV Generation.

This is the **final swipe page**.

It contains all of the main configuration controls.

### Agile tariff

Choose the Octopus Agile import tariff and region to display.

The app discovers currently available Agile tariffs dynamically and remembers the selected tariff.

### Selected day

The selected day applies to:

- Agile Prices;
- Solar Forecast;
- PV Generation.

Changing the day causes the price and solar pipelines to load that day, and generation recalculates from the resulting solar data.

### Refresh controls

Use:

- **Refresh Agile prices**;
- **Refresh solar forecast**.

A successful refresh replaces cached data with the latest downloaded data.

If refresh fails and a saved copy exists, the saved copy remains available.

### Solar site

Set or change the forecast location using search or manual coordinates.

### PV array details

Available fields include:

- array name;
- rated peak power in kWp;
- number of panels;
- watts per panel;
- panel tilt;
- panel azimuth;
- inverter maximum AC output;
- estimated system losses;
- notes.

Azimuth convention:

```text
0°   North
90°  East
180° South
270° West
```

If panel count and watts per panel are provided, the app calculates the implied kWp value.

---

## 8. Offline operation

The app can continue to show previously downloaded information without a network connection.

### Agile data

Downloaded tariff/day rate sets are stored locally.

### Solar data

Downloaded site/day solar forecasts are stored locally.

Solar cache entries are tied to both coordinates and date.

### PV generation

PV Generation is calculated locally.

If the selected site's solar forecast is cached and the PV settings are stored, generation can be recalculated offline.

### What offline mode cannot do

Without a network connection the app cannot obtain:

- a new tariff catalogue;
- a new unpublished price day;
- a new place/postcode search result;
- a new solar forecast for an uncached site/day.

---

## 9. UK daylight-saving days

The app uses `Europe/London` calendar logic.

Typical day sizes are:

```text
Normal day          48 periods
Spring clock change 46 periods
Autumn clock change 50 periods
```

The wheels use the actual returned period count.

---

## 10. Privacy and stored information

The app does not currently require:

- Octopus account login;
- Octopus API key;
- MPAN;
- meter serial number;
- payment information;
- live iPhone GPS permission.

Stored locally:

- selected tariff;
- solar-site name and coordinates;
- PV-array settings;
- cached Agile prices;
- cached solar forecasts.

Configured coordinates are sent to Open-Meteo only when required to obtain solar forecast/geocoding data.

PV-array details and generation calculations remain local in the current implementation.

---

## 11. Troubleshooting

### No Agile prices

Check:

- tariff is selected;
- correct date is selected;
- Octopus has published prices for that day;
- network connection is available if no cache exists.

Try **Refresh Agile prices**.

### Solar Forecast has no data

Check:

- solar site is configured;
- coordinates are valid;
- selected day is within the available forecast range;
- network is available if no cached forecast exists.

Try **Refresh solar forecast**.

### PV Generation has no data

Check:

- solar forecast exists;
- rated kWp is entered, or panel count and panel wattage are both entered.

### PV Generation looks wrong

Check:

- rated kWp;
- panel count/wattage;
- inverter maximum;
- system loss percentage.

Remember that tilt, azimuth, shading and temperature are not yet applied.

---

## 12. How the app works internally

The main components are:

```text
AgilePriceWheelApp
        |
        v
SwipeDashboardView
        |
        +--> ContentView / AgileViewModel / OctopusAPI / AgileCacheStore
        |
        +--> SolarForecastView / SolarForecastModel / SolarForecastAPI / SolarForecastCache
        |
        +--> GenerationEstimateView / AppSettingsStore
        |
        +--> AppSettingsView
```

### Agile pipeline

```text
Octopus public API
    ↓
OctopusAPI
    ↓
AgileViewModel
    ↓
ContentView / PriceWheelView
```

`AgileCacheStore` provides offline persistence.

### Solar pipeline

```text
Open-Meteo
    ↓
SolarForecastAPI
    ↓
SolarForecastModel
    ↓
SolarForecastView
```

`SolarForecastCache` provides offline persistence.

### Generation pipeline

```text
SolarForecastModel.forecast
        +
AppSettingsStore PV settings
        ↓
GenerationEstimateView
        ↓
GenerationWheelView
```

No generation data is downloaded. The estimate is calculated on the device.

---

## 13. Documentation

The project maintains three main documentation surfaces:

- `README.md` — technical/developer reference;
- `USER_GUIDE.md` — complete operating guide;
- `AgilePriceWheel/DocumentationView.swift` — in-app offline guide.

Future functional changes must keep these documents synchronized with the implementation.

---

## 14. Disclaimer

Agile Price Wheel is an independent application and is not an official Octopus Energy or Open-Meteo application.

Electricity prices should be checked against the user's actual Octopus tariff before billing or financial decisions.

Solar irradiance is forecast weather data. PV generation is a derived estimate and may differ materially from actual production.
