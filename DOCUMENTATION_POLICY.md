# Documentation maintenance policy

Agile Price Wheel maintains three primary documentation surfaces:

1. `README.md` — comprehensive developer, architecture, setup, dependency, data-flow, caching, calculation, build and distribution reference in GitHub.
2. `USER_GUIDE.md` — complete operating guide for end users, including navigation, settings, offline behaviour, troubleshooting and interpretation of displayed values.
3. `AgilePriceWheel/DocumentationView.swift` — the user-facing guide compiled into the iOS application, used both as the sixth swipe page and as the modal information-button guide.

## Required rule for future changes

Any change that alters application behaviour must update the relevant documentation **in the same change/commit or pull request**.

This includes changes to:

- swipe-page order, wrap behaviour or navigation;
- user-visible features or controls;
- feature-enable/disable configuration such as the PV-installed switch;
- price-wheel, solar-wheel, generation-wheel or net-price-wheel behaviour;
- tariff discovery or Octopus API integration;
- Open-Meteo forecast/geocoding integration;
- solar-site settings, including current-location access and permissions;
- PV-array settings;
- PV-generation calculations or assumptions;
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

Before a release, verify that:

- `README.md` describes the current implementation and architecture;
- `USER_GUIDE.md` accurately describes how a user operates the current app;
- `DocumentationView.swift` matches the user-visible behaviour and essential guidance available in `USER_GUIDE.md`.

Documentation-only wording changes do not require a corresponding code change.

## Build-maintenance requirement

Compiler or Xcode compatibility fixes that do not alter user-visible behaviour do not require changes to all three user-facing documentation surfaces. They must still be reflected in the repository documentation where they affect build, setup, diagnostics, troubleshooting or source-maintenance guidance.

`AppSettingsView.swift` and `SolarSiteSettingsView.swift` use the explicit SwiftUI `Section { ... } header: { ... } footer: { ... }` form for sections that have footers. This avoids the generic-inference errors produced by combining a shorthand string-title initializer with a separate footer closure on the current project toolchain.

## Current-location solar-site requirement

The Solar Site screen supports three ways to set the forecast site:

- `Use Current Location`, using Core Location when explicitly requested by the user;
- place/postcode search through Open-Meteo geocoding;
- manual latitude/longitude entry.

Current-location access must remain opt-in. The app must request **When In Use** permission only after the user taps `Use Current Location`, and the generated Info.plist must contain an `NSLocationWhenInUseUsageDescription` string explaining that location is used to set the solar forecast site.

If location access is denied, restricted or unavailable, the app must continue to offer place/postcode search and manual coordinates. A successful current-location fix is persisted only as the selected solar-site coordinates, in the same way as the other site-selection methods.

Any change to this behaviour must update `README.md`, `USER_GUIDE.md`, and `DocumentationView.swift` together with the implementation.

## Source of truth

The implementation is authoritative for actual behaviour. Documentation must describe the implementation as it exists; documentation must not promise unfinished features.

If implementation and documentation disagree, treat that as a defect and update the documentation and/or implementation together.

## PV-installed feature-state requirement

The current app includes a persistent `Solar PV panels installed` configuration in `AppSettingsStore`.

When this setting is off, documentation must continue to state that:

- PV-array controls are disabled/greyed;
- Net price optimiser controls are disabled/greyed;
- the PV Generation page is disabled/greyed;
- the Net Electricity Price page and wheel are disabled/greyed;
- Solar Forecast remains available;
- stored PV/optimiser values are retained rather than deleted.

Any future change to which features remain available when PV is disabled must update the implementation and all three documentation surfaces together.

## Page-order requirement

The documented swipe order must match `SwipeDashboardView` exactly. The current order is:

```text
Agile Prices
→ Solar Forecast
→ PV Generation
→ Net Electricity Price
→ App Settings
→ User Guide
→ Agile Prices
```

The User Guide is page 6 of 6 and the final page in the normal left-swipe sequence. A further left swipe from User Guide wraps back to Agile Prices.

Reverse navigation does not wrap at the first page: a right swipe from User Guide returns to App Settings, while a right swipe from Agile Prices leaves the app on Agile Prices.

Any future change to this navigation order or wrap behaviour must update `SwipeDashboardView.swift`, `README.md`, `USER_GUIDE.md`, and `DocumentationView.swift` together.
