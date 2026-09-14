# Documentation maintenance policy

Agile Price Wheel maintains these primary documentation surfaces:

1. `README.md` — developer, architecture, setup, dependency, data-flow, caching, calculation, build and testing reference.
2. `USER_GUIDE.md` — complete operating guide for end users.
3. `AgilePriceWheel/DocumentationView.swift` — the user-facing guide compiled into the app.
4. Focused implementation/testing notes under `docs/`.

## Required rule for future changes

Any change that alters application behaviour must update the relevant documentation in the same implementation cycle.

This includes changes to:

- page order, button-navigation behaviour or wrap behaviour;
- page names and user-visible titles;
- Now/current-time selection behaviour;
- feature-enable/disable configuration such as the PV-installed switch;
- price, solar, PV Forecast or net-price wheel behaviour;
- tariff discovery or Octopus API integration;
- Open-Meteo forecast/geocoding integration;
- solar-site settings, including current-location access and permissions;
- PV-array settings, displayed units and validation;
- PV Forecast calculations or assumptions;
- net/effective-price calculations or assumptions;
- network behaviour and error handling;
- offline caching, persistence or refresh behaviour;
- server/local data-source indicators;
- privacy or stored information;
- Swift/Xcode/iOS requirements;
- dependencies or frameworks;
- project setup, signing, building or deployment;
- file/module architecture;
- testing, troubleshooting or diagnostics procedures.

Before release verify that README, USER_GUIDE and DocumentationView describe the implementation as it actually exists.

## Build-maintenance requirement

Compiler or Xcode compatibility fixes that do not alter user-visible behaviour do not require edits to every user-facing guide, but repository build/troubleshooting documentation must still be corrected when relevant.

`AppSettingsView.swift` and `SolarSiteSettingsView.swift` use the explicit SwiftUI `Section { ... } header: { ... } footer: { ... }` form for sections that have footers on the current project toolchain.

## Current-location solar-site requirement

Solar Site supports:

- `Use Current Location` using Core Location when explicitly requested;
- place/postcode search through Open-Meteo geocoding;
- manual latitude/longitude entry.

Current-location access must remain opt-in. Request **When In Use** permission only after the user taps `Use Current Location`. The generated Info.plist must contain an `NSLocationWhenInUseUsageDescription` explaining why location is needed.

If permission is denied, restricted or unavailable, place/postcode search and manual coordinates must remain usable. The app must not continuously track the user after setting the solar site.

## PV-installed feature-state requirement

The app includes a persistent `Solar PV panels installed` setting.

When it is off:

- PV-array controls are disabled/greyed;
- Net price optimiser controls are disabled/greyed;
- the **PV Forecast** page is disabled/greyed;
- the Net Electricity Price page and wheel are disabled/greyed;
- Solar Forecast remains available;
- stored PV/optimiser values are retained.

Documentation must not refer to the user-facing third page as `PV Generation`; its current user-facing name is **PV Forecast**. The implementation type `GenerationEstimateView` may retain its internal name.

## Solar PV array unit requirement

Numeric Solar PV array fields must keep their units visible beside the editable value, including after a value has been entered.

Required presentation:

```text
Rated peak power             kWp
Panel rating                 W
Panel tilt from horizontal   °
Azimuth                      °
Inverter maximum AC output   kW
Estimated system losses      %
```

`Number of panels` is dimensionless.

Units are presentation labels only; they must not be stored as part of the numeric text value. Any change to the field/unit mapping must update README, USER_GUIDE and DocumentationView.

## Now-button requirement

The four metric pages are:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price

Each must expose a Now control that returns the shared selected date to today and selects the half-hour containing the current time. App Settings and User Guide must not show the Now control.

See `docs/NOW_BUTTON_AND_CURRENT_TIME.md` for the focused behaviour/testing note.

## Main-navigation requirement

The documented order must match `SwipeDashboardView`:

```text
Octopus Agile Prices
→ Solar Forecast
→ PV Forecast
→ Net Electricity Price
→ App Settings
→ User Guide
→ Octopus Agile Prices
```

Main page changes must be performed with explicit bottom navigation buttons, not a horizontal drag/swipe gesture. This is intentional because the price, solar, PV Forecast and net-price wheels use touch/drag interaction and page swiping can conflict with sector selection.

Required behaviour:

- a fixed bottom navigation bar is available on all six pages;
- `Back` moves to the preceding page;
- `Back` is disabled on Octopus Agile Prices;
- `Next` moves forward through the normal page order;
- on User Guide, the forward button is labelled `Prices` and returns to Octopus Agile Prices;
- six page dots and a page-position indicator identify the current page;
- horizontal dragging elsewhere on a page must not change the main page;
- wheel-sector dragging must never navigate to another page.

The historical Swift type name `SwipeDashboardView` may remain even though page-changing swipe gestures are no longer used.

Any future page-order, page-name or navigation-control change must update `SwipeDashboardView.swift`, `README.md`, `USER_GUIDE.md` and `DocumentationView.swift` together.

## Source of truth

The implementation is authoritative for actual behaviour. Documentation must describe completed behaviour only. If implementation and documentation disagree, treat that as a defect.
