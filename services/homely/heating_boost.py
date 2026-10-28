#!/usr/bin/env python3
"""Agile space-heating planner and offline-tested controller.

No live Homely heating write adapter is supplied: the write/expiry/temperature
contracts have not been observed. homely.py and its DHW job are untouched.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
import fcntl
import json
import math
import os
from pathlib import Path
import tempfile
from typing import Protocol
from zoneinfo import ZoneInfo

UTC = timezone.utc


def utc(value: datetime) -> datetime:
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError('Timezone-aware timestamp required')
    return value.astimezone(UTC)


def number(value) -> float:
    if isinstance(value, bool):
        raise ValueError('Boolean is not a temperature or price')
    result = float(value)
    if not math.isfinite(result):
        raise ValueError('Finite temperature or price required')
    return result


@dataclass(frozen=True)
class Policy:
    enabled: bool = False
    on_price_p: float = 0.0
    off_price_p: float | None = None
    target_c: float = 21.0
    limit_c: float = 22.0
    sensor_age_s: int = 120

    def __post_init__(self):
        if self.off_price_p is None:
            object.__setattr__(self, "off_price_p", self.on_price_p)
        for value in (self.on_price_p, self.off_price_p, self.target_c, self.limit_c):
            number(value)
        if self.off_price_p < self.on_price_p:
            raise ValueError('Heating off price must be at least the on price')
        if not 5 <= self.target_c <= self.limit_c <= 25:
            raise ValueError('Require 5 <= target <= room safety limit <= 25 C')
        if not 1 <= self.sensor_age_s <= 300:
            raise ValueError('Sensor freshness must be 1..300 seconds')

    @classmethod
    def from_config(cls, config):
        enabled = config.get('HEATING_BOOST_ENABLED', 'false').lower()
        if enabled not in ('true', 'false'):
            raise ValueError('HEATING_BOOST_ENABLED must be true or false')
        # Legacy single threshold remains a fallback for existing installations.
        on = number(config.get('HEATING_ON_PRICE_P',
                               config.get('HEATING_PRICE_THRESHOLD_P', '0')))
        return cls(enabled=enabled == 'true', on_price_p=on,
                   off_price_p=number(config.get('HEATING_OFF_PRICE_P', str(on))),
                   target_c=number(config.get('HEATING_TARGET_C', '21')),
                   limit_c=number(config.get('HEATING_MAX_ROOM_C', '22')),
                   sensor_age_s=int(config.get('HEATING_SENSOR_MAX_AGE_S', '120')))


def price_requests_heat(price, policy: Policy, active: bool) -> bool:
    """On at/below the on price; off above the off price; hold between."""
    return number(price) <= (policy.off_price_p if active else policy.on_price_p)



def eligible_slots(slots, day: date, tz: ZoneInfo, policy: Policy):
    # Reuse the production completeness/DST checks, then validate numeric prices.
    from homely import validate_agile_day
    ordered = validate_agile_day(slots, day, tz)
    for slot in ordered:
        number(slot['price'])
        utc(slot['start'])
        utc(slot['end'])
    # Raw VAT-inclusive IMPORT price; never the solar-adjusted DHW score.
    return [slot for slot in ordered if price_requests_heat(slot['price'], policy, False)]


class HeatingAdapter(Protocol):
    """Future verified adapter contract, currently exercised only by fake tests.

    States cover space-heating controls only, including prior mode/override.
    make_boost must preserve schedules, DHW/Sunamp and unrelated controls.
    write must use conditional ownership and an idempotency key. A native server
    expiry must return control to the prior strategy if this worker disappears.
    """
    server_expiry_verified: bool
    def read(self) -> dict: ...
    def temperature(self) -> tuple[float, datetime]: ...
    def make_boost(self, previous: dict, target_c: float,
                   expires: datetime, operation_id: str) -> dict: ...
    def write(self, expected: dict, desired: dict, operation_id: str) -> None: ...


class Journal:
    """Atomic local recovery state; one lock covers the entire control tick."""
    def __init__(self, path: Path, identity: str):
        self.path, self.identity = path, identity

    @contextmanager
    def locked(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.with_suffix('.lock').open('a') as handle:
            os.chmod(handle.name, 0o600)
            fcntl.flock(handle, fcntl.LOCK_EX)
            yield

    def load(self):
        if not self.path.exists():
            return None
        record = json.loads(self.path.read_text())
        if not isinstance(record, dict) or record.get('identity') != self.identity:
            raise RuntimeError('Recovery journal identity mismatch or corruption')
        for key in ('previous', 'boost', 'expires', 'operation_id'):
            if key not in record:
                raise RuntimeError('Incomplete recovery journal')
        return record

    def save(self, record):
        record = dict(record, identity=self.identity)
        fd, name = tempfile.mkstemp(dir=self.path.parent)
        try:
            with os.fdopen(fd, 'w') as handle:
                json.dump(record, handle, allow_nan=False)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(name, self.path)
            self._sync_directory()
        finally:
            if os.path.exists(name):
                os.unlink(name)

    def clear(self):
        self.path.unlink(missing_ok=True)
        self._sync_directory()

    def _sync_directory(self):
        fd = os.open(self.path.parent, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)


class Controller:
    """Recovery and safety state machine; no network connections of its own."""
    def __init__(self, adapter: HeatingAdapter, journal: Journal, policy: Policy):
        self.adapter, self.journal, self.policy = adapter, journal, policy

    def tick(self, now: datetime, slot: dict | None):
        with self.journal.locked():
            return self._tick(utc(now), slot)

    def _tick(self, now, slot):
        policy, adapter = self.policy, self.adapter
        record = self.journal.load()
        # Caller supplies the current validated slot, including prices in the hold
        # band. None means a retrieval/validation failure or no current rate.
        valid_slot = False
        if slot is not None:
            try:
                a, b = utc(slot['start']), utc(slot['end'])
                valid_slot = (a <= now < b and b-a == timedelta(minutes=30)
                              and price_requests_heat(slot['price'], policy,
                                  record is not None and a <= utc(datetime.fromisoformat(record['expires']))))
            except (ValueError, TypeError, KeyError):
                valid_slot = False
        safe_temperature = False
        if policy.enabled and valid_slot:
            try:
                temperature, observed = adapter.temperature()
                age = (now - utc(observed)).total_seconds()
                safe_temperature = (0 <= age <= policy.sensor_age_s
                                    and -30 <= number(temperature) < min(policy.target_c, policy.limit_c))
            except Exception:
                # Sensor/network failure removes boost permission; restore below.
                safe_temperature = False
        allowed = policy.enabled and valid_slot and safe_temperature

        if record:
            current = adapter.read()  # Failure leaves journal intact for retry.
            if current == record['previous']:
                self.journal.clear()  # Write never happened, or server expired it.
                # An expired lease can continue in the hold band, with fresh checks.
                if not allowed or now < utc(datetime.fromisoformat(record['expires'])):
                    return 'previous state confirmed'
            elif current != record['boost']:
                # An occupant or another controller took ownership. Do not undo it.
                self.journal.clear()
                return 'external change preserved'
            else:
                if allowed and now < utc(datetime.fromisoformat(record['expires'])):
                    return 'boost active'
                adapter.write(record['boost'], record['previous'], record['operation_id'] + ':restore')
                if adapter.read() != record['previous']:
                    raise RuntimeError('Restore not verified; recovery journal retained')
                self.journal.clear()
                if not allowed:
                    return 'previous state restored'
                # Renew only to the new slot boundary, preserving the prior strategy.

        if not allowed:
            return 'no boost'
        if not adapter.server_expiry_verified:
            raise RuntimeError('Native automatic expiry is unverified; live boost refused')
        from uuid import uuid4
        operation_id = uuid4().hex
        previous = adapter.read()
        expires = utc(slot['end'])
        boost = adapter.make_boost(previous, policy.target_c, expires, operation_id)
        if boost == previous:
            return 'already at requested state'
        # Persist intent BEFORE the request: a timeout may mean it succeeded.
        self.journal.save(dict(previous=previous, boost=boost,
                               expires=expires.isoformat(), operation_id=operation_id))
        adapter.write(previous, boost, operation_id)
        if adapter.read() != boost:
            raise RuntimeError('Boost not verified; recovery journal retained')
        return 'boost started'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--env-file', type=Path, default=Path(__file__).with_name('homely.env'))
    parser.add_argument('--profile')
    parser.add_argument('--date', type=date.fromisoformat, help='Installation-local date (default today)')
    parser.add_argument('--live', action='store_true', help='Reserved; always refused until API verified')
    args = parser.parse_args(argv)
    if args.live:
        parser.error('Live heating disabled: write, sensor and automatic-expiry API contracts are unverified')
    from homely import Config, HomelyClient, homely_login, fetch_agile_prices
    config = Config(args.env_file, args.profile)
    policy = Policy.from_config(config)
    client = HomelyClient(homely_login(config)['access_token'])
    client.discover_identity()
    client.get_settings()
    tz = ZoneInfo(client.timezone_name)
    day = args.date or datetime.now(tz).date()
    slots = fetch_agile_prices(config.get('OCTOPUS_PRODUCT'), config.get('OCTOPUS_TARIFF'), day, tz)
    candidates = eligible_slots(slots, day, tz, policy)
    print('PLAN ONLY — live heating disabled; no heating/DHW writes or emails')
    print(f'Raw import: on <= {policy.on_price_p:g}, off > {policy.off_price_p:g} p/kWh; target {policy.target_c:g} C; room limit {policy.limit_c:g} C')
    print('Between the on and off prices, retain the current heating decision. Listed slots are start candidates only.')
    print('Temperature eligibility unknown until a verified fresh sensor is available.')
    for slot in candidates:
        print(f"{slot['start'].isoformat()} to {slot['end'].isoformat()}: {slot['price']:g} p/kWh")
    print(f'{len(candidates)} qualifying half-hours out of {len(slots)}')


if __name__ == '__main__':
    main()
