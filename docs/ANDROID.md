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

The Android project has the core pricing/solar screens. Heating/controller parity
is outstanding and is required; see [Android heating requirements](ANDROID-HEATING-REQUIREMENTS.md). Platform packaging, Play Store signing/release metadata and device-specific polish remain separate release tasks and must not be described as completed until tested.

## Heating controller parity

The Apple app includes a Heating page for the authenticated Synology controller,
including its approved automatic mode. Android does not include this feature yet; existing Android pages are unchanged.

The latest iOS update adds supervisor recovery/freshness and optional reported
Homely observations, plus reconnecting with its saved Keychain key. These remain
iOS-only; no equivalent Android screen or controller client is implemented.

The iOS Heating policy now uses whole-number dropdowns (1–20 p/kWh and
10–25°C) while preserving existing out-of-range values. This remains iOS-only.

Short policy labels and blue informational/red error messages apply only to the iOS Heating page.

The Agile heating heading and separate red/green policy and reported-state lines are iOS-only.

The controller address/key settings and test/reload action relocation are iOS-only.

The iOS Heating page is now price-only; its removed temperature selectors do not affect Android.

The iOS heating controls now support signed −20…20p values, zero, and both controller modes. This heating-client update is iOS-only; Android parity is not claimed.

The iOS Heating page also has a persistent Automation switch with OFF/shutdown-pending display. ON requires prior controller activation. This is not implemented on Android.

## Weekly heating log — iOS

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
Android does not yet provide Heating or this log.

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
This feature is iOS only; Android still has no Heating page.
