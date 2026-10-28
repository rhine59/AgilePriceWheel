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

## iOS and Android heating controller

See [Heating controller](HEATING_CONTROLLER.md) for the Synology service contract, recovery/freshness display, secure reconnection and iOS and Android feature status.

The iOS Heating guide also documents the signed price dropdown choices
and preservation of existing saved values outside those choices.

The Heating guide includes short selector labels and the information/error colour meanings.

Agile heating documents separate policy permission and fresh Homely-reported heating state.

Heating connection details are configured in App Settings; policy test/reload stays on Agile heating.

The Heating guide records the price-window boost strategy and removed temperature controls.

The iOS heating controls now support signed −20…20p values, zero, and both controller modes. The signed price controls are now also available on Android.

The iOS Heating page also has a persistent Automation switch with OFF/shutdown-pending display. ON requires prior controller activation. Android now includes the same persistent Automation control.

## Weekly heating log — iOS and Android

On **Heating**, connect and tap **Weekly heating log**. It opens the current
Monday–Sunday week; use the arrows for previous weeks and Reload or pull to
refresh. ON is red and OFF green. Each entry shows the confirmed action time,
effective price, saved on/off thresholds and reason. Times use Europe/London
and include GMT/BST to distinguish the repeated autumn hour. Logging began on
25 October 2026; earlier weeks contain no reconstructed events.

The controller retains 366 days independently of the phone. A pending-storage
warning means confirmed events are awaiting a database retry. Manual Homely
changes and compressor cycles are outside this automation log. Existing
pre-update entries may say “Price data unavailable” where a slow setup exceeded
the former 15-second budget; new entries distinguish “Heating setup timed out.”
Android now provides Heating and the weekly session/action log; see [Android parity](ANDROID.md).

The owner has approved ongoing operation and enabled Automation. New installs
still default OFF; use the app switch to pause/resume this installation without
changing its saved price policy. Heating depends on each half-hour decision.

## Heating sessions and estimated cost

**Heating → Weekly heating log** now groups each ON with its matching OFF in a
Heating sessions section. It shows elapsed duration, effective rate at each action,
raw Agile and effective unit rates for each half-hour, configured electrical load,
estimated kWh and estimated cost. Negative totals are labelled **Estimated payment**.
Individual actions remain below for investigation. Existing records pair by action
order; cost stays unavailable where historical load/rates were not saved.

Costs assume the configured electrical load throughout the confirmed enabled
interval and use effective prices after forecast solar. They are not metered
consumption or a supplier bill. Missing intervals or an unconfirmed OFF leave the
total unavailable. Sessions crossing weeks appear with the same ID in both weeks;
do not add duplicate appearances. Manual changes do not fabricate an OFF.
This feature is available on iOS and Android.


Android heating controls are implemented. See [delivery status](ANDROID-HEATING-REQUIREMENTS.md) and [verification](ANDROID-HEATING-VERIFICATION.md).


26 October bug audit: unavailable prices now stay labelled unavailable. Sessions
ending exactly at Monday midnight stay in the preceding week. An unconfirmed end
is not assumed to continue indefinitely; later weeks require recorded activity.
See [audit](BUG-AUDIT-2026-10-26.md) for checks and limits.


The 27 October schedule-target preparation in the Homely repository is offline-only; the existing app does not gain a 22°C control from that capture.

Android implementation, setup, rebuild scripts and emulator evidence: [Android guide](ANDROID.md), [requirements/status](ANDROID-HEATING-REQUIREMENTS.md), [verification](ANDROID-HEATING-VERIFICATION.md).

- [Homely consolidation](HOMELY-CONSOLIDATION.md) — unified source layout, controller commands and existing-installation migration.
- [Homely service catalogue](../services/homely/controller/SERVICES.md) — API and independent runtime responsibilities.
