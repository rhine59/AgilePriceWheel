# Homely

Homely is an automated domestic-hot-water scheduler that combines **Homely heat-pump control**, **Octopus Agile half-hour electricity prices** and **forecast solar generation**.

The current production program is `homely.py`. It supports multiple household profiles, dynamically discovers each Homely installation, calculates the lowest expected grid-cost DHW periods, safely replaces only the target weekday's hot-water schedule and emails a detailed activity report.

## Heating container: build, tests and action logs

**[Synology container guide](controller/CONTAINER.md)** — the verified NAS arrangement, all services, persistent storage, build/test scripts, source transfer without NAS Git, logging and upgrade/rollback.

The independent `homely-heating` container controls space heating using effective
Agile/PV prices. It preserves the separate hot-water scheduler. Start with the
[rebuild and verification guide](controller/REBUILD.md),
[complete service catalogue](controller/SERVICES.md) and
[narrated Python walkthrough](examples/README.md).

```sh
./scripts/rebuild-controller.sh
```

This builds an amd64 image and runs isolated verification without restarting the
NAS service. In iOS, action history is **Heating → Weekly heating log**; the same
records are available through the authenticated history API.

## Documentation

**[Python Service Walkthrough](examples/README.md)** — executable example and narrated use case covering every homely-heating service, with offline simulation and optional live read-only checks.

**[homely-heating Services](controller/SERVICES.md)** — complete container service catalogue: API, pricing, policy, optional observations, recovery, configuration and current control restrictions.

**[Homely Python Implementation](docs/HOMELY-PYTHON.md)** — architecture, Homely OAuth/API interaction, Agile retrieval, solar model, slot ranking, schedule construction, email reporting, safety behaviour and function reference.

**[Installation and Configuration](docs/INSTALLATION.md)** — Python setup, `homely.env`, profile configuration, safe first tests, live operation, LaunchAgent installation and troubleshooting.

**[API Reference](docs/API-REFERENCE.md)** — all Homely API calls discovered and used by the project, request examples, likely response structures, OAuth flow, customer methods, plus the Octopus Agile and Open-Meteo calls used by the scheduler.

**[Public Release and Security Audit](docs/PUBLICATION-SECURITY.md)** — checks to perform before making the repository public, including full Git-history secret scanning with the supplied `scripts/publication-audit.sh` tool.

## Main files

- `homely.py` — current production scheduler.
- `homely.env.sample` — example multi-profile configuration.
- `com.richard.homely.plist` — macOS LaunchAgent definition.
- `launchd_setup.sh` — LaunchAgent installer/reinstaller.
- `requirements.txt` — Python dependencies.
- `docs/` — current technical and operational documentation.

## Historical/development implementations

The repository also retains:

- `homely_agile_dhw.py`
- `homely_solar.py`
- `homely_with_logic_email.py`

These are earlier development implementations retained for reference. The scheduled production entry point is `homely.py`.

## Safe test sequence

```bash
# Authentication and Homely discovery only
python homely.py --profile Richard --auth-test

# Calculate tomorrow's schedule without changing Homely
python homely.py --profile Richard --dry-run

# Test all configured profiles without changing Homely
python homely.py --all-profiles --dry-run
```

Only remove `--dry-run` after reviewing the proposed schedule.

## Unattended operation

The supplied LaunchAgent runs:

```bash
python homely.py --all-profiles
```

daily at 23:00.

See [Installation and Configuration](docs/INSTALLATION.md) before enabling unattended operation.

## Security

`homely.env` contains Homely and email credentials and must never be committed. Runtime environment files and logs are excluded from Git.

## Free/negative-price space heating (prepared, live disabled)

`heating_boost.py` plans candidate heating periods using raw Agile import prices
(default <= 0 p/kWh). It includes an offline-tested controller with configurable
temperature limits and recovery journaling. Live Homely heating writes remain
unavailable until the API and native expiry are verified and the user approves
a supervised test. The existing Sunamp/DHW job is unchanged.

See [Heating boost status, usage and safety](docs/HEATING-BOOST.md).

## Synology controller and iPhone connection

The new [always-running controller service](controller/README.md) calculates
**effective** prices from Agile plus forecast PV, and stores separate on/off
price policy. The existing AgilePriceWheel iOS app has a Heating connection page
for status and policy editing. The deployed service remains **plan-only** with automatic starts disabled; an
explicit app OFF can request heating shutdown. No hot-water control is exposed. It is distinct from the raw-price
command-line planner described above.

**[Homely API discovery register](docs/HOMELY-OBSERVED-CALLS.md)** — all identified app operations, observed request/response types, side effects and verification limits, with no private capture values.


The Docker service now includes persistent heating supervision and a narrow
transport for the observed Homely mode/cancellation calls. Live heating remains
blocked; the recovery controller is tested with a simulated verified adapter.
See [supervisor status, setup and tests](controller/README.md#heating-supervisor-and-recovery).


The iPhone heating policy contains **Heating on** and **Heating off**, including
negative values and zero. Homely retains its existing temperature targets. The
native [half-hour driver](controller/slot_control.py) is implemented and gated by
administrative activation, matching expiry evidence and the app Automation switch.
OFF is persistent and requests heating shutdown; ON cannot bypass activation.
The deployed NAS remains unactivated with heating disabled. See the
[controller guide](controller/README.md) for recovery and outage limits.


[26 October heating checkpoint](docs/CHECKPOINT-2026-10-26.md) records the deployed baseline, verification and outstanding Android delivery.


[26 October bug audit](docs/BUG-AUDIT-2026-10-26.md) records corrected price-display and history edge cases, regression evidence and remaining limits.


[Scheduled-target preparation](controller/SCHEDULE-TARGET-PREPARATION.md) documents the 27 October captured temperature edit and offline restoration rehearsal. No 22°C mode has been enabled.


[Reverse proxy and port forwarding](controller/NETWORKING.md) — DSM HTTPS, certificate assignment, router TCP 8451 mapping, port roles and connection checks.


[Native Synology verification](controller/VERIFICATION-2026-10-27.md) records the successful NAS build/test run and the permission fixes found during native testing.


[Prepared supervised target test](controller/SUPERVISED-22C-TEST.md) describes the diagnostic and rollback required before any 22°C heating mode can be considered verified.

### DHW price coverage and scheduler (October 2026)

See [DHW Agile price coverage fix](docs/DHW-AGILE-PRICE-COVERAGE-2026-10-28.md) for the October 2026 incident, the corrected macOS LaunchAgent path, and the `--today` partial-day price coverage behaviour. Scheduled next-day DHW optimisation still requires a complete local day's prices.
