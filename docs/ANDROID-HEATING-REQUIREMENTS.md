# Required Android heating app

Checkpoint: 26 October 2026. Android is a required deliverable, not optional.
The repository already has a native Kotlin/Jetpack Compose app under `android/`;
extend it to match the deployed iOS heating feature rather than start a separate
controller. No Android heating APK has yet been built or installed.

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

## Acceptance before calling Android delivered

Build an installable APK, verify controller JSON compatibility and key storage,
exercise signed policy/automation/history against fake services, test auth/network
failures and DST/cross-week estimates, and check compact/large phone plus tablet
layouts. Install on an available Android device/emulator. Document build/signing
and update root guide, Android README and parity guide. Play Store release is
a separate task and must not be claimed complete without evidence. Live heating
tests still require explicit approval; use offline/read-only checks by default.


27 October investigation: a scheduled 16→22→16°C target edit was captured with
heating disabled, restored and documented in Homely's
`controller/SCHEDULE-TARGET-PREPARATION.md`. An offline planner now rehearses
restoration and external-edit refusal. Neither iOS nor Android should advertise
an enabled 22°C boost/physical ceiling: its live lifecycle and temperature-control
contract remain unverified. Existing price-only app controls are unchanged.


Follow-up capture verified creating/removing a one-hour scheduled period while
heating stayed disabled, with exact final restoration. Offline period planning
is tested in the Homely repository. This does not establish a 22°C timed boost,
a physical ceiling or a new app/controller mode. Keep Android/iOS parity claims
limited to features actually implemented and verified.
