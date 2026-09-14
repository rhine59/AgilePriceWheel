# Documentation maintenance policy

Agile Price Wheel maintains these primary documentation surfaces:

1. `README.md` — developer, architecture, setup, dependency, data-flow, caching, calculation, build and testing reference.
2. `USER_GUIDE.md` — complete indexed operating guide for end users.
3. `AgilePriceWheel/DocumentationView.swift` — indexed user-facing guide compiled into the app.
4. `docs/INDEX.md` — central documentation index.
5. Focused implementation/testing notes under `docs/`, including Now/current-time behaviour and adaptive screen layout.

## Required rule for future changes

Any change that alters application behaviour must update the relevant documentation in the same implementation cycle.

This includes page navigation, page names, adaptive screen layout, Now/current-time selection, Cost Savings behaviour, PV configuration, wheel behaviour, tariff/API integration, solar-site/location behaviour, PV-array fields and units, calculations, caching, privacy, build requirements, architecture, testing and troubleshooting.

Before release verify that README, USER_GUIDE, DocumentationView and docs/INDEX.md describe the implementation as it actually exists.

## Documentation indexing requirement

- `README.md` must contain a documentation/table-of-contents index near the top;
- `USER_GUIDE.md` must contain a numbered index near the top;
- `DocumentationView.swift` must begin with an in-app Index section;
- `docs/INDEX.md` must list the principal documentation surfaces and current page order;
- focused layout rules must be documented in `docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`.

Any new user-facing page or major feature must be added to all relevant indexes.

## Main-navigation requirement

The app defines seven directly selectable pages:

```text
Octopus Agile Prices
Solar Forecast
PV Forecast
Net Electricity Price
Cost Savings
App Settings
User Guide
```

Main page changes are performed with bottom navigation, not horizontal drag/swipe gestures.

Required buttons and symbols when PV is enabled:

```text
Prices    bolt.circle.fill
Solar     sun.max.fill
PV        bolt.fill
Net       sterlingsign.circle.fill
Save      banknote.fill
Settings  slider.horizontal.3
Guide     book.closed.fill
```

When `Solar PV panels installed` is off, PV, Net and Save are hidden. Prices, Solar, Settings and Guide remain visible. Turning PV back on restores the three hidden pages immediately.

The selected page button must be visually highlighted. Wheel-sector dragging must never navigate between pages.

## Adaptive screen-layout requirement

Top-level screen handling must avoid device-specific fixed offsets.

Required principles:

- use flexible SwiftUI layout rather than fixed screen coordinates;
- bottom navigation must adapt to available width;
- current implementation uses `ViewThatFits(in: .horizontal)` with normal icon+label, compact icon+label and icon-only fallback forms;
- navigation targets must preserve accessibility labels and at least a 44-point target height;
- metric and Settings headers must reflow when width is insufficient;
- content should be centred and width-limited on regular-width displays;
- compact-width screens should use smaller side margins;
- Now must occupy normal layout space rather than float over data;
- release testing must include small, standard and large iPhones plus a regular-width iPad layout and at least one larger Dynamic Type setting.

See `docs/SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md` for the detailed implementation and test matrix.

## Now-button requirement

The metric pages are:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings

Each visible metric page must expose a Now control that returns the shared selected date to today and selects the half-hour containing the current time. App Settings and User Guide must not show Now.

The control must be part of normal layout flow and must not obscure headings, source status, wheel sectors, metric cards or other controls.

See `docs/NOW_BUTTON_AND_CURRENT_TIME.md`.

## Cost Savings requirement

Cost Savings uses the same forecast PV model and configured controllable load as Net Electricity Price.

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for that period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × published Agile price
```

Required behaviour:

- one Cost Savings wheel sector per matched half-hour;
- selected sector shows saving in pence;
- page shows forecast day total saving, best half-hour and total avoided grid import;
- surplus PV above the configured load is not counted as import-cost saving;
- export revenue is not included;
- negative Agile prices may produce negative savings;
- Net Electricity Price must show the same selected-sector PV saving value;
- Cost Savings is hidden from navigation when PV is off and returns when PV is on.

## Current-location solar-site requirement

Solar Site supports:

- `Use Current Location` using Core Location when explicitly requested;
- place/postcode search through Open-Meteo geocoding;
- manual latitude/longitude entry.

Current-location access must remain opt-in. Request **When In Use** permission only after the user taps `Use Current Location`. The generated Info.plist must contain an `NSLocationWhenInUseUsageDescription` explaining why location is needed.

After a current-location fix, the app should reverse-geocode the coordinates to a familiar locality/town name where possible. If no suitable common name is found, use `Current location`. The saved site name must be editable without changing latitude or longitude.

On iOS 26 and later, reverse geocoding must use MapKit `MKReverseGeocodingRequest` rather than deprecated `CLGeocoder`. A legacy Core Location geocoder may remain only inside an availability-limited compatibility path for earlier supported systems. Location authorization changes should be handled through `locationManagerDidChangeAuthorization(_:)`; do not synchronously call Location Services availability APIs on the main actor when that can trigger responsiveness diagnostics.

If permission is denied, restricted or unavailable, place/postcode search and manual coordinates must remain usable. The app must not continuously track the user.

## PV-installed feature-state requirement

When `Solar PV panels installed` is off:

- PV Forecast, Net Electricity Price and Cost Savings are hidden from bottom navigation;
- PV-array controls are disabled/greyed;
- Net price optimiser controls are disabled/greyed;
- Solar Forecast remains available;
- stored PV/optimiser values are retained;
- re-enabling PV immediately restores PV, Net and Save.

## Solar PV array unit requirement

```text
Rated peak power             kWp
Panel rating                 W
Panel tilt from horizontal   °
Azimuth                      °
Inverter maximum AC output   kW
Estimated system losses      %
```

`Number of panels` is dimensionless. Units are presentation labels only.

## Build-maintenance requirement

Compiler or Xcode compatibility fixes that do not alter user-visible behaviour do not require edits to every user-facing guide, but repository build/troubleshooting documentation must still be corrected when relevant.

Current release builds should be checked for SDK deprecation warnings and runtime responsiveness warnings, particularly around location APIs. `AppSettingsView.swift` and `SolarSiteSettingsView.swift` use the explicit SwiftUI `Section { ... } header: { ... } footer: { ... }` form for sections that have footers on the current project toolchain.

## Source of truth

The implementation is authoritative for actual behaviour. Documentation must describe completed behaviour only. If implementation and documentation disagree, treat that as a defect.
