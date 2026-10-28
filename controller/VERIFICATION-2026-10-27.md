# Synology build/test verification — 27 October 2026

## Tested source

Code and scripts at commit `1bd7e9c4406f4e0c2cd3246cf5a150287ddfce1c`
were packaged from a clean Git checkout, transferred as committed source and
built natively on the existing Synology amd64 NAS, which has Bash and Docker
24.0.2 / Compose 2.20.1 but no Git. Later documentation-only updates do not change
the tested application or build/test scripts.

## Results

| Verification | Result |
| --- | --- |
| Native NAS Docker build | Passed; separate candidate tag `homely-heating-controller:nas-build-check` |
| Non-root readability check | Passed |
| Backend unittest suite | 200 tests passed |
| Narrated service walkthrough | 62 checks passed |
| Target + period rehearsal | Passed; synthetic, network disabled |
| Live container image/start-time comparison | Unchanged |
| Live container health afterwards | Running, healthy |
| Default Mac build/verification | Passed |
| Owner-only source reproduction | Passed after fixes below |
| Source packaging guards | Dirty checkout refused; existing archive refused; only committed files included |
| Public HTTPS read | Valid certificate, 401 without key, 200 JSON with key |

Tests mount no host source/data/credential folders and have no network access.
No price policy, heating setting, manual hold, app connection, certificate,
reverse-proxy rule or router port forwarding was changed. The candidate was
not installed as the runtime image.

## Native failures found and fixed

The initial native attempt built successfully but could not read host-mounted
fixtures as the image's non-root user. Verification now streams only tests and
examples into disposable `/tmp`, without broadening NAS folder permissions.
Archive extraction rejects links, absolute/parent-traversal paths and unexpected
root folders.

The next native attempt exposed COPY inheriting owner-only source permissions.
The Dockerfile now normalises public `/app` read access inside the image before
switching to the runtime user. A local reproduction with private source modes
and the final native run both passed. No credentials enter the build context.
These initial failed runs are retained as diagnostic evidence; only the final
native run is claimed successful.

## Reproduce

Use [Synology container guide](CONTAINER.md) for packaging and both native-NAS
and Mac-built-image paths. Run `scripts/rebuild-controller.sh` to build and verify,
or `scripts/verify-controller.sh` against an existing candidate. Host prerequisites
are Bash, Docker, tar and gzip; Git is needed only on the source-packaging machine.
[Network guide](NETWORKING.md) covers DNS, DSM HTTPS/certificate assignment,
router TCP 8451 forwarding and port roles. [Rebuild guide](REBUILD.md) covers
backup, deliberate service replacement and rollback. [Service catalogue](SERVICES.md)
and [Python narrative](../examples/README.md) describe every client endpoint.

The exact owner hostname/LAN address and certificate expiry remain in private
local deployment notes. Public-hostname access from the Mac is not a new cellular
network test, nor a direct audit of the router/DSM saved settings.

## Scope limits

The 22°C schedule/period planner remains offline and disconnected from the live
write path. An actual 22°C timed boost, physical temperature ceiling, new-ID
generation contract and integrated live recovery are not established by these
tests. Android heating parity remains required. A green Docker health check does
not prove fresh prices, absence of a manual hold or physical heat-pump operation.
