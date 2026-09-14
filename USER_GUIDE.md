# Agile Price Wheel — Complete User Guide

This guide explains the current Agile Price Wheel app. The first dashboard page is titled **Octopus Agile Prices**.

---

# 1. Main navigation

The app has six pages:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. App Settings
6. User Guide

A fixed navigation bar is shown at the bottom of every page. It has six direct buttons:

| Button | Opens |
|---|---|
| ⚡ Prices | Octopus Agile Prices |
| ☀️ Solar | Solar Forecast |
| ☀️⚡ PV | PV Forecast |
| £ Net | Net Electricity Price |
| sliders Settings | App Settings |
| book Guide | User Guide |

The selected page button is highlighted in orange.

You no longer need Back/Next controls and there is no horizontal swipe navigation between pages. This avoids conflicts with touching or dragging around the wheel sectors.

Obsolete swipe instructions have been removed from the bottoms of the Solar Forecast, PV Forecast, Net Electricity Price and Settings pages.

---

# 2. Now button

The **Now** button appears on:

- Octopus Agile Prices;
- Solar Forecast;
- PV Forecast;
- Net Electricity Price.

Tapping Now:

- returns the shared selected date to today;
- loads today's source data if required;
- selects the half-hour containing the current time;
- updates PV Forecast and Net Electricity Price to the same period.

The current-period test is:

```text
validFrom <= now < validTo
```

The Now button is deliberately placed in the unused dark area above and to the right of the wheel. It should not cover wheel sectors, metric cards or page controls. The app uses a slightly different vertical offset on the Octopus price page to keep the button clear of its header.

---

# 3. Octopus Agile Prices

Each wheel sector represents one Agile settlement period. A normal day has 48 half-hours; UK clock-change days can have 46 or 50.

Touch or drag around the wheel to select a period. The page shows selected, lowest, highest and average prices, selected tariff details and server/cache status.

Negative prices are blue. Positive prices progress from green through yellow/orange to red relative to that day.

The page also contains Prices, Chart and Details views.

---

# 4. Solar Forecast

This page shows forecast global horizontal irradiance (GHI / shortwave solar radiation) in W/m².

It shows an interactive half-hour solar wheel, selected irradiance, peak irradiance/time, daylight average, forecast-site coordinates and source/cache status.

Open-Meteo 15-minute shortwave-radiation samples are combined into half-hour values.

Solar Forecast remains available even when **Solar PV panels installed** is off.

---

# 5. Setting the solar site

In App Settings choose **Set solar site** or **Change solar site**.

You can use:

1. **Use Current Location** — asks iOS for When-In-Use permission only when tapped;
2. place/postcode search;
3. manual latitude/longitude.

The app does not continuously track location. Search and manual coordinates remain available if permission is denied.

---

# 6. PV Forecast

Each wheel sector represents forecast PV electrical energy for that half-hour in kWh.

The page shows estimated daily total, peak output/time, selected half-hour energy and average power, and effective array capacity used.

If **Solar PV panels installed** is off, PV Forecast is greyed and disabled while saved PV settings remain stored.

For each period:

```text
irradiance factor = max(GHI, 0) / 1000
raw PV power = array kWp × irradiance factor
loss-adjusted power = raw PV power × (1 - loss percentage)
estimated power = min(loss-adjusted power, inverter maximum)  [if configured]
estimated energy = estimated power × actual period duration
```

Rated kWp takes priority. If blank, capacity can be derived from panel count × panel watts / 1000.

Tilt and azimuth are stored but are not yet applied because the current model uses horizontal GHI rather than plane-of-array irradiance.

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

The optimiser load defaults to **3.0 kW**.

The calculation assumes all forecast PV is available to the configured load. It does not yet subtract normal household background demand first and does not credit export income.

The Net Electricity Price wheel uses fixed colour bands from dark green at negative values through green/lime/yellow/orange/red to dark red above 50 p/kWh.

---

# 8. App Settings

Settings contains Agile tariff/region, selected day, refresh controls, solar site, PV availability, PV-array details and optimiser load.

When **Solar PV panels installed** is switched off:

- PV-array fields are greyed and disabled;
- optimiser controls are greyed and disabled;
- PV Forecast is greyed and disabled;
- Net Electricity Price is greyed and disabled;
- Solar Forecast remains active;
- saved PV and optimiser values are retained.

---

# 9. Solar PV array settings and units

The PV-array section contains Array name, Rated peak power, Number of panels, Panel rating, Panel tilt, Azimuth, Inverter maximum AC output, Estimated system losses and Notes.

Engineering units stay visible beside the editable value:

| Field | Unit |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt from horizontal | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

Number of panels has no unit. Enter numeric values only; the unit labels are display-only.

Azimuth convention:

```text
0° North
90° East
180° South
270° West
```

---

# 10. Refresh, caching and offline use

App Settings provides **Refresh Agile prices** and **Refresh solar forecast**.

Agile and solar downloads are cached locally. PV Forecast and Net Electricity Price are calculated locally from source data and settings and can be recalculated from cached data when the required inputs are available.

The in-app User Guide is bundled with the app and remains available offline.

---

# 11. Privacy

The public Octopus tariff/rate functions do not require Octopus account login details, API key, MPAN, meter serial number or payment details.

Location permission is requested only when **Use Current Location** is tapped. The selected coordinates are stored locally and sent to Open-Meteo when forecast/geocoding requests require them.

PV settings, optimiser load and derived calculations remain local.

---

# 12. UK clock changes

The app uses `Europe/London` time and actual timestamps/durations:

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

---

# 13. Troubleshooting

If no Agile prices appear, check tariff/date/network and try **Refresh Agile prices**.

If no solar forecast appears, check the solar site/date and try **Refresh solar forecast**.

If **Use Current Location** fails, check iOS location permission or use place/postcode search or manual coordinates.

If PV Forecast or Net Electricity Price is greyed, check **Solar PV panels installed**.

If Now selects an unexpected period, confirm today's source data has loaded.

If the Now button covers data or controls on a supported iPhone size, treat that as a layout defect. It should remain in the unused dark area above/right of the wheel.

If dragging a wheel changes pages, that is a defect: main page changes should occur only by tapping one of the six bottom buttons.

If a PV engineering unit disappears while editing, treat that as a UI defect.

---

# 14. Internal structure

```text
AgilePriceWheelApp
        ↓
SwipeDashboardView
        ├─ Octopus Agile Prices
        ├─ Solar Forecast
        ├─ PV Forecast
        ├─ Net Electricity Price
        ├─ App Settings
        └─ User Guide
```

`SwipeDashboardView` retains its historical name, but swipe-based page changing has been removed. It now owns the fixed six-button direct navigation bar and the Now-button overlay placement.

The internal Swift type `GenerationEstimateView` implements the user-facing PV Forecast page.

---

# 15. Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.

Solar irradiance, PV Forecast and Net Electricity Price are forecasts/derived planning estimates and can differ from actual generation, energy flows and bills.
