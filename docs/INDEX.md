# Agile Price Wheel documentation index

This file is the central index for project and user documentation.

## User documentation

1. [`../USER_GUIDE.md`](../USER_GUIDE.md) — complete operating guide for all seven defined pages, conditional PV-page visibility and adaptive screen behaviour.
2. `AgilePriceWheel/DocumentationView.swift` — in-app indexed User Guide, available offline.
3. [`NOW_BUTTON_AND_CURRENT_TIME.md`](NOW_BUTTON_AND_CURRENT_TIME.md) — Now-button behaviour and testing.
4. [`SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) — responsive layout rules, navigation fallbacks and device-size testing matrix.

## Developer and technical documentation

1. [`../README.md`](../README.md) — architecture, data sources, calculations, adaptive layout, setup and testing.
2. [`../DOCUMENTATION_POLICY.md`](../DOCUMENTATION_POLICY.md) — documentation maintenance rules and source-of-truth requirements.

## Current page index

The app defines seven pages:

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings
6. App Settings
7. User Guide

Navigation is conditional on **Solar PV panels installed**:

- **PV on:** all seven page buttons are available.
- **PV off:** PV Forecast, Net Electricity Price and Cost Savings are hidden; the bottom bar shows Prices, Solar, Settings and Guide.
- Turning PV back on restores PV, Net and Save immediately and keeps saved PV-array and optimiser settings.

The PV navigation symbol is `bolt.fill`.

## Adaptive layout summary

The dashboard uses SwiftUI adaptive layout rather than per-device offsets:

- bottom navigation uses `ViewThatFits` with normal icon+label, compact icon+label and icon-only fallback presentations;
- navigation controls retain accessibility labels and a minimum 44-point target height;
- metric and Settings headers can reflow into a stacked arrangement on narrow widths;
- content is centred and width-limited on larger/regular-width displays;
- compact-width layouts use reduced side margins;
- Now occupies reserved layout space rather than floating over content.

See [`SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) for the complete rules and test matrix.

## Cost Savings model

For each half-hour:

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

Only PV that offsets the configured load is counted. Surplus export income is not included. When the Agile price is negative, calculated saving can also be negative.

The selected half-hour's PV cost saving is also shown by Net Electricity Price.
