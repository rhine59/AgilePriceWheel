# Documentation maintenance policy

Agile Price Wheel maintains these primary documentation surfaces:

1. `README.md` — developer, architecture, setup, dependency, data-flow, caching, calculation, build and testing reference.
2. `USER_GUIDE.md` — complete operating guide for end users.
3. `AgilePriceWheel/DocumentationView.swift` — the user-facing guide compiled into the app.
4. Focused implementation/testing notes under `docs/`.

## Required rule for future changes

Any change that alters application behaviour must update the relevant documentation in the same implementation cycle.

This includes changes to page navigation, page names, Now/current-time selection, Now-button placement, PV configuration, wheel behaviour, tariff/API integration, solar-site/location behaviour, PV-array fields and units, calculations, caching, privacy, build requirements, architecture, testing and troubleshooting.

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

Documentation must use the user-facing name **PV Forecast**. The implementation type `GenerationEstimateView` may retain its internal name.

## Solar PV array unit requirement

Numeric Solar PV array fields must keep their units visible beside the editable value, including after a value has been entered.

```text
Rated peak power             kWp
Panel rating                 W
Panel tilt from horizontal   °
Azimuth                      °
Inverter maximum AC output   kW
Estimated system losses      %
```

`Number of panels` is dimensionless. Units are presentation labels only and must not be stored as part of the numeric text value.

## Now-button requirement

The four metric pages are:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price

Each must expose a Now control that returns the shared selected date to today and selects the half-hour containing the current time. App Settings and User Guide must not show the Now control.

The Now control must be positioned in unused dark space above and to the right of the wheel. It must not obscure wheel sectors, metric cards, headings, settings/info controls or other useful content on supported iPhone screen sizes. Page-specific vertical offsets are acceptable where needed to keep the control clear of each page's header.

See `docs/NOW_BUTTON_AND_CURRENT_TIME.md` for the focused behaviour/testing note.

## Main-navigation requirement

The app has six directly selectable pages:

```text
Octopus Agile Prices
Solar Forecast
PV Forecast
Net Electricity Price
App Settings
User Guide
```

Main page changes must be performed with the fixed six-button bottom navigation bar, not with a horizontal drag/swipe gesture. This is intentional because the four wheel pages use touch/drag interaction and page swiping can conflict with sector selection.

Required bottom buttons and symbols are:

```text
Prices    bolt.circle.fill
Solar     sun.max.fill
PV        bolt.sun.fill
Net       sterlingsign.circle.fill
Settings  slider.horizontal.3
Guide     book.closed.fill
```

Required behaviour:

- all six buttons are visible on all six pages;
- tapping any button jumps directly to its page;
- the selected page button is visually highlighted;
- horizontal dragging elsewhere on a page does not navigate between main pages;
- wheel-sector dragging never changes the main page;
- obsolete swipe, Back/Next, page-dot and page-number navigation instructions must not be shown in page footers.

The historical Swift type name `SwipeDashboardView` may remain even though page-changing swipe gestures are no longer used.

Any future page-name, icon or navigation-control change must update `SwipeDashboardView.swift`, `README.md`, `USER_GUIDE.md` and `DocumentationView.swift` together.

## Source of truth

The implementation is authoritative for actual behaviour. Documentation must describe completed behaviour only. If implementation and documentation disagree, treat that as a defect.
