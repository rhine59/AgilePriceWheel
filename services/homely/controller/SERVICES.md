# homely-heating service catalogue

Updated 27 October 2026. This describes the native price-only driver and current
HTTP API. New installations default to **plan-only** with automation OFF. The owner has
now approved and enabled the existing installation.
See [setup and behaviour](README.md), the [Homely API register](../docs/HOMELY-OBSERVED-CALLS.md)
and the [Python walkthrough](../examples/README.md).

Owner clarification, 27 October 2026: heating should remain enabled for each
qualifying half-hour price slot, using existing Homely temperature settings;
there is no requested room-temperature target or ceiling in the price policy.
The native boost ends at the slot boundary and is renewed for a qualifying next
slot. Homely's thermostat can still stop actual heat production. Explicit OFF,
manual intervention, changed policy, unavailable price data or recovery can end
an interval early; this is not a guarantee of continuous compressor operation.

## Service inventory

| Service | Behaviour |
| --- | --- |
| Status API | Current forecast, latched half-hour policy permission, activation, telemetry and recovery state |
| Policy API | Signed on/off prices and tariff/PV configuration, with persisted revisions |
| Weekly history API | Confirmed automation ON/OFF actions, prices and reasons by London calendar week |
| Automation switch API | Persistent ON/OFF; explicit OFF requests confirmed heating shutdown |
| Agile pricing | VAT-inclusive import prices covering the current London day/slot; contiguous published future prefix allowed |
| Solar/effective prices | Open-Meteo UTC quarter-hours and the app's load/PV/loss/inverter model |
| Slot policy | One decision at :00/:30; separate on/off thresholds and hysteresis; temperature-independent |
| Native boost driver | Captured enable/start/cancel/disable calls, available only after explicit activation and matching evidence |
| Observation | Reported heating state/room data for display; does not gate price policy |
| Recovery/manual hold | Durable write intent, reconciliation before another start, conservative preservation of external changes |
| Storage/process exclusion | Atomic private policy/ledger files and one control process per data directory |
| Container operations | Non-root, read-only filesystem, persistent volume, restart policy, authenticated health check |

## HTTP API

Container port 8080 is published on host loopback port 8086 by the base Compose
file. The NAS reverse proxy supplies HTTPS; keep the Python HTTP port private.
Every implemented route requires `Authorization: Bearer <controller-key>`.
The startup key must contain at least 32 characters. Responses are JSON with
`Cache-Control: no-store`; handler logging excludes policy, credentials and tokens.

| Method/path | Request | Response/effect |
| --- | --- | --- |
| `GET /v1/status` | None | Status below. No Homely write; GET does not start a boost |
| `GET /v1/history[?week=YYYY-MM-DD]` | Optional Monday date | Weekly confirmed automation actions; see below |
| `GET /v1/policy` | None | `{revision, policy}` |
| `PUT /v1/policy` | Complete `{revision, policy}` | Atomically saves the next revision, invalidates forecasts and wakes workers; never activates control |
| `GET /v1/automation` | None | Saved enabled/revision, can_enable, shutdown_pending, phase and error |
| `PUT /v1/automation` | `{"enabled": true}` or `{"enabled": false}` | Persists the switch and wakes control; ON requires prior activation, OFF requests shutdown |

Paths are exact, without trailing slashes. Only history accepts the documented week query. There is no administrative activation,
raw Homely command, unauthenticated health, PATCH, WebSocket or browser-UI endpoint.
A policy save on an already active controller stops its owned boost, releases a
manual hold and waits for a new half-hour decision. The same action in plan-only
mode cannot change heating controls.

Errors: 400 malformed/invalid policy, 401 incorrect key, 404 unknown GET/PUT route,
409 stale revision, 500 failed save. Unsupported verbs use the server's 501
response. PUT requires Content-Length of 1–16,384 bytes; body timeout is ten
seconds. Reload after an uncertain save instead of blindly retrying it. Source
failures are reported inside status, rather than making HTTP health fail.

## Automation switch

The saved switch defaults OFF. PUT accepts exactly one JSON boolean `enabled`;
invalid bodies return 400. ON returns 409 unless administrative activation,
matching evidence and settled recovery permit it. The response's `enabled` is
saved intent; it is not proof of physical heating. `shutdown_pending` remains true
until the worker acknowledges the OFF revision. API authentication also applies
to these routes.

OFF saves intent before commands, then cancels the selected timed boost and
sets normal heating disabled. Explicit OFF has stop-only permission even when
automatic starts are unactivated. It cannot start/enable heating or write target
values. After acknowledged shutdown, later manual Homely use is left alone.
ON takes effect at a new boundary, not by replaying a mid-slot start.

Explicit OFF is persisted without waiting for the current network/control tick;
its response can therefore acknowledge intent promptly while shutdown is pending.
The worker rechecks it around enable/start operations and reconciles in-flight work.

Switch revisions are separate from price-policy revisions. Commands are
serialized, last accepted command wins, and every accepted command increments
its revision. A lost PUT response is reconciled with GET, never blindly replayed.
A repeated OFF is a new explicit shutdown request. Corrupt saved switch/ledger
state can be repaired by OFF, with invalid data retained in a private backup.

## Policy document

```json
{
  "revision": 0,
  "policy": {
    "on_price_p": -5,
    "off_price_p": -1,
    "target_c": 21,
    "limit_c": 22,
    "product": "",
    "tariff": "",
    "latitude": 54,
    "longitude": -2,
    "array_kwp": 5,
    "loss_percent": 15,
    "inverter_kw": 5,
    "load_kw": 3
  }
}
```

These are illustrative values, not a configured installation. GET/PUT require
exactly these document/policy fields. Numeric values must be finite JSON numbers,
not booleans. Revision is an integer matching the latest GET; successful saves
increment it, including identical-policy saves. Concurrent saves use 409.

| Field | Units and validation |
| --- | --- |
| on_price_p | Signed p/kWh; start at or below this |
| off_price_p | Signed p/kWh; stop above this; must be >= on price |
| target_c / limit_c | Legacy compatibility fields, preserved by the app; require 5 <= target <= limit <=25. Not used by the native price-only driver and never sent as temperature settings |
| product / tariff | Both empty for unconfigured, otherwise matching Agile import product and E-1R product/region tariff |
| latitude / longitude | Degrees; −90…90 / −180…180 |
| array_kwp | 0…1000 kWp |
| loss_percent | 0…100 percent |
| inverter_kw | 0…1000 electrical kW; zero means no clipping |
| load_kw | 0.01…1000 expected electrical kW |

Negative rates mean payment for grid import. On=−5/off=−1 starts at −5 or lower,
holds through −1 while already permitted, and stops at 0. Zero is supported.
The backend does not clamp prices to the iPhone menu (−20…+20p); existing values
outside that menu remain Current. Factory on/off defaults are both 0p.

## Status document

Top-level fields:

- `control_enabled`: administrative readiness AND saved Automation ON, not evidence of physical heating.
- `mode`: `plan_only` when unactivated/blocked; `automatic` when the write gate is open.
- `revision`, `price_basis=agile_plus_forecast_pv`, `stale`, `updated_at`, `error`, `error_stage`.
- `price_requests_heat`: the worker's latched permission, masked OFF if its revision/slot is no longer current or sources are unavailable; distinct from actual heating.
- `current`: start/end, Agile/effective price, forecast PV/grid kWh; null if unavailable.
- `slots`: published calculated intervals; `price_day_complete` and `price_coverage_end` distinguish a usable prefix from a complete local day.
- `slot_decision`: action (`boost`/`off`), phase, price_allowed, decision_price_p,
  slot_start/end and policy_revision. May be unavailable before the first control check.
- `automation`: the saved switch document and shutdown state; `heating_control` and a human-readable `message`.

`error_stage` identifies configuration, Agile prices, solar forecast or calculation
failure. A snapshot older than 15 minutes, from the future or without a current
slot is unusable. A failed refresh clears it immediately.

`heating_control` contains strategy=`slot_boost`, control_enabled,
native_expiry_verified, recovery_pending, last_checked_at, observation, error,
blockers, slot_decision and, after activated checks, manual_hold. Its phase is:

| Phase | Meaning |
| --- | --- |
| disabled | Automatic activation off; explicit user OFF is separately permitted |
| automation_off | App switch OFF; shutdown acknowledged or no heating operation owed |
| blocked | Activation requested but required matching evidence/configuration is missing |
| boost_active | Matching native boost confirmed |
| heating_off | Normal heating disabled and no timed boost left to reconcile |
| waiting_for_boundary | Too late to start this half-hour |
| manual_change_hold | External heating change detected; persisted hold |
| recovery_required / unavailable | Control outcome/data could not be established; inspect retained state |

Recovery can be pending while activation is off. Automatic paths do not bypass
that restriction; an explicit authenticated app OFF has separate stop-only permission. When active, an error retains its ledger, removes slot permission
and reconciles before another start. `control_enabled=true` can coexist with a
hold/error: it means configured activation, not successful heat delivery.

Observation fields are disabled, reported_heating_on, room_c, observed_at,
sensor_age_s, sensor_candidate_fresh and sensor_contract_verified. An optional
observation_error describes unavailable display telemetry. The app requires a
recent successful control poll and marks older sensor values as last reported.
Temperature/freshness never changes native price-only permission. Reported
heating is not a meter or proof of compressor operation.

## Background work and failure handling

The pricing worker refreshes every 60 seconds after completion. The control
worker waits at most five seconds after a check, or wakes at the next boundary or
policy/source change. It operates independently of the phone. Boundary attempts
must begin within the first 15 seconds; an in-progress setup has at most 60
seconds, while retaining the original slot end.
DST uses UTC instants: London spring/autumn days retain 46/50 separate slots.

A confirmed native boost end bounds the boost; it does not disable normal heating.
The driver explicitly disables normal heating when permission ends. NAS/controller or API outages
can prevent immediate shutdown, so a cloud-dependent controller cannot guarantee
physical off during an outage. It never blindly replays a start. Readback is
required before reconciling/retrying a stop. A hold survives restarts and policy
save releases it. No full old temperature/schedule snapshot is replayed.

No observed Homely compare-and-swap or idempotency token exists. Fresh comparison
and a process lock cannot eliminate a simultaneous official-app write race. The
hold mechanism is conservative and can also detect automatic Homely strategy
changes. Other household/zone combinations require their own reviewed evidence.

## Storage, settings and Docker

| Setting/file | Purpose |
| --- | --- |
| HEATING_API_TOKEN | Shared HTTPS API bearer key; never returned |
| HEATING_POLICY_FILE | Default /data/policy.json |
| HEATING_RECOVERY_FILE | Default /data/heating-recovery.json; legacy recovery detection and shared process-lock name |
| sibling automation.json | Persistent switch enabled/revision, default OFF |
| sibling *.slot.json | Native ledger: identity, lease intent, hold, revision and previous control snapshot |
| HEATING_NATIVE_EXPIRY_PROOF_FILE | Default sibling native-expiry-proof.json; private installation-specific reviewed evidence |
| HEATING_API_TOKEN | Required bearer key, at least 32 characters; keep private |
| HEATING_LIVE_ENABLED | Default false. True requires explicit user approval plus matching evidence |
| HEATING_HOMELY_ENV_FILE / PROFILE | Approved login secret mount and profile |
| HEATING_HOUSE_ID / SENSOR_ZONE_ID / BOOST_ZONE_ID | Explicit verified installation/telemetry/boost selection |

The identity fingerprint binds profile, house and boost zone. Files are private,
atomic and flushed; corrupt/wrong-identity ledgers are retained. An unresolved old
recovery file blocks the new write gate. No credentials are stored in status,
policy, image or phone. `compose.observe.yml` is the optional secret-mount overlay;
preserve an existing NAS runtime Compose file when upgrading.

The base container targets amd64, runs UID 10001, uses a persistent /data volume,
read-only root filesystem, /tmp temporary storage, no added capabilities and
restart unless-stopped. Its health probe is an authenticated GET status; HTTP
health is not proof of fresh prices, control reachability or physical operation.

The container does not run or change the separate Sunamp/hot-water job, send a
hot-water setter, control batteries/EVs or host the iOS app. The six method/path combinations
above are the full public service surface. The older temperature/lease controller is a
retained offline regression model, not the production actuator.

## Verification

Run [`scripts/rebuild-controller.sh`](../scripts/rebuild-controller.sh) to build
and execute all verification, or `scripts/verify-controller.sh` for an existing
image. [Rebuild guide](REBUILD.md) explains isolated and live read-only checks.
The suite currently includes 178 backend tests plus 62 narrated offline checks,
covering all six public method/path combinations. No real equipment is exercised.
The iOS weekly log has 13 focused model/navigation checks.

Reviewed live evidence and its limits are recorded in
[SUPERVISED-TEST.md](SUPERVISED-TEST.md). Ongoing activation and Automation have
subsequently been enabled by the owner. Six real overnight action records exposed
a slow setup exceeding the old allowance; setup now has a bounded 60-second
completion allowance. A full unattended cycle after this correction remains
unobserved. Neither HTTP health nor a passing mock suite proves physical heating.

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

## Finding action logs and diagnostics

In iOS: **Heating → Weekly heating log**. Select a previous week using the arrows;
use Reload or pull to refresh. For example, actions from Sunday 25 October are
in the week beginning 19 October, not the new Monday 26 October week.

The authenticated history endpoint is the action log. Container stdout/stderr
is operational diagnostics and does not duplicate every heating action. Use
`docker logs --timestamps --tail 100 homely-heating` for diagnostics and
`docker inspect homely-heating` locally for container health/exit information;
inspect output can include secrets and must not be published. The history DB is
inside the persistent `heating-policy` volume at `/data/heating-history.sqlite3`,
not on the container's disposable root filesystem. See the rebuild guide for a
read-only API example without putting the bearer key in shell arguments.

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


[Proposed supervised 22°C test](SUPERVISED-22C-TEST.md) documents the explicit approval, fresh-reading preconditions, immediate stop/60-second fallback and final restoration checks. It remains separate from the production worker and has not enabled a 22°C mode.
