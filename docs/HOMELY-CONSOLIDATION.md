# Homely consolidation into AgilePriceWheel

AgilePriceWheel is the single source repository for its native apps and supporting Homely heating/hot-water services. The imported service source comes from Homely commit `2f1cffa709b0f0ed18a772b23fe80560a189eae4`, including the latest DHW trailing-price coverage fix.

## What is merged

- iPhone/iPad and Android remain at their existing paths.
- Homely Python source, controller API, Docker/Compose configuration, tests, examples and documentation are under `services/homely/`.
- The iOS app already integrates the service through App Settings → Agile heating connection and Heating. No second iOS app or new connection is required.
- Root commands provide a single entry point for source packaging, controller build and verification.

## Runtime remains independent of the phone

Repository consolidation does not move the Python service into the iOS process. The NAS/home service continues to evaluate policy and retain history when the phone is closed or offline. The app retains its current HTTP contract, Keychain key and saved address. The separate DHW scheduler remains separate from the space-heating controller.

## Development and tests

From the repository root:

```bash
python3 -m venv .venv-homely
.venv-homely/bin/python -m pip install -r services/homely/requirements.txt
PYTHON="$PWD/.venv-homely/bin/python" ./scripts/test-homely.sh
./scripts/rebuild-homely.sh
./scripts/verify-homely.sh
./scripts/package-homely.sh /tmp/homely-source.tar.gz
```

The test script uses fixtures and an offline demo. Container verification uses `--network none`, disposable storage and no credentials. The rebuild command does not start or replace the live container. Python entry points can also be run after `cd services/homely`; Docker context stays that directory, excluding the native apps.

## Existing NAS installation

No live deployment is performed by this consolidation. Keep the current container, image, token, policy/recovery/history volume, activation and schedules. Do not run a new Compose project against fresh storage and assume that it has migrated existing automation.

For a later upgrade, use the existing [container upgrade/rollback procedure](../services/homely/controller/CONTAINER.md), build from `services/homely`, and retain the exact existing Compose project name and volume bindings. Inspect the active deployment first. Keep secrets in the existing private runtime configuration. No environment file or controller database belongs in Git.

The source package still extracts with `homely.py`, `requirements.txt` and `controller/` at its root, so the documented NAS source-transfer layout stays compatible. Packaging uses committed files only and refuses a dirty checkout.

## Repository history and ownership

The original Homely repository is retained for full history and rollback. Its latest tracked source was imported as a squashed subtree with explicit provenance. No repository was deleted, archived, made public or rewritten. Once this consolidation is merged, make future service changes under `services/homely` in AgilePriceWheel; the old repo can be marked read-only later if desired.

## Release preparation

The already-tested App Store preparation (privacy manifest and version 2.1 build 2) is included. The separate unfinished offline review-demo work remains outside this consolidation until its tests pass. Consolidation itself does not upload, submit or publish a new App Store binary.
