# Free/negative-price space heating

## Status (24 October 2026)

Prepared at the user's request with **live heating disabled**. `heating_boost.py`
provides a read-only Agile price planner and an offline-tested recovery controller.
It does not contain a Homely heating write adapter, a live temperature reader or
an unattended worker. `--live` always fails before login. Setting
`HEATING_BOOST_ENABLED=true` cannot bypass that gate.

The production `homely.py`, Sunamp/DHW price selection, solar calculation, schedule
writes, email reports and LaunchAgent are unchanged. The new planner does not
send emails or write heating, hot-water, summer-mode or installation settings.

## Verified capabilities and limits

The existing Mac checkout is `/Users/richardhine/scripts/Homely`, backed by
`rhine59/Homely` on GitHub. The starting production commit is `e24f201`.
The prior conversation contained no additional technical details or captures.

A read-only inspection used the existing OAuth flow and ONLY `userInfo`,
`getUser`, `getSettings`, `getAllSchedules` customer operations. No control writes
were made. Response **structure**, rather than personal identifiers or values,
was inspected. The selected installation exposed:

- `getSettings`: timezone, zone count, summer/hot-water-only modes, DHW settings;
- `getAllSchedules`: `heating` schedules with temperature/start/end/weekday/id;
- `temporary` entries with start/end/temperature/min/max;
- existing `hotwater` schedules.

These observations prove that heating schedules and temporary entries can be
READ. They do not establish write methods, timestamp units, zone addressing,
server-side expiry semantics, ownership handling or a fresh room sensor API.
No guessed heating operation was sent to Homely. Older retained scripts use
`setSettings` as a pseudo-read; do not use those for capability discovery.

Homely Energy's official [boost documentation](https://help.homelyenergy.com/knowledge/how-do-i-use-in-app-boosts-and-how-do-i-check-my-heating-and-hot-water-is-on)
says the app's heating boost runs at the installer's highest set temperature for
up to 90 minutes. This must not be equated with a bounded room-temperature
setpoint. Its [temperature explanation](https://help.homelyenergy.com/knowledge/why-is-my-home-warmer-than-my-set-temperature)
also says app temperatures are minimums, not precise upper cutoffs. A configured
room limit therefore cannot guarantee no thermal overshoot. API/polling delays
and stored heat also matter. The controller restores prior controls at or above
the configured target or limit; it cannot cool a room or promise a physical
temperature ceiling.

Search results for the Norwegian Homely alarm API describe a different product
and were not used to infer heat-pump controls.

## Configuration and read-only use

All settings use the existing `PROFILE.KEY`, shared `KEY`, default precedence.
Credentials stay in the ignored local `homely.env`, never in Git.

| Key | Default | Meaning |
| --- | --- | --- |
| HEATING_BOOST_ENABLED | false | Offline controller permission only; live remains unavailable |
| HEATING_ON_PRICE_P | 0 | Start at or below this raw import price, p/kWh including VAT |
| HEATING_OFF_PRICE_P | Same as on price | Restore prior heating above this price; must be >= on price |
| HEATING_TARGET_C | 21 | Requested room target, 5..safety limit |
| HEATING_MAX_ROOM_C | 22 | Stop/revert threshold, maximum configurable 25 C |
| HEATING_SENSOR_MAX_AGE_S | 120 | Freshness limit, 1..300 seconds |

With the same Python environment as the DHW scheduler:

```sh
python heating_boost.py --env-file /Users/richardhine/scripts/Homely/homely.env --profile Richard
python heating_boost.py --env-file /Users/richardhine/scripts/Homely/homely.env --profile Richard --date 2026-10-25
python -m unittest discover -s tests -v
```

Choose a profile actually configured locally. The default date is today in the
installation timezone. Output shows candidate half-hours, target and safety
limit. Temperature eligibility is explicitly unknown. A candidate is not a
claim that the heating can or should be switched on.

This reuses the production Octopus fetcher (pagination, retries, complete day
validation), then rejects non-finite prices. It uses **raw import price**, never
solar-adjusted prices, export rates or standing charges. The on threshold defaults to `<= 0`, which includes
both exactly free and negative rates. Missing/duplicate/overlapping slots fail
rather than creating a partial plan. UTC ordering preserves all 46/48/50 slots
across BST changes; displayed ISO timestamps include offsets to distinguish the
repeated autumn hour. No recurring weekday schedule is rewritten.

## Offline controller and restoration design

`Controller` accepts a `HeatingAdapter` supplied by tests. There is no production
implementation. Callers must validate a complete price day before passing the
current validated slot (including prices in the hold band); any price-fetch/validation failure must pass `None`.

Each tick serializes on a filesystem lock. It requires a valid current half-hour,
price permission, enabled policy and a finite, recent, non-future temperature below the safety
limit. It refuses an adapter without verified native automatic expiry. An
individual lease ends at the current slot's UTC end; renewals require fresh
checks, so a contiguous cheap period is not an unlimited boost.

Before any write, an atomic, permission-restricted, fsynced journal saves the
exact prior heating state, intended boost, operation ID, expiry and installation
identity. A timeout after acceptance can therefore be reconciled on restart.
Restoration runs even if disabled or the price/sensor API has failed. Read/write
failures retain recovery information for a later retry. Readback must confirm
restoration before deleting the journal. A matching prior state means expiry
or a write that never happened; a differing external state is preserved. The
adapter must make writes conditional and idempotent to avoid overwriting a
concurrent occupant change. A journal must be unique per account/house/zone.

This state machine is tested with simulated controls only. It is **not evidence
that Homely provides compare-and-set or native expiry**. The production adapter
must prove equivalent guarantees, or this design needs revisiting. Native expiry
is essential because the Mac can sleep, lose internet or stop running; local
retry logic alone cannot guarantee a stop. Returning to the saved heating state
also does not necessarily turn the heat pump off if the normal strategy still
requests heat. DHW can continue running independently.

## Before any live activation

Obtain redacted app/vendor evidence for heating write and cancel/restore methods,
zone selection, current-state readback, live room temperature plus observation
time, native expiry, and effects on holiday/summer modes and DHW priority.
Do not invent method names or probe state-changing operations to discover them.
Implement the adapter only against that evidence, add fixture-based API tests,
and prove that its payloads exclude DHW/Sunamp and unrelated settings. Capture
prior controls including active overrides and mode. Respect existing holiday,
summer, hot-water-only and manual choices rather than silently defeating them.

Then prepare a concrete short supervised test describing profile/zone, target,
limit, duration, prior state and rollback. **Ask the user before changing live
heating controls.** Only after approval perform the supervised test and verify
expiry/restore with readback. A separate frequent worker, monitoring and sleep/
restart handling would be needed for unattended operation; the once-daily DHW
job is not an adequate safety loop and must remain independent.

## Validation

The test suite covers inclusive/negative thresholds, raw versus solar price,
46/48/50-slot days, both repeated autumn hours, incomplete/duplicate/overlapping
rates, non-finite values, safety policy validation, disabled live mode before
authentication, prior-state restoration, manual intervention, idempotent polling,
sensor failure/staleness/future timestamps, price failure, disabling, write/read
failures, timeout after successful write, restart recovery, journal identity/
corruption and refusal without native expiry. A DHW regression verifies that
replacing a weekday preserves other weekdays and does not mutate its input.

## Separate switching prices

Set, for example:

```ini
HEATING_ON_PRICE_P=0
HEATING_OFF_PRICE_P=5
```

Heating starts at **0 p/kWh or below**. Once started, it continues while the price
is **5 p/kWh or below**, and restores the prior heating state **above 5 p/kWh**.
At exactly the off price it remains on. Between 0 and 5 it retains its existing
decision: an inactive boost will not start. Equal on/off settings are allowed
and preserve the original single-threshold behaviour. The off price cannot be
lower than the on price. Both values must be finite and support profile overrides.
The legacy `HEATING_PRICE_THRESHOLD_P` is a fallback for the on setting when the
new key is absent; the off setting then defaults to that same on value.

Safety limits and failed/missing API data always override the price permission.
The controller retains price permission across an immediately adjacent slot and
restart using its recovery journal, while still enforcing native expiry and fresh
temperature checks. After a gap beyond that adjacent slot, it must meet the on
price again. The read-only planner lists start candidates only, since subsequent
hold-band operation depends on the actual prior heating state. No live control
adapter or job is enabled by changing these settings.


## Subsequent mode-control discovery

A supervised Proxyman capture has now established `setSettings` with boolean
`hotWaterOnlyMode` (`false` allows normal space heating, `true` disables it).
`getZones` provides candidate room temperature, reported heating state and an
update timestamp. See [the discovery register](HOMELY-OBSERVED-CALLS.md) for
verified examples and important mode-write side effects. Earlier statements in
this document about unobserved writes/sensors describe the initial inspection.

A later capture verified `setHeatingBoost` cancellation (`status: false`,
string `zoneId`). The user observed boost starting as soon as heating was
enabled; no separate start request was captured. Enabling must therefore be
treated as potentially starting a boost. A separate start contract, proven timed
expiry, conditional ownership mechanism and exact override restoration remain
unverified. The mode command rebuilds override timestamps.
The controller and app therefore remain plan-only; no live adapter is enabled.


## Docker supervision implementation

The Docker service now runs a separate ten-second supervisor and exposes its
status through `heating_control`. Its tested verified-adapter path includes
persistent recovery, restoration before new starts after restart, a manual-change
hold, effective-price thresholds and temperature cutoff at the configured target
or limit. No Homely temperature-setting request is inferred. See
[controller implementation and activation boundary](../controller/README.md#heating-supervisor-and-recovery).
The observed API transport remains write-disabled, and no real lease/ownership
adapter is supplied. This is a tested implementation in plan-only mode, not
activated automatic heating.


## Explicit app boost start/cancel verified on 25 October

A supervised phone capture now establishes the start payload: `status:true`,
integer Unix-millisecond `start` and `end`, and string `zoneId`. Cancellation is
`status:false` plus string `zoneId`. HTTP 200 responses confirmed `boostActive`
true then false, 14.917 seconds apart. The existing enabled mode was preserved;
full settings, schedules and override records matched the baseline afterward.
The server returned an earlier minute-aligned end in this sample. Native expiry,
general duration/zone/sensor semantics and conditional ownership remain unverified.
The existing write-disabled transport is unchanged. See the discovery register
for the current observed contract; earlier no-start statements are historical.
