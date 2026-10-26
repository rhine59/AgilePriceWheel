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

Verification: 159 backend checks and 13 focused iOS checks cover policy, history,
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
