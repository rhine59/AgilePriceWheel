# Scheduled-target preparation — 27 October 2026

## Verified phone capture

With space heating disabled and no timed boost, the user approved a brief change
of one existing Tuesday target from 16°C to 22°C and back. Two
`setHeatingSchedule` requests were accepted at 08:47:48.019 and 08:48:10.926 UTC
(22.907 seconds apart). Each sent the complete seven-entry schedule; the only
payload difference was that entry's temperature. Both returned HTTP 200 / JSON
null. Final independent readback exactly matched the preflight settings, heating
schedules and boost records. The existing hold was not cleared.

See docs/HOMELY-OBSERVED-CALLS.md for the complete observed API contract, data
units, request/response fields and limitations. No real identifiers or raw HAR
files are included in GitHub.

## Offline implementation

`controller/schedule_target.py` supplies a pure planner for changing an existing
identified entry and generating its restoration payload. It preserves the full
selected schedule, requires heating disabled, refuses missing/duplicate IDs and
invalid targets, requires readback to establish the changed state, treats an
already-restored state as a no-op, and refuses to overwrite an external heating
edit. Hot-water fields are never included. The code makes no HTTP call and is
not imported by the production driver; `setHeatingSchedule` is still rejected
by the production write allowlist.

Run `python3 examples/temperature_target_demo.py` for a synthetic narrated
rehearsal. `scripts/rebuild-controller.sh` builds/tests a candidate; it does not
restart or deploy the NAS. The period-planning candidate passed 200 backend tests and the
existing 62-check service walkthrough. The separate temperature example was
also executed offline with networking disabled.

## What remains before a live 22°C mode

- A scheduled target is not an independently writable timed-boost target. The
  earlier captured boost returned 20°C; sending a scheduled target of 22°C has
  not been tested with heating enabled or a timed boost.
- Period creation/removal is now captured (see below), but the identifier
  generation contract, live crash recovery and a general expiring temperature
  override remain unverified. No overnight heating lifecycle has been tested.
- A physical 22°C ceiling is not established. The candidate room value matched
  the phone but was around eight minutes old in one sample; update cadence,
  zone mapping, stale-data response and control latency need review.
- Live crash recovery, durable schedule ownership/restore intent, uncertain
  write reconciliation and expiry still need an integrated lifecycle. Homely
  exposes no observed conditional-write token, so fresh comparisons are not
  atomic ownership.

No live 22°C mode is deployed. The on/off prices have not been changed from
7p/8p and the manual-change hold has not been cleared. Future target/heat tests
need a specific approval first. Android heating parity remains required.

## Subsequent period capture and offline support

At 17:14:26.032 UTC the app submitted the complete schedule with one extra Tuesday
16:00–17:00, 22°C entry. At 17:14:33.610 it submitted the exact original schedule,
removing only the new period. Both returned HTTP 200 / JSON null, 7.578 seconds
apart. Independent readback confirmed original settings/schedules/boost records,
heating disabled, no active boost and the existing hold intact.

The editor required at least one hour. A 30-minute timed boost remains a different
operation. API-level minimum-period enforcement was not tested. The new entry's
ID was an opaque 10-character string, not an established UUID or server allocation
contract. The helper takes an explicit unused synthetic ID; it does not generate
live IDs or send a write.

`plan_period` now rehearses an adjacent non-overlapping period, full-schedule
preservation, unchanged other days, exact restoration, no-op after restoration
and refusal when an external edit occurs. It rejects invalid day/time/target or
reused identities and conservatively enforces the reported editor minimum. UTC
slot-to-local-time/DST conversion remains outside this planner. The candidate
passed 200 backend tests and the existing 62-check offline service walkthrough;
the separate narrated target/period example was also executed without network.
The NAS/image and both installed apps remain unchanged by this offline work.
