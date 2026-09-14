# Documentation maintenance policy

Agile Price Wheel maintains these primary documentation surfaces:

1. `README.md` — developer, architecture, setup, dependency, data-flow, caching, calculation, build and testing reference.
2. `USER_GUIDE.md` — complete indexed operating guide for end users.
3. `AgilePriceWheel/DocumentationView.swift` — indexed user-facing guide compiled into the app.
4. `docs/INDEX.md` — central documentation index.
5. Focused implementation/testing notes under `docs/`.

## Required rule for future changes

Any change that alters application behaviour must update the relevant documentation in the same implementation cycle.

This includes page navigation, page names, Now/current-time selection, Cost Savings behaviour, PV configuration, wheel behaviour, tariff/API integration, solar-site/location behaviour, PV-array fields and units, calculations, caching, privacy, build requirements, architecture, testing and troubleshooting.

Before release verify that README, USER_GUIDE, DocumentationView and docs/INDEX.md describe the implementation as it actually exists.

## Documentation indexing requirement

The documentation must remain easy to navigate:

- `README.md` must contain a documentation/table-of-contents index near the top;
- `USER_GUIDE.md` must contain a numbered index near the top;
- `DocumentationView.swift` must begin with an in-app Index section;
- `docs/INDEX.md` must list the principal documentation surfaces and current page order.

Any new user-facing page or major feature must be added to all relevant indexes.

## Main-navigation requirement

The app has seven directly selectable pages:

```text
Octopus Agile Prices
Solar Forecast
PV Forecast
Net Electricity Price
Cost Savings
App Settings
User Guide
```

Main page changes are performed with the fixed seven-button bottom navigation bar, not a horizontal drag/swipe gesture.

Required buttons and symbols:

```text
Prices    bolt.circle.fill
Solar     sun.max.fill
PV        bolt.sun.fill
Net       sterlingsign.circle.fill
Save      banknote.fill
Settings  slider.horizontal.3
Guide     book.closed.fill
```

The selected page button must be visually highlighted. Wheel-sector dragging must never navigate between pages.

## Now-button requirement

The five metric pages are:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings

Each must expose a Now control that returns the shared selected date to today and selects the half-hour containing the current time. App Settings and User Guide must not show Now.

The control must remain in unused dark space above/right of the wheel and must not obscure metric cards, wheel sectors or page controls on supported iPhone sizes.

See `docs/NOW_BUTTON_AND_CURRENT_TIME.md` for the focused behaviour/testing note.

## Cost Savings requirement

Cost Savings uses the same forecast PV model and configured controllable load as Net Electricity Price.

For each half-hour:

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
- negative savings must be presented clearly rather than silently clamped to zero;
- Net Electricity Price must show the same selected-sector PV saving value in its wheel and detail breakdown;
- Cost Savings is disabled/greyed when Solar PV panels installed is off.

Any change to this formula must update README, USER_GUIDE, DocumentationView and docs/INDEX.md together.

## Current-location solar-site requirement

Solar Site supports:

- `Use Current Location` using Core Location when explicitly requested;
- place/postcode search through Open-Meteo geocoding;
- manual latitude/longitude entry.

Current-location access must remain opt-in. Request **When In Use** permission only after the user taps `Use Current Location`. The generated Info.plist must contain an `NSLocationWhenInUseUsageDescription` explaining why location is needed.

If permission is denied, restricted or unavailable, place/postcode search and manual coordinates must remain usable. The app must not continuously track the user after setting the solar site.

## PV-installed feature-state requirement

When `Solar PV panels installed` is off:

- PV-array controls are disabled/greyed;
- Net price optimiser controls are disabled/greyed;
- PV Forecast is disabled/greyed;
- Net Electricity Price is disabled/greyed;
- Cost Savings is disabled/greyed;
- Solar Forecast remains available;
- stored PV/optimiser values are retained.

## Solar PV array unit requirement

Numeric Solar PV array fields must keep their units visible beside the editable value:

```text
Rated peak power             kWp
Panel rating                 W
Panel tilt from horizontal   °
Azimuth                      °
Inverter maximum AC output   kW
Estimated system losses      %
```

`Number of panels` is dimensionless. Units are presentation labels only and must not be stored as part of the numeric text value.

## Build-maintenance requirement

Compiler or Xcode compatibility fixes that do not alter user-visible behaviour do not require edits to every user-facing guide, but repository build/troubleshooting documentation must still be corrected when relevant.

`AppSettingsView.swift` and `SolarSiteSettingsView.swift` use the explicit SwiftUI `Section { ... } header: { ... } footer: { ... }` form for sections that have footers on the current project toolchain.

## Source of truth

The implementation is authoritative for actual behaviour. Documentation must describe completed behaviour only. If implementation and documentation disagree, treat that as a defect.
