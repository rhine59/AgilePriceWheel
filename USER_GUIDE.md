# Agile Price Wheel — Complete User Guide

This guide explains how to use every current part of Agile Price Wheel. The first dashboard page is titled **Octopus Agile Prices**.

The same essential guidance is built into the app as the sixth page and can also be opened from the information buttons.

---

# 1. Page order and navigation

The pages are arranged in this order:

```text
Octopus Agile Prices
    ↓
Solar Forecast
    ↓
PV Forecast
    ↓
Net Electricity Price
    ↓
App Settings
    ↓
User Guide
    ↓
Octopus Agile Prices
```

Use the fixed **Back** and **Next** buttons at the bottom of the screen to move between pages.

Horizontal swipe navigation is intentionally disabled. This prevents a touch or drag on one of the interactive wheel sectors from being mistaken for a page-change gesture.

On the first page, **Back** is disabled. On the User Guide page, the right-hand button is labelled **Prices** and returns to Octopus Agile Prices.

Six page dots plus a `1 of 6` style indicator show the current page.

The first four pages also show a **Now** button because they display half-hour metrics.

---

# 2. Now button

The **Now** button appears on:

- Octopus Agile Prices;
- Solar Forecast;
- PV Forecast;
- Net Electricity Price.

Tapping it:

- changes the shared selected date to today;
- loads today's source data if needed;
- selects the half-hour containing the current time;
- updates the PV Forecast and Net Electricity Price selections to the same current period.

The app uses:

```text
validFrom <= now < validTo
```

If no matching period is available, the first available period is used as a fallback.

---

# 3. Octopus Agile Prices

This is the first page.

Each wheel sector represents one Agile settlement period. A normal day has 48 half-hours; UK clock-change days can have 46 or 50.

Touch or drag around the wheel to choose a period. Page navigation will not respond to horizontal wheel dragging because swipe-to-change-page navigation has been removed.

The page shows:

- selected Agile price;
- selected period;
- lowest price and time;
- highest price and time;
- average price;
- selected tariff information;
- server/cache status.

Bottom controls inside the page provide Prices, Chart and Details views. The separate fixed navigation bar below them moves between the six main pages.

Negative prices are blue. Positive prices progress from green through yellow/orange to red relative to the selected day.

---

# 4. Solar Forecast

Use **Next** from Octopus Agile Prices.

This page shows forecast global horizontal irradiance (GHI / shortwave solar radiation) in W/m² for the same selected day.

The page shows:

- an interactive half-hour solar wheel;
- selected irradiance;
- peak irradiance and time;
- daylight average;
- forecast-site coordinates;
- server/cache status.

Solar data comes from Open-Meteo 15-minute shortwave-radiation forecasts, combined into half-hour values.

Solar Forecast remains available when **Solar PV panels installed** is off because it is a weather/irradiance view.

---

# 5. Setting the solar site

In App Settings choose **Set solar site** or **Change solar site**.

You can set the site in three ways.

## Use Current Location

Tap **Use Current Location** to ask iOS for When-In-Use location permission and use the device position as the solar forecast site.

The location request happens only when you tap the button. The app does not continuously track your location.

If permission is denied, you can still use either of the following methods.

## Search by place or postcode

Enter a place or postcode and choose the appropriate Open-Meteo geocoding result.

## Manual coordinates

Enter latitude and longitude directly.

The selected site is stored locally and is used to request solar irradiance forecasts.

---

# 6. PV Forecast

The page previously named **PV Generation** is now named **PV Forecast**.

Use **Next** from Solar Forecast.

Each wheel sector represents forecast PV electrical energy for that half-hour in kWh.

The page shows:

- estimated daily energy total;
- peak estimated power and time;
- selected half-hour energy;
- selected half-hour average power;
- effective array capacity used.

If **Solar PV panels installed** is off, PV Forecast is greyed and disabled, while your saved PV settings are retained.

---

# 7. How PV Forecast is calculated

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

Rated array kWp takes priority. If it is blank, the app can derive array capacity from:

```text
number of panels × panel rating in watts / 1000
```

The current model uses horizontal GHI. Tilt and azimuth are saved but are not yet applied to the irradiance calculation. Shading, temperature, snow/soiling, detailed inverter efficiency, mismatch, degradation, horizon effects and albedo are also not explicitly modelled.

Treat PV Forecast as a planning estimate rather than guaranteed generation.

---

# 8. Net Electricity Price

Use **Next** from PV Forecast.

This page estimates the effective p/kWh cost of running a configured load after forecast PV has reduced expected grid import.

For each half-hour:

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
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

The optimiser load defaults to **3.0 kW**.

The calculation assumes all forecast PV is available to the configured load. It does not yet subtract ordinary household background demand first and does not credit export income.

If **Solar PV panels installed** is off, the Net Electricity Price page and wheel are greyed and disabled.

---

# 9. Net-price colours

The Net Electricity Price wheel uses fixed bands:

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

App Settings is page 5 of 6.

It contains Agile tariff/day controls, solar site, solar refresh, PV availability, PV-array details and optimiser load.

Use **Back** to return to Net Electricity Price and **Next** to open the User Guide.

## Solar PV availability

The setting:

```text
Solar PV panels installed
```

controls whether PV-derived features are active.

When switched off:

- PV-array fields are greyed and disabled;
- optimiser controls are greyed and disabled;
- PV Forecast is greyed and disabled;
- Net Electricity Price is greyed and disabled;
- Solar Forecast remains active;
- existing PV and optimiser values remain saved.

Turning it back on restores the saved values.

---

# 11. Solar PV array settings and units

The Solar PV array section contains:

- Array name;
- Rated peak power;
- Number of panels;
- Panel rating;
- Panel tilt from horizontal;
- Azimuth;
- Inverter maximum AC output;
- Estimated system losses;
- Notes.

The app keeps engineering units visibly displayed beside the editable number. They do not disappear when a value has been entered.

| Field | Unit shown |
|---|---|
| Rated peak power | kWp |
| Panel rating | W |
| Panel tilt from horizontal | ° |
| Azimuth | ° |
| Inverter maximum AC output | kW |
| Estimated system losses | % |

Number of panels has no unit.

The unit label is not part of the stored number. For example, enter `5.0`, not `5.0 kWp`; the app displays `kWp` alongside it.

Azimuth convention:

```text
0° North
90° East
180° South
270° West
```

---

# 12. Net price optimiser setting

Set **Controllable load power (kW)** to the appliance/load size you want the Net Electricity Price calculation to evaluate.

The default is 3.0 kW.

This section is disabled when Solar PV panels installed is off.

---

# 13. User Guide page

The User Guide is page 6 of 6.

Use **Back** to return to App Settings. Use **Prices** on the right to return to Octopus Agile Prices and begin the sequence again.

The guide is compiled into the app, so it remains available offline.

---

# 14. Refresh and caching

App Settings provides:

- Refresh Agile prices;
- Refresh solar forecast.

Agile and solar downloads are cached locally.

PV Forecast and Net Electricity Price are local calculations derived from source data and settings. They can be recalculated from cached source data when the required inputs are already available.

---

# 15. UK clock changes

The app uses `Europe/London` time.

Typical day lengths:

```text
normal day          48 half-hours
spring clock change 46 half-hours
autumn clock change 50 half-hours
```

Actual timestamps and period durations are used.

---

# 16. Privacy

The app does not require Octopus account login details, API key, MPAN, meter serial number or payment details for the public tariff/rate functions used here.

Stored locally:

- selected tariff;
- solar site name and coordinates;
- PV-installed state;
- PV-array settings;
- optimiser load;
- cached Agile data;
- cached solar data.

Location permission is requested only if you tap **Use Current Location**. It is a When-In-Use request. The resulting coordinates are used to set the solar forecast site; the app does not continuously monitor location.

Configured coordinates are sent to Open-Meteo when forecast/geocoding requests require them.

---

# 17. Troubleshooting

## No Agile prices

Check the selected tariff/date, internet connection and publication status. Try **Refresh Agile prices**.

## No solar forecast

Check the solar site/date and try **Refresh solar forecast**.

## Use Current Location does not work

Check iOS location permission for Agile Price Wheel. If location permission is denied, use place/postcode search or manual coordinates instead.

## PV Forecast is greyed

Check **Solar PV panels installed** in App Settings. If the property has PV, turn it on.

## PV Forecast shows no output

Check that a solar forecast exists and that rated kWp or panel count + panel watts are configured.

## Net Electricity Price is greyed

Check **Solar PV panels installed**. The solar-adjusted net price is deliberately disabled when PV is configured as not installed.

## Now does not select the expected period

Confirm source data for today has loaded. The app selects the half-hour for which `validFrom <= now < validTo`.

## The page changes while using a wheel

It should not. Horizontal swipe navigation between main pages has been removed. Use the fixed Back/Next controls at the bottom. If wheel dragging still causes a page change, treat that as a defect.

## Units disappear while editing

They should not. The Solar PV array fields display persistent suffixes for kWp, W, °, kW and %. If a unit is missing, treat that as a UI defect.

---

# 18. Internal structure

```text
AgilePriceWheelApp
        ↓
SwipeDashboardView
        ├─ Octopus Agile Prices
        │    └─ AgileViewModel → OctopusAPI / AgileCacheStore
        ├─ Solar Forecast
        │    └─ SolarForecastModel → SolarForecastAPI / SolarForecastCache
        ├─ PV Forecast
        │    └─ GenerationEstimateView + AppSettingsStore
        ├─ Net Electricity Price
        │    └─ NetEffectivePriceView
        ├─ App Settings
        │    └─ AppSettingsStore / SolarSiteSettingsView
        └─ User Guide
             └─ DocumentationView
```

`SwipeDashboardView` keeps its historical type name but now uses explicit bottom buttons rather than swipe gestures for page changes.

The internal Swift type `GenerationEstimateView` keeps its existing name even though the user-facing page is now called PV Forecast.

---

# 19. Documentation

The project documentation surfaces are:

- `README.md` — developer/technical reference;
- `USER_GUIDE.md` — complete operating guide;
- `AgilePriceWheel/DocumentationView.swift` — in-app guide;
- `DOCUMENTATION_POLICY.md` — documentation-maintenance rules;
- focused notes in `docs/`.

Functional changes must keep these aligned with the implementation.

---

# 20. Disclaimer

Agile Price Wheel is independent and is not an official Octopus Energy or Open-Meteo application.

Electricity prices should be checked against the user's actual tariff. Solar irradiance, PV Forecast and Net Electricity Price are forecasts/derived planning estimates and can differ from actual generation, energy flows and bills.
