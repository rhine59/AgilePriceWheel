"""Observed Homely transport and legacy simulated-controller regression harness.

The production price-only driver is controller.slot_control. Automatic starts
require activation, matching private expiry evidence and app ON. Explicit user
OFF has separate stop-only permission and can never enable or start heating.
"""
from __future__ import annotations

import copy
from datetime import datetime, timezone
import fcntl
import math
from pathlib import Path
import threading

from heating_boost import Controller, Journal, Policy
from homely import Config, HomelyClient, homely_login, CUSTOMER_API_URL

UTC = timezone.utc
READ_METHODS = frozenset({'userInfo', 'getUser', 'getSettings', 'getAllSchedules',
                          'getHeatingBoost', 'getZones'})
OBSERVED_WRITES = frozenset({'setSettings', 'setHeatingBoost'})
LIVE_BLOCKERS = (
    'Native automatic expiry has not been verified.',
    'Conditional ownership and exact override restoration have not been verified.',
    'Enable-to-boost behaviour and sensor/zone mapping need a supervised test.',
)


class ControlUnavailable(RuntimeError):
    """Public-safe error: never include credentials, identifiers or API bodies."""


class SafeClient(HomelyClient):
    def post(self, body):
        if body.get('method') not in READ_METHODS | OBSERVED_WRITES:
            raise ControlUnavailable('Customer method is outside the heating allowlist')
        try:
            response = self.session.post(CUSTOMER_API_URL, headers=self.headers,
                                         json=body, timeout=10, allow_redirects=False)
            if response.status_code != 200:
                raise ControlUnavailable('Homely request failed')
            return response.json()
        except Exception:
            raise ControlUnavailable('Homely request failed; no automatic write retry') from None


class ObservedHomely:
    """Narrow transport for captured requests, with an explicit write gate.

    This is not the lease/ownership adapter required by Controller. The service
    constructs it read-only; the price-only supervisor opens its gate only after
    explicit activation and matching native-expiry evidence. Methods do not retry writes,
    including when a response is lost after the server accepted a request.
    """
    def __init__(self, env_file, profile, house_id, zone_id, boost_zone_id,
                 *, allow_writes=False):
        if not all(isinstance(v, str) and v for v in (profile, house_id, zone_id, boost_zone_id)):
            raise ValueError('Explicit profile, house and both zone identifiers are required')
        self.env_file, self.profile = Path(env_file), profile
        self.house_id, self.zone_id, self.boost_zone_id = house_id, zone_id, boost_zone_id
        self.allow_writes = allow_writes
        self.allow_stop = False
        self.client = None
        self.last_observation = None

    def connect(self):
        if self.client is not None:
            return self.client
        try:
            config = Config(self.env_file, self.profile)
            client = SafeClient(homely_login(config)['access_token'])
            client.discover_identity()
            if client.house_id != self.house_id:
                raise ControlUnavailable('Household does not match the configured installation')
            self.client = client
            return client
        except Exception:
            raise ControlUnavailable('Homely login or installation verification failed') from None

    def call(self, method, payload=None):
        if method not in READ_METHODS | OBSERVED_WRITES:
            raise ControlUnavailable('Customer method is outside the heating allowlist')
        stopping=self.allow_stop and ((method=='setSettings' and payload=={'hotWaterOnlyMode':True}) or (method=='setHeatingBoost' and payload=={'status':False,'zoneId':self.boost_zone_id}))
        if method in OBSERVED_WRITES and not (self.allow_writes or stopping):
            raise ControlUnavailable('Live heating writes are disabled')
        client = self.connect()
        body = dict(method=method, houseId=client.house_id, userId=client.user_id)
        if payload is not None:
            body['payload'] = payload
        try:
            return client.post(body)
        except Exception:
            # Reauthenticate on a later control tick, never replay an uncertain write.
            self.client = None
            raise ControlUnavailable('Homely request failed; outcome must be reconciled') from None

    def set_disabled(self, disabled):
        if type(disabled) is not bool:
            raise ValueError('Disabled must be a boolean')
        result = self.call('setSettings', dict(hotWaterOnlyMode=disabled))
        if not isinstance(result, dict) or not isinstance(result.get('settings'), dict) or not isinstance(result.get('schedules'), dict) or result['settings'].get('hotWaterOnlyMode') is not disabled:
            raise ControlUnavailable('Unexpected settings-write response; outcome uncertain')
        return result

    def cancel_boost(self):
        result = self.call('setHeatingBoost', dict(status=False, zoneId=self.boost_zone_id))
        if not isinstance(result, dict) or result.get('boostActive') is not False or result.get('zoneId') != self.boost_zone_id:
            raise ControlUnavailable('Boost cancellation was not verified')
        return result

    def start_boost(self, start, end):
        if start.tzinfo is None or end.tzinfo is None or not 0 < end.timestamp()-start.timestamp() <= 1800:
            raise ValueError('A timezone-aware boost of at most one half-hour is required')
        first,last=int(start.timestamp()*1000),int(end.timestamp()*1000)
        result=self.call('setHeatingBoost',dict(status=True,start=first,end=last,zoneId=self.boost_zone_id))
        if (not isinstance(result,dict) or result.get('boostActive') is not True
            or result.get('zoneId')!=self.boost_zone_id or type(result.get('start')) is not int
            or result['start']!=first or type(result.get('end')) is not int or result['end']!=last):
            raise ControlUnavailable('Unexpected boost start response; outcome must be reconciled')
        return result

    def observe(self, now):
        settings = self.call('getSettings')
        zones = self.call('getZones')
        if not isinstance(settings, dict) or type(settings.get('hotWaterOnlyMode')) is not bool or not isinstance(zones, list):
            raise ControlUnavailable('Unexpected heating state response')
        matches = [z for z in zones if isinstance(z, dict) and z.get('id') == self.zone_id]
        if len(matches) != 1:
            raise ControlUnavailable('Configured temperature zone was not uniquely found')
        zone = matches[0]
        value, updated = zone.get('temperature'), zone.get('lastUpdated')
        if (type(value) not in (int, float) or not math.isfinite(value)
                or not -30 <= value <= 60 or type(updated) not in (int, float)
                or not math.isfinite(updated) or type(zone.get('nodeLost')) is not bool
                or type(zone.get('heatingOn')) is not bool):
            raise ControlUnavailable('Invalid heating telemetry')
        try:
            observed = datetime.fromtimestamp(updated / 1000, UTC)
        except (ValueError, OverflowError, OSError):
            raise ControlUnavailable('Invalid heating timestamp') from None
        age = (now - observed).total_seconds()
        self.last_observation = dict(disabled=settings['hotWaterOnlyMode'],
            reported_heating_on=zone['heatingOn'], room_c=value,
            observed_at=observed.isoformat(), sensor_age_s=age,
            sensor_candidate_fresh=not zone['nodeLost'] and 0 <= age <= 120,
            sensor_contract_verified=False)
        return copy.deepcopy(self.last_observation)


class Supervisor:
    """Bridge effective-price policy to the persistent, tested safety controller.

    An injected lease adapter is used only by tests until its real Homely
    contract exists. Production has an optional observation transport instead.
    """
    def __init__(self, state, journal_path, *, adapter=None, identity='unconfigured',
                 observer=None, requested=False):
        self.state, self.adapter, self.observer = state, adapter, observer
        self.requested = requested
        self.journal = Journal(Path(journal_path), identity)
        self.hold = Journal(Path(journal_path).with_suffix('.hold.json'), identity)
        self.recovering = self.journal.path.exists()
        self.lock = threading.Lock()
        self._status = dict(phase='disabled', control_enabled=False,
            recovery_pending=self.recovering, last_checked_at=None,
            observation=None, error=None, blockers=list(LIVE_BLOCKERS))
        self.process_lock = None

    def claim_process(self):
        """Hold one process lock for this data directory, including observations."""
        self.journal.path.parent.mkdir(parents=True, exist_ok=True)
        handle = self.journal.path.with_suffix('.process.lock').open('a')
        try:
            Path(handle.name).chmod(0o600)
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except Exception:
            handle.close()
            raise RuntimeError('Another heating supervisor owns this data directory') from None
        self.process_lock = handle

    def status(self):
        with self.lock:
            return copy.deepcopy(self._status)

    def step(self, now=None):
        now = now or datetime.now(UTC)
        result = dict(phase='disabled', control_enabled=False,
            recovery_pending=self.journal.path.exists(), last_checked_at=now.isoformat(),
            observation=None, error=None, blockers=list(LIVE_BLOCKERS))
        try:
            if self.adapter is None:
                # Existing journal must never disappear because this release lacks
                # a compatible adapter or credentials. Surface manual recovery.
                if result['recovery_pending']:
                    result['phase'] = 'recovery_required'
                    result['error'] = 'Saved heating recovery requires the matching verified adapter'
                elif self.requested:
                    result['phase'] = 'blocked'
                if self.observer is not None:
                    result['observation'] = self.observer.observe(now)
            else:
                # Serialise policy changes with an entire control tick. A policy
                # saved after this tick invalidates the next start immediately.
                with self.state.control_lock:
                    document = self.state.document()
                    price = self.state.status(now)
                    p = document['policy']
                    recovering = self.recovering
                    policy = Policy(enabled=self.requested and not recovering,
                        on_price_p=p['on_price_p'], off_price_p=p['off_price_p'],
                        target_c=p['target_c'], limit_c=p['limit_c'])
                    slot = None
                    if not price['stale'] and price['current'] is not None:
                        current = price['current']
                        slot = dict(start=datetime.fromisoformat(current['start']),
                            end=datetime.fromisoformat(current['end']),
                            price=current['effective_price_p'])
                    hold = self.hold.load()
                    held = hold is not None and hold.get('revision') == document['revision']
                    if held and slot is not None and slot['price'] > policy.off_price_p:
                        held = False
                    if hold is not None and not held:
                        self.hold.clear()
                    if held and not self.journal.path.exists():
                        result['phase'] = 'manual change hold'
                    else:
                        engine = Controller(self.adapter, self.journal, policy)
                        result['phase'] = engine.tick(now, slot)
                        if result['phase'] == 'external change preserved':
                            self.hold.save(dict(previous={}, boost={}, expires=now.isoformat(),
                                operation_id='manual-hold', revision=document['revision']))
                    self.recovering = False
                    result['control_enabled'] = self.requested and self.adapter.server_expiry_verified
                    result['recovery_pending'] = self.journal.path.exists()
                    result['blockers'] = [] if self.adapter.server_expiry_verified else list(LIVE_BLOCKERS)
        except Exception:
            # Never expose exception text: the API or saved journal may be private.
            result['phase'] = 'recovery_required' if self.journal.path.exists() else 'unavailable'
            result['recovery_pending'] = self.journal.path.exists()
            result['error'] = 'Heating check failed; outcome may be uncertain. Saved recovery will be retried.'
            if result['recovery_pending']:
                self.recovering = True
            result['control_enabled'] = False
        with self.lock:
            self._status = result
        return result

    def worker(self):
        while True:
            self.state.control_wake.clear()
            self.step()
            self.state.control_wake.wait(10)


def build_supervisor(state, environ):
    # Activation is separate from matching installation-specific expiry evidence.
    # The transport starts read-only; the new supervisor opens its gate only when
    # both checks pass. The previous simulated Supervisor remains for regression tests.
    requested = environ.get('HEATING_LIVE_ENABLED', 'false')
    if requested not in ('true', 'false'):
        raise ValueError('HEATING_LIVE_ENABLED must be true or false')
    observer = None
    if environ.get('HEATING_HOMELY_ENV_FILE'):
        observer = ObservedHomely(environ['HEATING_HOMELY_ENV_FILE'],
            environ.get('HEATING_HOMELY_PROFILE', ''), environ.get('HEATING_HOUSE_ID', ''),
            environ.get('HEATING_SENSOR_ZONE_ID', ''), environ.get('HEATING_BOOST_ZONE_ID', ''),
            allow_writes=False)
    from controller.slot_control import SlotSupervisor
    return SlotSupervisor(state, environ.get('HEATING_RECOVERY_FILE', '/data/heating-recovery.json'),
        observer=observer, requested=requested == 'true',
        proof_path=environ.get('HEATING_NATIVE_EXPIRY_PROOF_FILE'))
