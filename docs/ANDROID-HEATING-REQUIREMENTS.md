# Required Android heating app

Updated: 27 October 2026. Android is a required deliverable, not optional.
The native Kotlin/Jetpack Compose app under `android/` now implements the
existing controller features; both apps use the same NAS service. The Android source and reproducible build/test scripts are in this repository.

## Required parity

- Agile heating page with separate Heating policy and Heating state, ON red and
  OFF green; display stale/unknown data, recovery and manual holds honestly.
- Settings for HTTPS controller address and securely stored bearer key; preserve
  settings on update, refuse insecure URLs/redirects and never log secrets.
- Test connection / reload policy, signed on/off price selectors including zero
  and negative numbers, validation and revision-aware saves preserving other fields.
- Persistent Automation ON/OFF; explicit enable confirmation, pending shutdown,
  reconcile uncertain requests, never grant administrative activation from the app.
- Weekly London Monday–Sunday action log, navigation/reload, GMT/BST times,
  ON/OFF correlation, duration, Agile/effective half-hour rates, estimated kWh
  and costs/payment using the saved configured load. Null means unavailable.
- Preserve iOS cost semantics: no retrospective load guesses, no meter claims,
  no double counting sessions repeated across weeks, manual changes never invent OFF.
- Share the existing six HTTP services in `Homely/controller/SERVICES.md`; no new
  Homely credentials/control transport belongs on the phone. Controller keeps running
  independently of both apps. No temperature selectors for price-only automation.

## Delivery status — 27 October 2026

The Kotlin controller client, secure connection storage, Heating page, signed
price controls, Automation switch and weekly session/action log are implemented.
The exact tests, installable APK and emulator layout evidence are recorded in
[verification](ANDROID-HEATING-VERIFICATION.md). No Play Store publication or
physical-device installation is claimed. The prepared 22°C diagnostic was
cancelled before heating writes; temperature-independent price control is the
owner's requirement. Existing Homely targets remain in charge of temperature.
