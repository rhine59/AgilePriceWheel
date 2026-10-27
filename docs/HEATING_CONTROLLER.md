# Heating controller

## Agile heating (iOS only)

The **Heating** tab opens **Agile heating**. Connection details live in
**App Settings → Agile heating connection**: save the HTTPS address and key,
then use **Test connection / reload controller policy** on Heating. The key stays
in Keychain. Updating the app preserves existing settings and connection.

Two separate coloured lines show **Heating policy** (price permission) and
**Heating state** (Homely's report): ON red, OFF green, unavailable when data is
missing or stale. Older sensor data is marked last reported. Neither line proves
physical compressor operation. Activation and recovery/manual-hold status are
shown separately. The app accepts both plan-only and automatic controller modes.

**Heating on** and **Heating off** offer −20 through +20 p/kWh, including zero.
Existing values outside the menu remain Current. Both values can be negative;
negative rates mean payment for grid-imported electricity. Off must be >= on.
For example, on=−5p/off=−1p starts at −5p or below, holds through −1p once
permitted, and stops above −1p. Homely retains its own temperature targets; the
app has no target/ceiling controls. Information is blue and errors are red.

The **Automation** switch is the persistent policy on/off control. OFF requests
boost cancellation and heating disable, then leaves later manual Homely use alone.
The app shows **shutdown pending** until confirmed. ON requires prior controller
activation and confirmation in the app, then waits for a new half-hour decision.
Switch state survives app/NAS restarts. A failed request is reloaded, not blindly
repeated. The switch never changes your saved price thresholds.

The NAS evaluates effective Agile-plus-forecast-PV prices at :00 and :30. Each
boost ends at the next slot boundary. It explicitly disables normal heating when
permission ends; native boost expiry alone is not an off command. A forecast
refresh inside the slot cannot renew a boost. A mid-slot restart or recovered
failure waits for the next boundary. API outages can delay an off command.

Copy this app's tariff/site/PV settings into the draft only when desired, then
review and confirm Save policy. Saving never changes activation. If already
active, it stops the current owned boost, releases a manual-change hold and
applies the policy from the next half-hour. A hold preserves external Homely
changes; there is no observed atomic ownership token, so simultaneous app writes
cannot be fully excluded. Temperature and sensor freshness do not gate the policy.

The controller runs without the iPhone app. Status polls every 30 seconds while
Heating is open. Administrative activation and Automation are now enabled with
the owner's approval. The app cannot grant initial administrative activation.

Verification: 172 backend checks and 14 focused iOS checks cover policy, history,
DST, failures and navigation. Real overnight automation entries are available.

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


26 October bug audit: unavailable prices now stay labelled unavailable. Sessions
ending exactly at Monday midnight stay in the preceding week. An unconfirmed end
is not assumed to continue indefinitely; later weeks require recorded activity.
See [audit](BUG-AUDIT-2026-10-26.md) for checks and limits.


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
