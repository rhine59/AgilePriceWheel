# Agile Price Wheel documentation index

## Shared documentation

1. [`../README.md`](../README.md) — project overview, shared calculations, Apple/Android build paths and release verification.
2. [`../USER_GUIDE.md`](../USER_GUIDE.md) — cross-platform operating guide.
3. [`../DOCUMENTATION_POLICY.md`](../DOCUMENTATION_POLICY.md) — documentation and platform-parity maintenance rules.

## Apple/iPhone/iPad

1. `AgilePriceWheel/DocumentationView.swift` — offline in-app guide.
2. [`NOW_BUTTON_AND_CURRENT_TIME.md`](NOW_BUTTON_AND_CURRENT_TIME.md) — Now behaviour.
3. [`SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md`](SCREEN_LAYOUT_AND_DEVICE_SUPPORT.md) — SwiftUI responsive-layout rules and device matrix.

## Android

1. [`../android/README.md`](../android/README.md) — Android Studio setup, dependencies, calculations and test checklist.
2. [`ANDROID.md`](ANDROID.md) — Android/iOS parity contract and maintenance scope.

## Shared page model

With PV enabled: Prices, Solar, PV, Net, Save, Settings, Guide. With PV disabled: Prices, Solar, Settings, Guide. Re-enabling PV restores PV, Net and Save.

## Shared Cost Savings model

```text
load energy = configured load kW × period hours
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

Net Electricity Price must surface the same selected-period PV saving.

## iOS Heating controller

See [Heating controller](HEATING_CONTROLLER.md) for the Synology service contract, recovery/freshness display, secure reconnection and iOS-only feature status.

The iOS Heating guide also documents the price/temperature dropdown choices
and preservation of existing saved values outside those choices.

The Heating guide includes short selector labels and the information/error colour meanings.

Agile heating documents separate policy permission and fresh Homely-reported heating state.

Heating connection details are configured in App Settings; policy test/reload stays on Agile heating.

The Heating guide records the price-window boost strategy and removed temperature controls.

The iOS heating controls now support signed −20…20p values, zero, and both controller modes. This heating-client update is iOS-only; Android parity is not claimed.

The iOS Heating page also has a persistent Automation switch with OFF/shutdown-pending display. ON requires prior controller activation. This is not implemented on Android.
