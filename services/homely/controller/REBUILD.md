# Rebuild, verification and action logs

The scripts build and test an image. They never restart the NAS, change policy,
enable automation, access credentials or call Homely. Deployment is separate.

## Prerequisites and rebuild

Use Bash, Git, Docker with Linux-container support, tar and gzip and enough disk for an
image archive. DS918+ uses `linux/amd64`; Docker Desktop on an Apple Silicon Mac
can build/run this target through emulation. The build downloads its base image,
OS packages and Python requirements. Verification has no network access.

```sh
git clone https://github.com/rhine59/Homely.git
cd Homely
./scripts/rebuild-controller.sh
# Optional new archive filename; existing files are never overwritten:
./scripts/rebuild-controller.sh /private/path/heating-controller.tar.gz
# Verify an existing image without rebuilding:
./scripts/verify-controller.sh
```

Default image: `homely-heating-controller:verified`. Overrides apply to both build
and verification:

```sh
IMAGE=homely-heating-controller:candidate PLATFORM=linux/amd64 \
  ./scripts/rebuild-controller.sh
# For a Synology shell where Docker is not on PATH:
DOCKER=/usr/local/bin/docker ./scripts/rebuild-controller.sh
```

A failed build, test, either walkthrough or export exits nonzero. Export happens only
after verification succeeds. The archive is private, created atomically and
incomplete exports are cleaned up. The resulting image ID is printed. Record it
with `git rev-parse HEAD`. Package/base-image resolution may change in future;
these are repeatable instructions, not a byte-identical-build promise. Retain
the tested archive for exact reinstalls.

## Verification coverage

The actual image runs as its configured non-root user with no network, a
read-only root filesystem and temporary `/tmp`, with streamed fixture copies.
Neither production `/data` nor credentials are mounted.

| Check | Coverage |
| --- | --- |
| Backend suite | 200 checks at this revision: policy/API/auth/errors, effective prices, missing data, native requests, disabled activation, explicit OFF, restart recovery, manual holds, slow setup, history outbox/deduplication and DST |
| Narrated Python demo | 62 checks using real local HTTP handlers with fake cloud/equipment: all six public method/path combinations, signed prices, writes/restoration/conflicts, current and selected weekly history |
| Schedule/period rehearsal | Synthetic target edit, exact restore, no-op after restore, external-edit refusal, add/remove one-hour period; no Homely request |
| Optional deployed read | Status, policy, switch and history over HTTPS; never writes or proves physical heat delivery |

Counts may grow. A legacy regression test prints an expected argparse “Live
heating disabled” message; the final suite result/exit code is authoritative.
A mock pass does not replace reviewed live Homely evidence. Focused app tests
live in the separate AgilePriceWheel repository.

## Updating an existing Synology installation

A recreation briefly stops HTTP and workers. Restart can reconcile an outstanding
boost, then wait for a new slot. Upgrade while idle; build and test first.

1. Securely save the existing private runtime Compose/environment files. Record
   project name, image tag, activation and mounts. Inspect output may contain
   credentials; do not publish or commit it.
2. Back up the entire persistent data volume consistently: policy, switch, native
   ledger, proof, SQLite database and any WAL files. Use a consistent NAS snapshot
   or stop the container for the backup.
3. Transfer the verified archive with your existing SSH connection, then load it:

   ```sh
   gzip -dc /private/path/heating-controller.tar.gz | /usr/local/bin/docker load
   ```

4. Retain the existing image under a rollback tag. Set only this service's image
   to the verified tag, or retag it to the runtime image tag. Recreate only this
   service using its **existing runtime Compose file**, project and environment.
   Preserve policy volume, secret mount, API key, profile/zones, evidence,
   activation and saved switch. The shipped generic Compose is for new installs;
   it must not replace the configured NAS file.
5. Allow at least 90 seconds for startup and scheduled health checks. Verify a
   fresh control poll, API reachability, recovery, saved policy/switch and retained
   history. Compare mounts by destination: Docker can reorder equivalent mounts.
6. If checks fail, restore the retained image tag and recreate just this service
   with unchanged configuration. Preserve `/data`; do not erase state, reset the
   switch or replay start commands as a rollback shortcut.

An image rebuild/load alone does not change a running container. Compose service
recreation does restart it. These scripts perform neither recreation nor live
activation. Never use `docker compose down -v` on the existing installation.

## Read-only verification of the deployed service

Keep the bearer key in an owner-only private file. Live reads use only the Python
standard library:

```sh
python3 examples/heating_services.py \
  --url https://heating.example.com:8451 \
  --key-file /private/path/controller-key.txt --samples 1
```

This reads all GET services, including current and selected weekly history. To
also inspect Docker through an existing SSH login, append
`--docker-container homely-heating --ssh-target account@nas.example.com --ssh-port 2233`.
No write occurs unless `--write-policy` or `--automation on/off` is explicitly
supplied. The [Python narrative](../examples/README.md) explains simulated and
live writes, backup/restoration and uncertain outcomes.

## Where to see action logs

- **iPhone:** Heating → Weekly heating log. Monday–Sunday London weeks; use arrows
  for older weeks, Reload or pull to refresh. ON red, OFF green. Entries show
  confirmed time, effective price, thresholds and reason.
- **API:** authenticated `GET /v1/history`, optionally `?week=YYYY-MM-DD` with a
  Monday date. The sample's `Client.history()` returns complete event records.
- **NAS volume:** `/data/heating-history.sqlite3`, retaining 366 days. Events
  awaiting a DB retry stay in the native ledger; the API reports pending/warning.
- **Diagnostics:** `docker logs --timestamps --tail 100 homely-heating` and local
  health/exit inspection. stdout is not the action ledger. Status exposes source
  and control failures; the automation endpoint exposes shutdown acknowledgement.

A Monday starts an empty page until new actions occur. Sunday 25 October entries
belong to the week beginning 19 October. There is no reconstructed pre-install
history. Manual Homely changes, compressor cycles and measured electricity use
are outside the log. HTTP can be healthy while prices or Homely are unavailable;
check status freshness/errors as well as container health.

The [service catalogue](SERVICES.md) documents every endpoint, request/response,
configuration, pricing model, storage, timing and outage limit. The
[observed Homely register](../docs/HOMELY-OBSERVED-CALLS.md) documents captured
upstream calls. These scripts add no upstream control call.


See [26 October bug audit](../docs/BUG-AUDIT-2026-10-26.md) for exclusive week boundaries, retention, consistent read transactions and session truncation fixes.


## Current image versus temperature research

The source now includes an offline schedule-target/period planner and its tests.
It is packaged so the same candidate image can run the full verification script,
but it is not imported by the runtime driver. Production still refuses schedule
writes. A build/test pass does not enable a 22°C target or remove a manual hold.
The [container guide](CONTAINER.md) explains runtime components and the difference
between the six client API routes and the captured upstream Homely commands.


For the actual Synology runtime, its volumes and both NAS/Mac build paths, start with [homely-heating on Synology](CONTAINER.md). The source packaging script handles the NAS without Git and excludes ignored private files.


[Synology network setup](NETWORKING.md) documents DSM HTTPS routing, certificate assignment, TCP 8451 forwarding, backend ports and end-to-end verification.


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
