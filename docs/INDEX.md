# Agile Price Wheel documentation index

This file is the central index for project and user documentation.

## User documentation

1. [`../USER_GUIDE.md`](../USER_GUIDE.md) — complete operating guide for all seven pages.
2. `AgilePriceWheel/DocumentationView.swift` — in-app indexed User Guide, available offline.
3. [`NOW_BUTTON_AND_CURRENT_TIME.md`](NOW_BUTTON_AND_CURRENT_TIME.md) — Now-button behaviour and testing.

## Developer and technical documentation

1. [`../README.md`](../README.md) — architecture, data sources, calculations, setup and testing.
2. [`../DOCUMENTATION_POLICY.md`](../DOCUMENTATION_POLICY.md) — documentation maintenance rules.

## Current page index

1. Octopus Agile Prices
2. Solar Forecast
3. PV Forecast
4. Net Electricity Price
5. Cost Savings
6. App Settings
7. User Guide

## Cost Savings model

The Cost Savings page shows the forecast value of PV generation that offsets the configured controllable load.

For each half-hour:

```text
load energy = configured load kW × period hours
forecast PV = forecast PV energy for the same period
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

Only PV that offsets the configured load is counted. Surplus export income is not included. When the Agile price is negative, the calculated saving can also be negative because importing electricity would have been financially beneficial in that period.

The selected half-hour's PV cost saving is also shown in the centre and detail breakdown of the Net Electricity Price view.
