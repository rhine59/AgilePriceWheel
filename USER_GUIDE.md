# Agile Price Wheel — Complete User Guide

This guide explains the current Agile Price Wheel app. The first dashboard page is titled **Octopus Agile Prices**.

## Index

1. [Main navigation](#1-main-navigation)
2. [Screen sizes and adaptive layout](#2-screen-sizes-and-adaptive-layout)
3. [Now button](#3-now-button)
4. [Octopus Agile Prices](#4-octopus-agile-prices)
5. [Solar Forecast](#5-solar-forecast)
6. [Setting the solar site](#6-setting-the-solar-site)
7. [PV Forecast](#7-pv-forecast)
8. [Net Electricity Price](#8-net-electricity-price)
9. [Cost Savings](#9-cost-savings)
10. [App Settings](#10-app-settings)
11. [Solar PV array settings and units](#11-solar-pv-array-settings-and-units)
12. [Refresh, caching and offline use](#12-refresh-caching-and-offline-use)
13. [Privacy](#13-privacy)
14. [UK clock changes](#14-uk-clock-changes)
15. [Troubleshooting](#15-troubleshooting)
16. [Internal structure](#16-internal-structure)
17. [Disclaimer](#17-disclaimer)

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

When **Solar PV panels installed** is on, all seven bottom buttons are available:

| Button | Opens |
|---|---|
| ⚡ Prices | Octopus Agile Prices |
| ☀️ Solar | Solar Forecast |
| ⚡ PV | PV Forecast |
| £ Net | Net Electricity Price |
| banknote Save | Cost Savings |
| sliders Settings | App Settings |
| book Guide | User Guide |

The PV button uses a simple filled lightning bolt.

When **Solar PV panels installed** is off, **PV**, **Net** and **Save** disappear. The bottom bar then shows **Prices**, **Solar**, **Settings** and **Guide**. Turning PV back on restores the three hidden pages and retains the saved PV-array and optimiser settings.

Horizontal swipe navigation is disabled so wheel dragging cannot change page accidentally.

---

# 2. Screen sizes and adaptive layout

The dashboard adapts automatically to the available width.

On normal widths, the bottom navigation shows icons and labels. On narrower widths it uses a more compact icon-and-label form. If the width becomes too restricted, it can fall back to icons only while preserving accessibility labels.

The metric-page and Settings headers can also change layout. On wider screens, controls and title share one row. On narrower screens, the controls move to a top row and the title/date appear below, preventing collisions.

Main metric content is centred and width-limited on larger screens instead of stretching across the full display. Compact-width devices use smaller side margins.

The **Now** button occupies its own layout space rather than floating over content.

A 44-point minimum navigation tap height is retained. Very large Dynamic Type should still be checked because wheel-centre text and dense metric cards have limited physical space.

---

# 3. Now button

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

---

# 4. Octopus Agile Prices

Each wheel sector represents one Agile settlement period. A normal day has 48 half-hours; UK clock-change days can have 46 or 50.

Touch or drag around the wheel to select a period. The page shows selected, lowest, highest and average prices, selected tariff details and server/cache status.

Negative prices are blue. Positive prices progress from green through yellow/orange to red relative to that day.

---

# 5. Solar Forecast

This page shows forecast global horizontal irradiance (GHI / shortwave solar radiation) in W/m².

It includes an interactive half-hour solar wheel, selected irradiance, peak irradiance/time, daylight average, forecast-site coordinates and source/cache status.

Solar Forecast remains available even when **Solar PV panels installed** is off.

---

# 6. Setting the solar site

In App Settings choose **Set solar site** or **Change solar site**.

You can use:

1. **Use Current Location** — asks iOS for When-In-Use permission only when tapped;
2. place/postcode search;
3. manual latitude/longitude.

When **Use Current Location** succeeds, the app reverse-geocodes the coordinates using Apple geocoding APIs and tries to use a familiar locality or town name. On iOS 26 and later this uses MapKit; older supported systems use the compatibility geocoder. If no suitable common name is returned, the label falls back to **Current location**.

The saved site name is editable. Renaming it does not change the saved latitude or longitude.

The app does not continuously track location. Search and manual coordinates remain available if permission is denied or Location Services are unavailable.

---

# 7. PV Forecast

Each wheel sector represents forecast PV electrical energy for that half-hour in kWh.

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = array kWp × irradiance factor
loss-adjusted power = raw PV power × (1 - loss percentage)
estimated power = min(loss-adjusted power, inverter maximum)  [if configured]
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority. If blank, capacity can be derived from panel count × panel watts / 1000.

If **Solar PV panels installed** is off, PV Forecast and its bottom-navigation button are hidden. Turning PV back on restores the page using the retained PV settings.

---

# 8. Net Electricity Price

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
grid import = max(load energy - forecast PV, 0)
slot cost = grid import × Agile price
net price = slot cost / complete load energy
```

The selected sector also displays **PV saving** in pence.

```text
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The optimiser load defaults to **3.0 kW**. Export income is not included.

This page is hidden when PV is off and returns when PV is enabled again.

---

# 9. Cost Savings

Cost Savings is a half-hour wheel showing the forecast monetary value of PV generation that offsets the configured load.

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

The page also shows forecast day saving, best-saving half-hour, total avoided grid import, selected Agile price, forecast PV and PV used against the load.

Only PV that offsets the configured load is counted. Export income is not included. Negative Agile prices can legitimately produce a negative saving.

This page is hidden when PV is off and returns when PV is enabled again.

---

# 10. App Settings

Settings contains Agile tariff/region, selected day, refresh controls, solar site, PV availability, PV-array details and optimiser load.

When **Solar PV panels installed** is switched off:

- PV Forecast, Net Electricity Price and Cost Savings disappear from navigation;
- the bottom bar changes from seven page buttons to four;
- PV-array fields are disabled;
- optimiser controls are disabled;
- Solar Forecast remains active;
- saved PV and optimiser values are retained.

Turning PV back on restores PV, Net and Save immediately.

---

# 11. Solar PV array settings and units

| Field | Unit |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt from horizontal | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

Number of panels has no unit.

Azimuth convention:

```text
0° North
90° East
180° South
270° West
```

---

# 12. Refresh, caching and offline use

App Settings provides **Refresh Agile prices** and **Refresh solar forecast**.

Agile and solar downloads are cached locally. PV Forecast, Net Electricity Price and Cost Savings are calculated locally from source data and settings.

The in-app User Guide remains available offline.

---

# 13. Privacy

The public Octopus tariff/rate functions do not require Octopus account login details, API key, MPAN, meter serial number or payment details.

Location permission is requested only when **Use Current Location** is tapped. Coordinates are stored locally, reverse-geocoded by Apple to obtain the readable site name and sent to Open-Meteo for solar forecast requests. The app does not continuously monitor location.

---

# 14. UK clock changes

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

The app uses `Europe/London` and actual timestamps/durations.

---

# 15. Troubleshooting

If no Agile prices appear, check tariff/date/network and try **Refresh Agile prices**.

If no solar forecast appears, check the solar site/date and try **Refresh solar forecast**.

If **Use Current Location** shows **Current location**, reverse geocoding did not return a suitable locality. The coordinates are still valid and the label can be edited.

If current location is unavailable, check both iPhone/iPad Location Services and Agile Price Wheel's When-In-Use permission. Place/postcode search and manual coordinates remain available.

If PV, Net and Save are missing, check **Solar PV panels installed**. If it is off, that is expected.

If those pages do not return when PV is switched on again, treat that as a defect.

If the bottom navigation clips, a page title collides with controls, or Now covers page content on a supported device size, treat that as a layout defect.

If Cost Savings differs from the Net selected-sector PV saving, treat that as a defect because both use the same avoided-import formula.

If dragging a wheel changes page, treat that as a defect.

---

# 16. Internal structure

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

`SwipeDashboardView` owns conditional page navigation, adaptive screen handling, the shared Now control and PV-dependent visibility.

`GenerationEstimateView` implements PV Forecast. `CostSavingsView` implements Cost Savings.

---

# 17. Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.

Solar irradiance, PV Forecast, Net Electricity Price and Cost Savings are forecast/derived planning estimates and can differ from actual generation, energy flows and bills.
