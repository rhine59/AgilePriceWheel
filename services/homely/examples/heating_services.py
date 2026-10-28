#!/usr/bin/env python3
"""Narrated homely-heating client. Live mode is read-only unless explicitly asked to save policy or switch automation.

Standard-library live client; --demo additionally uses this repository's backend
and requirements.txt. Explicit --automation off/on affects heating through the controller; defaults are read-only.
"""
from __future__ import annotations
import argparse
import copy
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit, urlencode
from urllib.request import Request, HTTPRedirectHandler, build_opener


class APIError(RuntimeError):
    def __init__(self, status):
        self.status = status
        super().__init__(f'Controller HTTP {status}; no request was retried')


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class Client:
    def __init__(self, origin, key, *, demo=False):
        parts = urlsplit(origin)
        if (parts.scheme not in (('http',) if demo else ('https',)) or not parts.hostname
                or parts.username is not None or parts.password is not None
                or parts.path not in ('', '/') or parts.query or parts.fragment):
            raise ValueError('Use an HTTPS origin without credentials, path, query or fragment')
        if len(key) < 32 or any(c in key for c in '\r\n'):
            raise ValueError('Controller key must contain at least 32 characters and no newline')
        self.origin, self.key = origin.rstrip('/'), key
        self.opener = build_opener(NoRedirect())

    def request(self, method, path, document=None):
        body = None if document is None else json.dumps(document, allow_nan=False).encode()
        request = Request(self.origin + path, data=body, method=method,
                          headers={'Authorization': 'Bearer ' + self.key,
                                   'Content-Type': 'application/json'})
        try:
            with self.opener.open(request, timeout=15) as response:
                return json.load(response)
        except HTTPError as exc:
            exc.close()
            raise APIError(exc.code) from None
        except (URLError, TimeoutError, OSError):
            raise RuntimeError('Connection failed; outcome may be uncertain. Reload before retrying a save.') from None

    def status(self): return self.request('GET', '/v1/status')
    def history(self, week=None):
        return self.request('GET', '/v1/history' + ('?' + urlencode({'week': week}) if week else ''))
    def policy(self): return self.request('GET', '/v1/policy')
    def save(self, document): return self.request('PUT', '/v1/policy', document)
    def automation(self): return self.request('GET', '/v1/automation')
    def set_automation(self, enabled): return self.request('PUT', '/v1/automation', dict(enabled=enabled))


def show_status(status):
    print('Mode:', status['mode'], '| live control enabled:', status['control_enabled'])
    print('Price data stale:', status['stale'], '| price permission:', status['price_requests_heat'])
    print('Price basis:', status['price_basis'], '| refreshed:', status.get('updated_at'))
    current = status.get('current')
    if current:
        print('Current Agile / effective p/kWh:', current['agile_price_p'], '/', current['effective_price_p'])
        print('Forecast PV / grid kWh:', current['pv_kwh'], '/', current['grid_kwh'])
    print('Forecast slots returned:', len(status.get('slots', [])))
    if 'price_day_complete' in status:
        print('Full local day published:', status['price_day_complete'],
              '| published coverage ends:', status.get('price_coverage_end'))
    if status.get('error_stage'): print('Source/configuration error stage:', status['error_stage'])
    if status.get('error'): print('Pricing warning:', status['error'])
    control = status.get('heating_control', {})
    print('Supervisor:', control.get('phase'), '| recovery pending:', control.get('recovery_pending'))
    print('Last heating check:', control.get('last_checked_at'))
    try:
        age = (datetime.now(timezone.utc) - datetime.fromisoformat(
            control['last_checked_at'].replace('Z', '+00:00'))).total_seconds()
        print('Supervisor check fresh (0..45 seconds):', 0 <= age <= 45)
    except (KeyError, TypeError, ValueError):
        print('Supervisor freshness is unknown.')
    if control.get('error'): print('Supervisor warning:', control['error'])
    for blocker in control.get('blockers', []): print('Activation blocked:', blocker)
    observation = control.get('observation')
    if observation:
        print('Reported room C:', observation['room_c'], '| reported heating:', observation['reported_heating_on'])
        print('Space heating disabled:', observation['disabled'])
        print('Candidate sensor freshness:', observation['sensor_candidate_fresh'],
              '| sensor contract verified:', observation['sensor_contract_verified'])
    else:
        print('Optional Homely observation is not connected.')


def inspect_docker(container, ssh_target=None, ssh_port=22):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', container):
        raise ValueError('Invalid Docker container name')
    template = ('{"health":{{json .State.Health.Status}},'
                '"restart_policy":{{json .HostConfig.RestartPolicy.Name}},'
                '"read_only":{{json .HostConfig.ReadonlyRootfs}},'
                '"restart_count":{{json .RestartCount}},'
                '"cap_drop":{{json .HostConfig.CapDrop}},'
                '"security_options":{{json .HostConfig.SecurityOpt}}}')
    args = ['docker', 'inspect', '--format', template, container]
    if ssh_target:
        if ssh_target.startswith('-') or any(c.isspace() for c in ssh_target):
            raise ValueError('Invalid SSH destination')
        args[0] = '/usr/local/bin/docker'
        args = ['ssh', '-p', str(ssh_port), '-o', 'BatchMode=yes',
                '-o', 'StrictHostKeyChecking=yes', '-o', 'ConnectTimeout=8',
                ssh_target, shlex.join(args)]
    try:
        result = json.loads(subprocess.check_output(args, stderr=subprocess.PIPE, timeout=30))
    except (subprocess.SubprocessError, OSError, ValueError):
        raise RuntimeError('Read-only Docker inspection failed; no container action was taken') from None
    print('Docker operational service:', json.dumps(result))
    if result['health'] != 'healthy' or not result['read_only']:
        print('Operational warning: inspect container health/isolation; this example will not change it.')
    print('API health does not prove fresh prices or physical heating operation.')
    return result


def exercise_live(args):
    key = (Path(args.key_file).read_text().strip() if args.key_file
           else os.environ.get('HOMELY_HEATING_TOKEN', ''))
    client = Client(args.url, key)
    print('Use case: review the current signed-price heating policy and controller status.')
    baseline = client.policy()
    print('Policy revision:', baseline['revision'])
    print('Switch-on / switch-off p/kWh:', baseline['policy']['on_price_p'], '/', baseline['policy']['off_price_p'])
    print('Tariff configured:', bool(baseline['policy']['product'] and baseline['policy']['tariff']))
    show_status(client.status())
    history=client.history(getattr(args, "history_week", None))
    print("Weekly heating log:", history["week_start"], "| confirmed events:", len(history["events"]))
    print("Reload selected week:", client.history(history["week_start"])["week_start"])
    for event in history['events']:
        print('Action:', event['at'], event['state'].upper(), '| effective p/kWh:',
              event['price_p'], '| reason:', event['reason'])
    for session in history.get('sessions', []):
        print('Session:', session['id'], '| ON:', session['on_at'], '| OFF:', session['off_at'],
              '| seconds:', session['duration_seconds'], '| estimated GBP:', session['estimated_cost_gbp'],
              '| estimate status:', session['cost_status'])
        for interval in session['intervals']:
            print('  Rate:', interval['start'], '| Agile p/kWh:', interval.get('agile_price_p'),
                  '| effective p/kWh:', interval.get('effective_price_p'), '| load kW:', interval.get('load_kw'))
    print('History pending:', history['pending_events'], '| warning:', history['warning'])
    switch=client.automation()
    print('Automation switch:', switch['enabled'], '| shutdown pending:', switch['shutdown_pending'], '| can enable:', switch['can_enable'])
    action=getattr(args,'automation','status')
    if action!='status':
        print('Explicit automation command:', action, '(OFF stops heating; ON requires prior controller activation)')
        result=client.set_automation(action=='on')
        print('Saved automation enabled:',result['enabled'],'| shutdown pending:',result['shutdown_pending'])
        return
    if args.docker_container:
        inspect_docker(args.docker_container, args.ssh_target, args.ssh_port)
    if not args.write_policy:
        for _ in range(args.samples - 1):
            time.sleep(args.interval)
            show_status(client.status())
        print('Read-only run complete. No policy or equipment settings changed.')
        return

    if not args.backup_file:
        raise ValueError('--write-policy requires --backup-file for an owner-only original-policy backup')
    status = client.status()
    if status['mode'] != 'plan_only' or status['control_enabled']:
        raise RuntimeError('Policy exercise is restricted to a plan-only controller')
    desired = copy.deepcopy(baseline)
    desired['policy'].update(on_price_p=args.on_price, off_price_p=args.off_price)
    if not all(math.isfinite(v) for v in (args.on_price, args.off_price)) or args.off_price < args.on_price:
        raise ValueError('Require finite signed prices with off >= on')
    # No raw token is saved. Never overwrite a previous recovery backup.
    fd = os.open(args.backup_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'w') as handle:
        json.dump(baseline, handle, allow_nan=False)
        handle.flush(); os.fsync(handle.fileno())
    parent = os.open(str(Path(args.backup_file).resolve().parent), os.O_RDONLY)
    try: os.fsync(parent)
    finally: os.close(parent)
    saved = None
    try:
        saved = client.save(desired)  # Never automatically replay an uncertain PUT.
        print('Temporary policy saved at revision', saved['revision'])
        for _ in range(args.samples):
            time.sleep(args.interval)
            show_status(client.status())
    finally:
        if saved is not None:
            latest = client.policy()
            if latest != saved:
                raise RuntimeError('Another policy revision was observed; it was preserved. Original backup retained.')
            # Revision checking prevents overwriting a concurrent save after the GET.
            restored = client.save(dict(revision=latest['revision'], policy=baseline['policy']))
            print('Original policy values restored at new revision', restored['revision'])
            print('Price refresh has been requested; revision numbers never roll back.')
        else:
            print('Save was not confirmed; original backup retained. Reload to reconcile the outcome.')
    print('No live heating command was sent. Keep the backup until you have checked the policy.')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--demo', action='store_true', help='Exercise every service category offline with fake upstreams/equipment')
    parser.add_argument('--source-dir', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--url', default=os.environ.get('HOMELY_HEATING_URL', ''))
    parser.add_argument('--key-file', help='Private controller key file; otherwise use HOMELY_HEATING_TOKEN')
    parser.add_argument('--history-week', help='Read a retained Monday YYYY-MM-DD; default current London week')
    parser.add_argument('--automation', choices=['status','off','on'], default='status', help='Default read-only; explicit off requests heating shutdown; on requires controller activation')
    parser.add_argument('--write-policy', action='store_true', help='Explicitly save then restore a temporary policy; never enables heating')
    parser.add_argument('--backup-file', help='New private backup filename, required for live policy writes')
    parser.add_argument('--on-price', type=float, default=0)
    parser.add_argument('--off-price', type=float, default=5)
    parser.add_argument('--samples', type=int, default=2)
    parser.add_argument('--interval', type=float, default=2)
    parser.add_argument('--docker-container', help='Optional read-only Docker health/isolation inspection')
    parser.add_argument('--ssh-target', help='Use existing SSH authentication for remote Docker inspection only')
    parser.add_argument('--ssh-port', type=int, default=22)
    args = parser.parse_args(argv)
    if not 1 <= args.samples <= 20 or not math.isfinite(args.interval) or not 0 <= args.interval <= 60:
        parser.error('Use 1..20 samples and a finite interval of 0..60 seconds')
    if args.write_policy and args.automation!='status':
        parser.error('Choose a policy exercise or automation command, not both')
    if args.ssh_target and not args.docker_container:
        parser.error('--ssh-target requires --docker-container')
    try:
        if args.demo:
            if args.write_policy or args.url or args.key_file:
                parser.error('Keep --demo separate from live credentials and --write-policy')
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            from heating_demo import run_demo
            run_demo(args.source_dir)
            if args.docker_container:
                inspect_docker(args.docker_container, args.ssh_target, args.ssh_port)
        else:
            exercise_live(args)
        return 0
    except (RuntimeError, ValueError, OSError) as exc:
        print('Stopped:', str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
