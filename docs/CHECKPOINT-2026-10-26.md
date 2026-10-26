# Heating checkpoint — 26 October 2026

## Delivered baseline

- Controller code baseline: Homely `907bcfe`; session correlation, interval rates
  and configured-load cost estimates deployed to the NAS.
- iOS code baseline: AgilePriceWheel `2a6408f`; signed update installed in place,
  retaining connection/settings. Weekly log includes paired sessions and estimates.
- Verification: 172 backend tests, 62 narrated offline checks, 14 focused iOS checks;
  signed build/install and public HTTPS history reads passed.
- Automation enabled by owner approval; saved thresholds 7p on / 8p off preserved
  at checkpoint. Existing temperature targets remain managed by Homely.
- Three old action pairs have durations and effective prices but no invented
  historical load/cost. Future complete records use saved interval rates/load.
- A complete unattended cycle after the setup-latency correction remains unobserved.

## Recovery and documentation

Checkpoint commits are tagged `heating-checkpoint-2026-10-26-session-costs` in both
repositories. The tag includes this document and Android requirements. Runtime
images/data/configuration are private NAS checkpoints, never committed. Build
scripts run isolated tests without restarting the deployed service.

Use the Homely repository's `controller/REBUILD.md`, `controller/SERVICES.md`,
`examples/README.md` and `docs/HOMELY-OBSERVED-CALLS.md` for rebuild, services,
Python narrative and captured upstream calls. The iOS repository holds the app
guide, native Android source and `docs/ANDROID-HEATING-REQUIREMENTS.md`.

## Outstanding requirements

Android heating parity is required, not delivered. Extend the existing Kotlin/
Compose project with the same policy/switch/status, connection settings and weekly
session log/cost semantics, then build/test an installable APK. See the dedicated
Android requirements document. Store publishing is not complete for either app.

Preserve the owner's uncommitted Xcode project settings. No live controls should
be changed merely to verify a checkpoint. Never restore an old saved automation
ON state blindly: review heating state and reconcile using the documented recovery
procedure. Activation evidence and private settings must not be published.

## Verified saved artifacts

The NAS checkpoint contains an online SQLite backup, stable copies of persisted
JSON state, runtime Compose/environment, private inspect metadata and the verified
image archive with SHA-256 manifest. Runtime image ID:
`sha256:81cd02cb6ed2a6546b9056d8224d44bc90dca2636af1c5dca7741b6ed8194bc2`.
The container remained healthy and was not restarted for this checkpoint. Private
artifacts stay outside GitHub. The dedicated login-secret volume remains in place;
its credentials were not copied into public artifacts or the app.

The local checkpoint saves the installed signed iOS build plus documentation and
Python examples with hashes. Phone Keychain/settings remain on the phone. A
saved development build may need signing again when its profile expires.
