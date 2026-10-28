# Agile heating controller

The Synology container runs the effective-price API and a native half-hour heating
boost driver. The iPhone app edits policy and shows status; it does not need to
stay open. Automatic control is **disabled by default** for new installations.
The owner has approved and enabled the existing installation.

See the [complete service catalogue](SERVICES.md), [runnable Python walkthrough](../examples/README.md)
and [observed Homely API register](../docs/HOMELY-OBSERVED-CALLS.md).

## Behaviour

- Evaluate effective Agile-plus-forecast-PV prices once per half-hour, at :00/:30.
- Start at or below Heating on; retain permission until above Heating off.
- Both thresholds accept finite signed numbers. On=−5p/off=−1p means start at
  −5p or below, hold through −1p, and stop above −1p. Off must be >= on.
- Enable normal heating if necessary, then request a boost ending at the slot
  boundary. Homely keeps its own temperature targets; no temperature payload is sent.
- Renew once at the next boundary if policy still permits. Do not extend a lease
  in response to a forecast refresh inside its slot.
- When permission ends, cancel the matching owned boost and disable normal space
  heating. Expiry alone leaves normal heating enabled; it is not an off command.
- On a process start more than 15 seconds after the boundary, wait for the next
  boundary. An in-progress setup has a separate 60-second budget and retains the slot end.
- Missing/stale prices, a failed control check or a policy save remove permission
  for the rest of the slot. Recovery cannot replay a start inside that slot.
- A restart reconciles a saved operation before considering a new boost. It stops
  a still-matching owned boost and disables heating, then waits for a boundary.
- A changed mode, heating schedule, target/override or different timed boost causes
  a persistent manual-change hold. Matching owned boosts are cancelled, but manual
  targets/schedules/modes are not restored from an old snapshot. Save policy to
  release a hold; that also stops any existing owned boost before the next slot.

Temperature and sensor freshness do not determine price permission. Telemetry is
for the app's reported-state display. Existing hot-water settings/schedules are
excluded from the driver's comparisons and are never written.

## Price calculation and timing

```text
PV kW = array kWp × max(irradiance, 0)/1000 × (1 - losses/100)
PV kW = min(PV kW, inverter maximum), if configured
load kWh = electrical load kW × slot hours
PV kWh = PV kW × slot hours
grid kWh = max(load kWh - PV kWh, 0)
effective p/kWh = grid kWh × Agile import p/kWh / load kWh
```

The worker refreshes Agile and Open-Meteo data every 60 seconds after completion.
It requires contiguous published prices covering the current slot and every
needed UTC quarter-hour solar sample. An unpublished future tail is allowed;
missing current/interior data is not. Negative import rates remain negative, with
PV reducing the imported amount and therefore reducing the payment magnitude.
A complete London local day contains 46/48/50 distinct UTC half-hours across DST.

The control worker wakes at most five seconds after its preceding check, and
specifically at a boundary. Network requests have a ten-second timeout. A NAS/controller or API
outage can delay an off command: the server boost expires at its accepted end,
but normal heating can remain enabled until Homely becomes reachable. No local
software can guarantee physical shutdown during a cloud/control outage.

## Activation and private evidence

All of these must be present before the production transport can write:

1. `HEATING_LIVE_ENABLED=true`, set only after explicit user approval.
2. The existing approved Homely connection, with an explicit household and zone.
3. Private native-expiry evidence matching that profile/house/boost-zone identity.
4. No unresolved legacy recovery file.
5. The persistent app Automation switch is ON.

The default is `HEATING_LIVE_ENABLED=false`, and a missing automation switch file
means OFF. Saving price policy never arms automation. The app can switch ON only
after administrative activation and matching evidence; otherwise PUT ON returns
409. A persisted ON still cannot bypass the administrative gate.

The app's explicit OFF is a stop command as well as a persistent pause. It saves
OFF first, wakes the worker, cancels the selected timed boost and disables normal
heating. Its strictly scoped stop permission works even when automatic starts are
not activated; it cannot enable heating, start boosts or alter temperatures.
Shutdown stays pending until readback confirms it. After acknowledgement the
paused controller leaves later manual Homely use alone. Repeated OFF is a new
explicit stop request; a lost response must be reconciled with GET before retry.

Switch state lives in `/data/automation.json`. It survives app/container restarts
and is separate from price-policy revisions. A corrupt switch/ledger can be
repaired by an explicit authenticated OFF; invalid data is retained privately.
There is no endpoint granting the initial administrative activation.

The private marker defaults to `/data/native-expiry-proof.json` (override with
`HEATING_NATIVE_EXPIRY_PROOF_FILE`). It records version=1, a SHA-256 installation
identity, `native_expiry_records_verified=true`, and `slot_seconds=1800`. Create it
only from reviewed evidence, not a guessed capability flag. The approved
25 October pilot supplies this evidence for the configured installation. It
observed native expiry and exact API-record restoration for one half-hour boost;
it does not prove arbitrary durations or all outage cases.

Homely has no observed conditional-write or idempotency token. The driver compares
fresh state before writes, journals intent first, and yields on unexpected changes.
This cannot eliminate a simultaneous app-write race. Holds are conservative and
can also be caused by Homely itself changing heating strategy. Do not describe
this implementation as atomic ownership or guaranteed restoration of arbitrary
manual override state.

## Storage and deployment

The service uses `/data/policy.json`, the configured recovery-file path for the
process lock and legacy-journal detection, and a sibling `*.slot.json` ledger for
native operations, holds and previous control snapshots. Ledger writes are atomic,
flushed to disk and owner-only. Wrong-identity/corrupt records are retained and
reported; they are never silently discarded. Credentials remain in a separate
read-only private mount; they are not in the image, phone or API responses.

Use `compose.yml` and, when appropriate, `compose.observe.yml`. Preserve existing
NAS runtime environment, private mounts, reverse proxy, API key and policy volume
when upgrading. Do not replace a configured NAS Compose file with a generic one.
The image runs non-root, with a read-only root filesystem, private temporary
storage and an authenticated health check. Roll back an upgrade by restoring the
previous image tag and recreating only this service with its existing Compose file.

## Build and verify

```sh
./scripts/rebuild-controller.sh
# Optional: build, verify, then export for a NAS without a build toolchain
./scripts/rebuild-controller.sh /private/path/heating-controller.tar.gz
# Re-run verification against an existing image
./scripts/verify-controller.sh
```

See [rebuild, verification and operational checks](REBUILD.md) for prerequisites,
image names, archive transfer, deployment/restart behaviour, rollback, read-only
checks and where to find action logs. These scripts do not restart live services.
The current suite has 178 backend tests and 62 narrated offline checks. Cloud and
heating responses are simulated; an isolated pass is not proof of live operation.
The retained legacy temperature/lease model is a regression fixture; production
constructs `SlotSupervisor`.

## Approved live controller test

The bounded 25 October production-driver cycle confirmed a real price-policy
start, cancellation/disable after restoring the saved policy, and persisted app
OFF across restart. Its original short-wait harness timed out; reviewed response
ordering verifies the controller's completed stop. See the [test report](SUPERVISED-TEST.md)
for exact scope, timing and the follow-up immediate-OFF/status fixes. The owner subsequently approved ongoing use and enabled the live gate and app
switch. New installations still default OFF.

## Weekly heating log

`GET /v1/history` returns the current Monday–Sunday week in Europe/London.
`GET /v1/history?week=2026-10-19` selects a Monday by date. Both require the
controller bearer key. Invalid, duplicate, unknown, future or out-of-retention
week queries return 400; unavailable history storage returns 503.

The response contains `week_start`, exclusive `week_end`, `current_week`,
`oldest_week`, `timezone`, `recording_started_at`, `retention_days`, `events`,
`truncated`, `pending_events` and `warning`. Events are newest first, with `id`,
UTC `at`, `state` (on/off), `reason`, signed `price_p`, `on_price_p`,
`off_price_p`, and `source` (automation or supervised_test). Missing price
context is null. Weeks follow London calendar time, including 167/169-hour DST
weeks. Responses are capped at 2,000 rows with an explicit truncation flag.

The private SQLite database `/data/heating-history.sqlite3` retains 366 days.
Confirmed enable/disable actions enter the durable control-ledger outbox before
database insertion; retries deduplicate by event ID. A history-storage error
reports pending events without replaying heating commands. Boost renewal does
not add a second ON. Manual Homely changes and physical compressor cycles are
not recorded as automation actions. There is no invented history before logging
began. Back up the persistent data volume, including SQLite WAL files, using a
consistent snapshot or while the container is stopped.

Boundary attempts must begin within 15 seconds. An already-started setup may
finish within 60 seconds, keeping the original slot end. Exceeding that budget
stops heating and records `setup_timeout`; this is distinct from unavailable
price data. Historical entries recorded before this distinction retain their
original reason.

## Correlated sessions and estimated cost

History also returns `sessions`, newest first, for sessions overlapping the selected
London week. Each has `id`, `correlation` (`recorded_session_id` or
`legacy_sequence`), `on_at`, nullable `off_at`, `duration_seconds`, `on_price_p`,
`off_price_p`, `off_reason`, `source`, `intervals`, `estimated_energy_kwh`,
`estimated_cost_gbp` and `cost_status`. Existing `events` remain unchanged.

New actions carry a persistent session ID across allowed slot renewals and restart
reconciliation. An OFF is paired only with that ID; an external/manual change
leaves its end unconfirmed. Older alternating ON/OFF records are paired by order,
marked `legacy_sequence`, with no invented rate/load history. Unmatched OFF actions
remain visible in the individual action list. A session crossing a week boundary
appears in each overlapping week with the same ID and whole-session cost; do not
sum these duplicate appearances as separate sessions. Retention can remove an old
ON; no replacement is fabricated.

Each cost interval saves UTC `start`/`end`, `agile_price_p`,
`effective_price_p` and configured electrical `load_kw` at the time. Rates are
recorded on confirmed enable/start, slot renewal and stop, using the first saved
observation for each slot. Subsequent policy/load edits do not rewrite old costs.
The estimate integrates only elapsed ON-to-OFF overlap with each half-hour:

`estimated kWh = load_kw × elapsed hours`

`estimated GBP = sum(estimated kWh × effective_price_p / 100)`

The effective rate includes the existing forecast-PV model. The raw Agile unit
rate is shown separately; the OFF rate is context, not the rate for the whole
session. A 3 kW, 30-minute session at an effective −5p/kWh estimates 1.5 kWh and
−£0.075 (payment). These are **estimates**, not measured heat-pump consumption or
supplier billing; they omit standing charges. Configured load assumes constant
electrical draw throughout the confirmed enabled interval, including setup.

`cost_status=estimated` requires a confirmed OFF and complete rate/load coverage.
`end_unconfirmed` or `missing_rate_data` returns null total/energy rather than a
partial number presented as a total. Existing records retain unit prices where
known but cannot acquire historical consumption assumptions retroactively.
Intervals are stored separately from the legacy action rows; the database gets
an additive migration. Keep a consistent pre-upgrade backup; older images can
still read ON/OFF rows, but do not calculate session costs. The durable outbox
retries rates without replaying heating commands.

Verification now includes 178 backend tests and 62 offline walkthrough checks,
including signed estimates, rate/load changes, missing coverage, legacy migration,
cross-week/DST duration, stable session IDs and manual interruptions.


See [26 October bug audit](../docs/BUG-AUDIT-2026-10-26.md) for exclusive week boundaries, retention, consistent read transactions and session truncation fixes.


## Scheduled-temperature investigation (27 October)

A controlled 16→22→16°C schedule-target edit was captured and restored with
heating disabled. The [preparation report](SCHEDULE-TARGET-PREPARATION.md) records
the observed API, offline planner and tests, and remaining requirements. This is
not a new public HTTP service or an enabled 22°C mode. The deployed price-only
driver and production write allowlist are unchanged.


27 October follow-up: adding/removing one one-hour heating period was captured
using the same whole-schedule setter and exactly restored. Offline planning now
has 200 backend checks plus the 62-check service walkthrough; the deployed driver
and six public HTTP services are unchanged. See the observed register and
`controller/SCHEDULE-TARGET-PREPARATION.md` for the remaining live-control limits.


[Synology network setup](NETWORKING.md) documents DSM HTTPS routing, certificate assignment, TCP 8451 forwarding, backend ports and end-to-end verification.


[Archived supervised 22°C test](SUPERVISED-22C-TEST.md) records the prepared diagnostic, cancelled before heating writes after the owner confirmed temperature-independent price control. Final read-only checks confirmed restoration. It is not the next operating step or an enabled temperature mode.
