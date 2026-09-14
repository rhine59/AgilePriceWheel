# Agile Price Wheel — Complete User Guide

This guide explains the current Agile Price Wheel app. The first dashboard page is titled **Octopus Agile Prices**.

## Index

1. [Main navigation](#1-main-navigation)
2. [Now button](#2-now-button)
3. [Octopus Agile Prices](#3-octopus-agile-prices)
4. [Solar Forecast](#4-solar-forecast)
5. [Setting the solar site](#5-setting-the-solar-site)
6. [PV Forecast](#6-pv-forecast)
7. [Net Electricity Price](#7-net-electricity-price)
8. [Cost Savings](#8-cost-savings)
9. [App Settings](#9-app-settings)
10. [Solar PV array settings and units](#10-solar-pv-array-settings-and-units)
11. [Refresh, caching and offline use](#11-refresh-caching-and-offline-use)
12. [Privacy](#12-privacy)
13. [UK clock changes](#13-uk-clock-changes)
14. [Troubleshooting](#14-troubleshooting)
15. [Internal structure](#15-internal-structure)
16. [Disclaimer](#16-disclaimer)

The repository documentation index is in [`docs/INDEX.md`](docs/INDEX.md).

---

# 1. Main navigation

The app defines seven pages:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings
6. App Settings
7. User Guide

When **Solar PV panels installed** is on, all seven bottom buttons are shown:

| Button | Opens |
|---|---|
| ⚡ Prices | Octopus Agile Prices |
| ☀️ Solar | Solar Forecast |
| ☀️⚡ PV | PV Forecast |
| £ Net | Net Electricity Price |
| banknote Save | Cost Savings |
| sliders Settings | App Settings |
| book Guide | User Guide |

When **Solar PV panels installed** is off, the PV-dependent **PV**, **Net** and **Save** buttons are hidden. The bottom bar then shows only **Prices**, **Solar**, **Settings** and **Guide**. Turning PV back on restores the three hidden pages immediately. Saved PV-array and optimiser values are retained while PV is off.

The selected page button is highlighted in orange. Horizontal swipe navigation is disabled so wheel dragging cannot accidentally change pages.

---

# 2. Now button

The **Now** button appears on the metric pages that are currently available:

- Octopus Agile Prices;
- Solar Forecast;
- PV Forecast when PV is enabled;
- Net Electricity Price when PV is enabled;
- Cost Savings when PV is enabled.

Tapping Now returns the selected date to today, loads today's source data if required and selects the half-hour satisfying:

```text
validFrom <= now < validTo
```

Now is part of the adaptive page layout rather than a floating overlay, so SwiftUI reserves space for it instead of allowing it to cover descriptions, wheels or metric cards.

---

# 3. Octopus Agile Prices

Each wheel sector represents one Agile settlement period. A normal day has 48 half-hours; UK clock-change days can have 46 or 50.

Touch or drag around the wheel to select a period. The page shows selected, lowest, highest and average prices, selected tariff details and server/cache status.

Negative prices are blue. Positive prices progress from green through yellow/orange to red relative to that day.

---

# 4. Solar Forecast

This page shows forecast global horizontal irradiance (GHI / shortwave solar radiation) in W/m².

It includes an interactive half-hour solar wheel, selected irradiance, peak irradiance/time, daylight average, forecast-site coordinates and source/cache status.

Solar Forecast remains available even when **Solar PV panels installed** is off.

---

# 5. Setting the solar site

In App Settings choose **Set solar site** or **Change solar site**.

You can use:

1. **Use Current Location** — asks iOS for When-In-Use permission only when tapped;
2. place/postcode search;
3. manual latitude/longitude.

When **Use Current Location** succeeds, the app reverse-geocodes the coordinates using Apple's geocoding service and tries to use a familiar locality or town name for the solar-site label. If no suitable common name is returned, the label falls back to **Current location**.

The saved site name is editable in the **Current solar site** section. Editing the name changes only the label shown in the app; it does not change the saved latitude or longitude or move the forecast site.

The app does not continuously track location. Search and manual coordinates remain available if permission is denied.

---

# 6. PV Forecast

Each wheel sector represents forecast PV electrical energy for that half-hour in kWh.

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = array kWp × irradiance factor
loss-adjusted power = raw PV power × (1 - loss percentage)
estimated power = min(loss-adjusted power, inverter maximum)  [if configured]
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority. If blank, capacity can be derived from panel count × panel watts / 1000.

If **Solar PV panels installed** is off, the PV Forecast page and its bottom navigation button are hidden. Turning PV back on restores the page using the retained PV settings.

---

# 7. Net Electricity Price

This page estimates the effective p/kWh cost of running the configured load after forecast PV reduces expected grid import.

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net price = slot cost / complete load energy
```

The selected sector also displays **PV saving** in pence inside the wheel. The Selected half-hour breakdown repeats this value and shows the PV energy used against the load.

The saving is calculated as:

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The optimiser load defaults to **3.0 kW**. Export income is not included.

If **Solar PV panels installed** is off, Net Electricity Price and its bottom navigation button are hidden. They return when PV is enabled again.

---

# 8. Cost Savings

Cost Savings is a separate half-hour wheel showing the forecast monetary value of PV generation that offsets the configured load.

Each sector represents one half-hour and displays the saving in pence.

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The page also shows:

- forecast day saving;
- best-saving half-hour;
- total avoided grid import;
- selected half-hour saving;
- selected Agile price;
- forecast PV generation;
- PV used against the load.

Only PV that offsets the configured load is counted as an import-cost saving. Surplus PV export revenue is not included.

A negative Agile price can produce a **negative saving**. This means importing during that half-hour would have been financially beneficial, so PV generation reduces that benefit. Negative saving sectors are red; positive saving sectors are green.

When **Solar PV panels installed** is off, Cost Savings and its bottom navigation button are hidden. They return when PV is enabled again.

---

# 9. App Settings

Settings contains Agile tariff/region, selected day, refresh controls, solar site, PV availability, PV-array details and optimiser load.

The **Current solar site** section includes an editable site-name field plus the saved latitude and longitude.

When **Solar PV panels installed** is switched off:

- PV Forecast, Net Electricity Price and Cost Savings disappear from bottom navigation;
- the bottom bar changes from seven buttons to four;
- PV-array fields are greyed and disabled;
- optimiser controls are greyed and disabled;
- Solar Forecast remains active;
- saved PV and optimiser values are retained.

Turning **Solar PV panels installed** back on restores PV, Net and Save immediately and reuses the saved settings.

---

# 10. Solar PV array settings and units

Engineering units stay visible beside editable values:

| Field | Unit |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt from horizontal | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

Number of panels has no unit. Enter numeric values only; unit labels are display-only.

Azimuth convention:

```text
0° North
90° East
180° South
270° West
```

---

# 11. Refresh, caching and offline use

App Settings provides **Refresh Agile prices** and **Refresh solar forecast**.

Agile and solar downloads are cached locally. PV Forecast, Net Electricity Price and Cost Savings are calculated locally from source data and settings.

The in-app User Guide is bundled with the app and remains available offline.

---

# 12. Privacy

The public Octopus tariff/rate functions do not require Octopus account login details, API key, MPAN, meter serial number or payment details.

Location permission is requested only when **Use Current Location** is tapped. The returned coordinates are stored locally, used with Apple's reverse-geocoding service to obtain a readable site name, and sent to Open-Meteo when needed for solar forecast requests.

PV settings, optimiser load and derived calculations remain local.

---

# 13. UK clock changes

The app uses `Europe/London` time and actual timestamps/durations:

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

---

# 14. Troubleshooting

If no Agile prices appear, check tariff/date/network and try **Refresh Agile prices**.

If no solar forecast appears, check the solar site/date and try **Refresh solar forecast**.

If **Use Current Location** shows **Current location** instead of a place name, reverse geocoding did not return a suitable locality. The coordinates are still valid and the name can be edited manually.

If editing the solar-site name changes the coordinates, treat that as a defect: renaming is intended to change only the display label.

If PV Forecast, Net Electricity Price and Cost Savings are missing from the bottom bar, check **Solar PV panels installed**. If it is off, that is expected. Turn it on to restore those pages.

If the PV pages do not return after turning **Solar PV panels installed** on, treat that as a defect.

If Cost Savings shows a negative value, check the Agile price for that sector. Negative Agile prices can legitimately produce negative savings.

If the Cost Savings value differs from the Net Electricity Price selected-sector saving, treat that as a defect: both use the same avoided-import formula.

If Now selects an unexpected period, confirm today's source data has loaded.

If the Now button covers data or controls on a supported iPhone size, treat that as a layout defect.

If dragging a wheel changes pages, that is a defect: main page changes should occur only by tapping a visible bottom button.

---

# 15. Internal structure

```text
AgilePriceWheelApp
        ↓
SwipeDashboardView
        ├─ Octopus Agile Prices
        ├─ Solar Forecast
        ├─ PV Forecast
        ├─ Net Electricity Price
        ├─ Cost Savings
        ├─ App Settings
        └─ User Guide
```

`SwipeDashboardView` retains its historical name, but swipe-based page changing has been removed. It owns conditional bottom navigation and the shared Now control.

`GenerationEstimateView` implements PV Forecast. `CostSavingsView` implements Cost Savings.

---

# 16. Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.

Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecasts/derived planning estimates and can differ from actual generation, energy flows and bills.
