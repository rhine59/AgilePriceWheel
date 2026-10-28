# homely-heating on Synology

This is the guide to the always-running **Synology NAS container**. The iOS app
is a client; closing it does not stop policy processing. Android heating support
is required but is not yet implemented. The existing Mac hot-water scheduler is
a separate job and is not started by this container.

## Verified running arrangement

The existing NAS installation was inspected read-only on 27 October 2026:

| Item | Current arrangement |
| --- | --- |
| Container | `homely-heating` |
| Runtime image tag | `homely-heating-controller:synology` |
| CPU target | `linux/amd64` |
| Docker / Compose | Docker 24.0.2; Compose v2.20.1 |
| Container HTTP port | 8080; NAS publishes only `127.0.0.1:8086` |
| Remote access | DSM HTTPS reverse proxy on TCP 8451 to that loopback port |
| Runtime folder | `/volume1/docker/homely-heating` |
| Private runtime files | `compose.synology.yml` and `.env` in that folder |
| Persistent state | Named volume `homely-heating_heating-policy` mounted at `/data` |
| Credentials | Separate `homely-heating-observer-secrets` volume at `/run/secrets`, read-only |
| Restart policy | `unless-stopped` |
| Runtime isolation | Non-root user `heating` (UID 10001), read-only root, temporary `/tmp`, capabilities dropped |
| Inspection result | Running and healthy, zero automatic restarts |
| NAS build prerequisites | Bash and Docker/Compose present; Git is not installed |

The real hostname, key, household/sensor identities and login secrets stay in
private configuration. They are not needed to rebuild. The existing runtime is
owner-activated; the generic Compose files deliberately default to activation OFF.
Do not overwrite the private NAS Compose file with the generic example.

See [reverse proxy, certificate and router forwarding](NETWORKING.md) for the
full TCP 8451 → DSM HTTPS → loopback 8086 → container 8080 route.

## What the running container provides

| Public service | Purpose |
| --- | --- |
| `GET /v1/status` | Effective Agile/PV prices, freshness, permission, reported heating and recovery/hold state |
| `GET /v1/policy` | Saved on/off thresholds and tariff/PV/load model with revision |
| `PUT /v1/policy` | Revision-checked policy save; never grants initial activation |
| `GET /v1/automation` | Saved ON/OFF intent, readiness and shutdown acknowledgement |
| `PUT /v1/automation` | Persistent switch; OFF requests cancellation and heating disable |
| `GET /v1/history` | Weekly actions and correlated sessions/cost estimates; optional `?week=YYYY-MM-DD` Monday |

All routes require the bearer key and return JSON. Read routes do not issue
heating writes. The [complete catalogue](SERVICES.md) documents all request and
response fields, errors, authentication, pricing, session estimates and limits.
The [Python walkthrough](../examples/README.md) exercises every service offline;
live mode defaults to read-only and prints actions, sessions and rates.

Agile and solar forecasts refresh in the background. The native driver evaluates
price permission at :00/:30, with signed on/off thresholds and hysteresis. Each
boost ends at the original slot boundary. Starts must begin within 15 seconds;
an in-progress setup has at most 60 seconds to finish. Errors, source loss,
manual changes, policy edits or user OFF may end heating earlier. A half-hour
slot does not guarantee 30 minutes of physical heat-pump operation.

Boost expiry alone does not disable normal heating; the controller explicitly
cancels/disables when permission ends. Cloud/NAS outages can delay shutdown.
Unexpected heating changes cause a persistent hold rather than an overwrite.
Saving a policy or changing the automation revision can release that hold and
permit later starts, so those are control changes, not routine diagnostics.

## Runtime components and stored state

| Component | Role |
| --- | --- |
| `controller/service.py` | Authenticated HTTP, policy storage, price/solar refresh and process startup |
| `controller/slot_policy.py` | Pure half-hour price decisions |
| `controller/slot_control.py` | Captured native boost lifecycle, durable intent, recovery and manual hold |
| `controller/heating.py` | Narrow authenticated Homely transport and reported telemetry |
| `controller/automation.py` | Persistent app ON/OFF switch |
| `controller/history.py` | Private SQLite action/session history, rates and estimated costs |
| `controller/schedule_target.py` | **Offline preparation only**; never imported by the running control driver |

`/data` retains `policy.json`, `automation.json`, the native `*.slot.json` ledger,
reviewed native-expiry proof, optional legacy recovery data, and
`heating-history.sqlite3` plus possible WAL/SHM files. The ledger includes pending
history actions/rates so DB retry does not replay heat commands. Take a consistent
backup of the complete volume; do not copy just a live SQLite main file.

The administrative gate, verified installation/zone selection, matching expiry
evidence, settled recovery and saved app switch all govern starts. No HTTP route
grants administrative activation. Credentials are loaded from the private mount,
not the image or phone. See [configuration](SERVICES.md#storage-settings-and-docker).

## Build and test: NAS or Mac

The same scripts can run on either machine. Building/testing does **not** restart
the existing NAS service, alter its private configuration, change policy, or arm
heating. Tests use fake upstreams/equipment with no network or live data mounts.

| Script | Behaviour |
| --- | --- |
| `scripts/package-controller-source.sh new-source.tar.gz` | On a clean Git checkout, archive only committed source for a NAS without Git |
| `scripts/rebuild-controller.sh [new-image.tar.gz]` | Build amd64 candidate, run all verification, optionally export a private image archive |
| `scripts/verify-controller.sh` | Test an existing candidate: backend suite, all-service Python walkthrough, temperature/period rehearsal |

### Build directly on the Synology NAS

First prepare source on the Mac from the GitHub checkout:

```sh
./scripts/package-controller-source.sh /private/tmp/homely-source.tar.gz
```

Record the printed source revision. Transfer that archive over your existing SSH
connection to the NAS. Keep source in a new subfolder, separate from the private
runtime Compose/environment and persistent volumes. For example, on the NAS:

```sh
cd /volume1/docker/homely-heating
mkdir -m 755 source-candidate
# Use a new source directory for each revision, not an existing live folder.
tar -xzf homely-source.tar.gz -C source-candidate
cd source-candidate
DOCKER=/usr/local/bin/docker IMAGE=homely-heating-controller:candidate \
  bash scripts/rebuild-controller.sh
# Re-run tests without building:
DOCKER=/usr/local/bin/docker IMAGE=homely-heating-controller:candidate \
  bash scripts/verify-controller.sh
```

No Git installation is needed on the NAS. The build needs internet access for
base images/packages. The test containers have `--network none`, read-only root,
`/tmp` temporary storage, and streamed copies of source fixtures in disposable `/tmp`; they never mount the live
policy or credential volumes. The current source suite has **200 backend tests**,
**62 narrated service checks**, and the separate schedule-target/period rehearsal.

### Build on the Mac, then transfer the tested image

```sh
IMAGE=homely-heating-controller:candidate \
  ./scripts/rebuild-controller.sh /private/tmp/homely-candidate-image.tar.gz
```

Transfer the resulting archive over the existing SSH connection. On the NAS:

```sh
gzip -dc homely-candidate-image.tar.gz | /usr/local/bin/docker load
```

Loading adds an image; it does not update or restart the running container.
Both paths produce a separately tagged candidate. Runtime replacement is a
separate deliberate step. See [rebuild/upgrade/rollback](REBUILD.md), including
preserving the existing project, mounts, key, activation, switch and history,
retaining a rollback tag and allowing at least 90 seconds for health verification.
Do not run `compose down -v` or delete the existing volumes.

## Logs, diagnostics and read-only checks

In the app: **Heating → Weekly heating log**. The API exposes the same records.
Sessions show ON/OFF, duration, raw/effective rates and estimated load/cost. Missing
historical rate/load or unconfirmed OFF means unavailable, not zero cost.

On the NAS, `docker logs --timestamps --tail 100 homely-heating` provides runtime
diagnostics, not the complete action ledger. HTTP health can be green while
prices are stale or the driver is on hold. Check status freshness/errors as well.
Use the standard-library sample over the existing HTTPS address:

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8443 \
  --key-file /private/path/controller-key.txt --samples 1
```

`--history-week YYYY-MM-DD` selects a retained Monday. Explicit write options in
the sample affect live policy/heating; omit them for diagnostics. Do not post raw
`docker inspect` output: it can contain secrets.

## Temperature research is not an enabled feature

The 27 October app captures verified editing a scheduled target 16→22→16°C and
adding/removing a one-hour, 22°C period, with heating disabled and exact final
restoration. These are whole-schedule replacements. Production still rejects
`setHeatingSchedule`; no 22°C mode has been deployed by this preparation work.
The earlier timed-boost capture returned 20°C, and its request contained no
setpoint. A scheduled target is not proof of a 22°C timed boost or physical ceiling.
See [preparation status](SCHEDULE-TARGET-PREPARATION.md) and the
[observed API register](../docs/HOMELY-OBSERVED-CALLS.md) before any live extension.


The verifier streams only `tests` and `examples` into a disposable container
and extracts them under `/tmp` as the image's non-root user. It mounts no host
source/data/credentials and does not change NAS permissions. This avoids the
Synology ACL/UID mismatch observed with host bind mounts. The extraction accepts
only regular files/directories under those two paths; links and parent traversal
are rejected. Host `tar` is required.


The Dockerfile normalises read access to public `/app` source inside the image
after COPY. This makes a NAS build work even when the source was extracted with
an owner-only umask; credentials are excluded from the build context. Verification
checks that it runs as non-root and can read the application before running tests.
Neither step changes host permissions or the existing runtime.


[Native Synology verification, 27 October](VERIFICATION-2026-10-27.md): build, 200 backend tests, 62 service checks and both planning scenarios passed on the NAS. The live image/start time and healthy state were preserved.


[Proposed supervised 22°C test](SUPERVISED-22C-TEST.md) documents the explicit approval, fresh-reading preconditions, immediate stop/60-second fallback and final restoration checks. It remains separate from the production worker and has not enabled a 22°C mode.
