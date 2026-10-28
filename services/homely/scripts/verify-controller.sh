#!/usr/bin/env bash
# Isolated tests: no network, credentials, host/data mounts or heating writes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER="${DOCKER:-docker}"
IMAGE="${IMAGE:-homely-heating-controller:verified}"
PLATFORM="${PLATFORM:-linux/amd64}"
if [[ $# -eq 1 && ( $1 == --help || $1 == -h ) ]]; then
  echo 'Usage: scripts/verify-controller.sh (overrides: DOCKER, IMAGE, PLATFORM)'
  echo 'Runs backend tests, all-service walkthrough and schedule-edit/period rehearsal offline.'
  exit 0
fi
if [[ $# -gt 0 ]]; then echo 'Usage: scripts/verify-controller.sh (overrides: DOCKER, IMAGE, PLATFORM)' >&2; exit 2; fi
# Stream only fixtures as the source owner. The non-root image extracts its own
# disposable copy in /tmp, avoiding Synology host ACL/UID mismatches entirely.
RUNNER="$(cat <<'PY'
import os,pathlib,subprocess,sys,tarfile
if os.geteuid()==0:
    raise SystemExit('Verification requires the configured non-root image user')
for path in [pathlib.Path('/app/homely.py'),pathlib.Path('/app/heating_boost.py'),*pathlib.Path('/app/controller').glob('*.py')]:
    if not os.access(path,os.R_OK):
        raise SystemExit('Application source is not readable by the non-root image user')
print('Image application readable by non-root user',flush=True)
root=pathlib.Path('/tmp/controller-verification');root.mkdir()
with tarfile.open(fileobj=sys.stdin.buffer,mode='r|') as archive:
    for item in archive:
        path=pathlib.PurePosixPath(item.name)
        if (path.is_absolute() or '..' in path.parts or not path.parts
                or path.parts[0] not in ('tests','examples')
                or not (item.isfile() or item.isdir())):
            raise SystemExit('Unexpected fixture archive member')
        archive.extract(item,path=root,filter='data')
for label,command in [
    ('Backend unit tests',[sys.executable,'-m','unittest','discover','-s',str(root/'tests')]),
    ('All-service walkthrough',[sys.executable,str(root/'examples/heating_services.py'),'--demo','--source-dir','/app']),
    ('Schedule target and period rehearsal',[sys.executable,str(root/'examples/temperature_target_demo.py')])]:
    print(label,flush=True)
    subprocess.run(command,check=True)
PY
)"
COPYFILE_DISABLE=1 tar --exclude='__pycache__' --exclude='.DS_Store' -cf - -C "$ROOT" tests examples | \
  "$DOCKER" run --rm --interactive --platform "$PLATFORM" --network none --read-only --tmpfs /tmp \
  "$IMAGE" python -c "$RUNNER"
echo 'Backend suite, complete service walkthrough and schedule-planning rehearsal passed.'
