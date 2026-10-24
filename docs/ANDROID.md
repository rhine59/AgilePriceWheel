# Android implementation and parity

The Android implementation lives under `android/` and is native Kotlin + Jetpack Compose.

## Parity contract

User-facing calculation semantics should match iOS for Agile Prices, Solar Forecast, PV Forecast, Net Electricity Price and Cost Savings. Navigation should expose seven destinations with PV enabled and four with PV disabled. The same Now/current-period rule applies: `validFrom <= now < validTo`.

Android uses platform-appropriate APIs rather than copying Apple APIs: Jetpack Compose for UI, Fused Location Provider for a requested current-location fix, and Android Geocoder for a readable editable site name.

## Responsive layout

Compose content is constrained and centred on wide displays and uses available width on phones. Bottom navigation is state-derived and works on phones/tablets. Release testing must include compact and large phones plus a tablet/emulator.

## Maintenance rule

Any iOS change to calculations, page visibility, navigation, settings, location behaviour, Now behaviour, units, API semantics or user documentation must be assessed for Android parity in the same development cycle. Update `android/README.md`, this document and the root documentation when Android behaviour changes.

## Known implementation scope

The Android project now contains the complete parity path for the current core feature set. Platform packaging, Play Store signing/release metadata and device-specific polish remain separate release tasks and must not be described as completed until tested.

## Heating controller parity

The Apple app now includes a Heating page for an authenticated, plan-only Synology controller. Android does not include this feature yet; existing Android pages are unchanged.
