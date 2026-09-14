# Documentation and platform-parity policy

Agile Price Wheel now has native Apple and Android clients. Documentation must describe completed behaviour accurately and must distinguish source-level implementation from build/device verification.

## Documentation surfaces

- `README.md`: shared project architecture, calculations, build paths and status.
- `USER_GUIDE.md`: cross-platform user behaviour.
- `AgilePriceWheel/DocumentationView.swift`: Apple in-app guide.
- `android/README.md`: Android build, dependencies, architecture and verification.
- `docs/INDEX.md`: central index.
- `docs/ANDROID.md`: Android parity contract.
- focused Apple implementation notes under `docs/`.

## Required maintenance rule

Every user-visible feature change must be assessed for both platforms. If a change applies to only one platform, documentation must say so rather than implying parity. Relevant documentation must be updated in the same development cycle.

Changes requiring parity review include navigation/page visibility, Now/current-time behaviour, Agile/Solar APIs, PV model, Net Electricity Price, Cost Savings, PV settings and units, location/site naming, responsive layout, caching/persistence, accessibility and release requirements.

## Shared navigation contract

Logical pages are Octopus Agile Prices, Solar Forecast, PV Forecast, Net Electricity Price, Cost Savings, App Settings and User Guide. PV, Net and Save are hidden when **Solar PV panels installed** is off and return when it is on. Solar remains available. Wheel interaction must not trigger page navigation.

## Shared calculation contract

```text
PV energy = clipped loss-adjusted PV power × actual period duration
load energy = configured load kW × period hours
grid import = max(load energy - forecast PV, 0)
net price = (grid import × Agile price) / load energy
avoided grid import = min(forecast PV, load energy)
PV cost saving = avoided grid import × Agile price
```

Net and Cost Savings must agree on selected-period PV saving. Export income is not included. Negative Agile prices can create negative savings.

## Current-location contract

Current Location is opt-in. It must request platform location permission only in response to the user action, obtain a location fix, attempt a readable locality/town name, permit editing the display name independently of coordinates and avoid continuous tracking.

Apple uses Core Location and MapKit on the current iOS 26.5 target. Android uses Fused Location Provider and Android Geocoder.

## Responsive-layout contract

Avoid device-specific fixed offsets. Metric content and Now must not overlap. Navigation must remain usable on supported phone/tablet widths. Apple release testing includes small/standard/Max iPhones and iPad; Android release testing includes compact/normal/large phones and tablet/emulator.

## Build-status honesty

A committed implementation is not automatically a verified release. Do not claim Apple or Android build success unless that build has actually been run. Do not claim physical-device compatibility until the relevant device/emulator matrix has been tested.

## Android dependency policy

Prefer stable AndroidX/Compose releases and the Compose BOM rather than independently pinning Compose artifacts. Review Gradle/AGP/Kotlin/SDK versions during Android Studio sync rather than silently changing them without documentation.

## Source of truth

Runtime implementation is authoritative for actual behaviour. If implementation and documentation disagree, treat that as a defect and correct both.
