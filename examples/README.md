# Exercise every homely-heating service

Entry point: `heating_services.py`; offline helper: `heating_demo.py`. See the
[full catalogue](../controller/SERVICES.md). Default live mode is read-only.
Explicit `--write-policy` changes policy temporarily; explicit `--automation off`
requests heating shutdown, and `--automation on` can start policy heating only
when the controller has already been administratively activated.

## Use case: being paid to import electricity

Set Heating on to −5p and Heating off to −1p. At a new half-hour with effective
price −5p or lower, the active controller enables heating if needed and starts a
boost ending at the next boundary. It keeps Homely's own temperature targets.
Once permitted, it holds through −1p; a later 0p slot ends permission and disables
normal heating. PV reduces import, so it can also reduce the payment magnitude.

The app Automation switch is a separate permission. OFF is saved first, cancels
the selected timed boost and disables heating, with pending status until readback
confirms completion. The paused controller then leaves later manual Homely use
alone. ON requires prior administrative activation and a new half-hour boundary.
A lost save/switch response is reloaded instead of blindly repeated.

## Offline: all service categories without real heating

```sh
python3 examples/heating_services.py --demo
```

Use the repository's installed dependencies, or the tested Docker image:

```sh
IMAGE=homely-heating-controller:verified ./scripts/verify-controller.sh
```

The walkthrough passes 62 checks using real authenticated HTTP handlers, pricing calculations,
policy persistence, the slot state machine and native driver, against temporary
files and fake cloud/equipment responses. It covers all six GET/PUT method/path combinations,
authentication, conflicts, signed thresholds, PV, DST, gate enforcement, native
request shapes, no temperature payload, per-slot renewal, off commands,
restart/manual holds and corrupt recovery. The earlier simulated lease/temperature
model is also exercised as a regression fixture; it is not the production driver.
No cloud request or physical heating command is sent in `--demo`.

## Read-only: deployed service and optional Docker inspection

Keep the key in a private file or `HOMELY_HEATING_TOKEN` environment variable:

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 --key-file /private/path/controller-key.txt
```

This reads policy, status, automation state and current/selected weekly history,
then samples status again. It does
not modify anything. HTTPS redirects are refused and credentials are not logged.
Optional read-only health/isolation inspection uses an existing connection:

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 --key-file /private/path/controller-key.txt \
  --docker-container homely-heating --ssh-target account@nas.example.com --ssh-port 2233
```

## Explicit automation command

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 --key-file /private/path/controller-key.txt \
  --automation off
```

This is a real stop request, not an observation. It persists OFF and requests
heating shutdown. Use read-only mode afterwards to check shutdown_pending and
Homely's reported state. `--automation on` is the corresponding explicit arming
request, blocked with 409 until administrative activation/evidence/recovery allow
it. The example cannot grant administrative activation or bypass the write gate.
NAS/controller/API outages can delay shutdown; a native boost end alone does not
disable normal heating. Use Homely directly when remote shutdown is unconfirmed.

## Explicit temporary price-policy exercise

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 --key-file /private/path/controller-key.txt \
  --write-policy --on-price -5 --off-price -1 \
  --backup-file /private/path/original-policy.json --samples 2 --interval 2
```

This is restricted to plan-only mode and cannot be combined with a switch command.
It saves a private original-policy backup, writes signed prices and restores only
if its confirmed revision still owns the policy. Concurrent edits and uncertain
saves preserve the backup for reconciliation. Original tariff/PV/legacy temperature
fields are preserved; no temperature policy arguments are required. Revision
numbers never roll back. Run this only when you intend to change the shared policy.

## Reviewing the weekly log

The default read-only walkthrough also calls `GET /v1/history`, then reloads
that Monday with `?week=YYYY-MM-DD`. Use `client.history()` for this week and
`client.history("2026-10-19")` for a selected retained Monday. Review ON/OFF
timestamps, signed effective prices and reasons before editing policy. The
offline demo exercises both forms and invalid-week validation without heating.

## Endpoint narrative and coverage

| Step | Request | What the walkthrough demonstrates |
| --- | --- | --- |
| 1 | GET /v1/policy | Load signed on/off thresholds and revision before editing |
| 2 | GET /v1/status | Review effective prices, freshness, permission, reported heating and recovery |
| 3 | GET /v1/history | Review this week's confirmed ON/OFF actions |
| 4 | GET /v1/history?week=YYYY-MM-DD | Reload a selected London Monday; reject invalid dates |
| 5 | GET /v1/automation | Read persistent switch and shutdown acknowledgement |
| 6 | PUT /v1/policy | Save a complete revision-checked policy, then restore values at a new revision |
| 7 | PUT /v1/automation | Simulate OFF shutdown, blocked ON and activated ON with fake equipment |

Steps 1–5 are read-only live defaults. Steps 6–7 run against temporary files and
fake equipment in `--demo`; a real write requires the explicit live options above.
The walkthrough also exercises pricing/PV workers, DST, persistence, recovery,
authentication and errors. Docker health/isolation is a separate optional
read-only inspection because the offline demo cannot inspect your deployed NAS.

`Client.history()` and `Client.history(monday)` return full event dictionaries;
for an example display loop:

```python
week = client.history()  # client is an authenticated Client instance
for event in week['events']:
    print(event['at'], event['state'].upper(), event['price_p'], event['reason'])
```

Times returned by the API are UTC; the app displays London GMT/BST. Manual
changes and compressor cycles are not included. Retention and storage warnings
are described in the service catalogue. Rebuild the tested example environment
with `./scripts/rebuild-controller.sh`; see [rebuild guide](../controller/REBUILD.md).

To print all actions for a previous week, add `--history-week`:

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 --key-file /private/path/controller-key.txt \
  --history-week 2026-10-19 --samples 1
```

The program prints each event's UTC confirmation time, ON/OFF, signed effective
price and reason, plus any pending-history warning. A Monday date is required;
invalid or out-of-retention dates are rejected by the service.

## Use case: check what a completed heating session cost

After a cheap slot, open Weekly heating log or run the read-only example for its
week. The sample now prints each correlated session: ON/OFF, elapsed seconds,
estimated GBP, estimate status, and the individual Agile/effective rates and load
assumptions. For example, 3 kW for half an hour at −5p/kWh effective price estimates
1.5 kWh and £0.075 paid to you. A later rate change is integrated separately.
Check `cost_status` before using a total: incomplete rate data or an unconfirmed
OFF produces null, not a guessed bill. Existing old pairs can show duration but
lack historical cost assumptions. Cross-week sessions repeat with the same ID;
deduplicate IDs when combining weeks. See the service catalogue for all fields.


## Offline temperature-edit rehearsal

```sh
python3 examples/temperature_target_demo.py
# Or use the separately built candidate image:
IMAGE=homely-heating-controller:schedule-planning ./scripts/rebuild-controller.sh
# Rebuild runs this example along with the backend suite and all-service demo.
# To repeat verification against the existing image:
IMAGE=homely-heating-controller:schedule-planning ./scripts/verify-controller.sh
```

Use case: a future preheat controller needs to change one existing target to
22°C, then restore it without overwriting a person’s intervening edit. This
example uses synthetic data and the pure schedule planner. It preserves every
other entry/time/ID, requires heating disabled, checks a fake independent
readback, restores exactly, avoids replay after restoration and refuses to
restore after an external edit. It does not call any public or Homely API.

This is preparation, not an enabled 22°C heating mode. Creation/deletion of
periods, targets outside existing schedule windows, native boost temperature,
reliable sensor freshness, durable live recovery and arbitrary temporary ownership
are still unverified. New code does not widen the production write allowlist.


The temperature rehearsal also covers `plan_period`: add one synthetic Tuesday
16:00–17:00 period at 22°C, then remove it while preserving the original entries.
The app's one-hour editor minimum is enforced conservatively. The program supplies
a synthetic unused ID; no live ID generator has been established. This models
schedule data only, not an actual one-hour heating run or a timed boost target.


On the NAS, prefer `verify-controller.sh`: it streams fixtures into disposable
`/tmp` instead of bind-mounting host folders, avoiding Synology UID/ACL access
errors. See [NAS container guide](../controller/CONTAINER.md) and
[reverse proxy/forwarding](../controller/NETWORKING.md) for the running service.


## Prepared supervised target experiment

`launch_supervised_probe.py` and `supervised_boost_target.py` implement the
[proposed test](../controller/SUPERVISED-22C-TEST.md). Preparation and final
verification are read-only; run/stop require the explicit live flag and specific
human approval. These are not part of the default six-service walkthrough and
are not executed live by build/test scripts. The backend tests rehearse their
behaviour with fake equipment only. No actual heating test has been performed.
