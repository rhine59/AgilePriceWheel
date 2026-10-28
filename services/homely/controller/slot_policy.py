"""Price-only half-hour decisions used by the gated native-boost driver.

This module makes no Homely calls; slot_control applies its decisions. A fresh
process waits for a boundary; it never starts a fresh 30-minute boost mid-slot.
"""
from datetime import datetime, timezone
import math

UTC = timezone.utc


def timestamp(value):
    value = datetime.fromisoformat(value) if isinstance(value, str) else value
    if value.tzinfo is None or value.utcoffset() is None:
        raise ValueError('An explicit timezone is required')
    return value.astimezone(UTC).timestamp()


class SlotPolicy:
    """Latch one price decision per UTC slot; fail closed until the next slot.

    Forecast refreshes cannot extend/restart a boost or change a latched decision.
    Price/forecast loss or a policy edit stops permission immediately. Subsequent
    recovery waits for the next boundary. DST folds are distinct UTC intervals.
    The caller must separately enforce native expiry, ownership and write gates.
    """
    def __init__(self, boundary_grace_s=15):
        if not 0 <= boundary_grace_s <= 30:
            raise ValueError('Boundary grace must be at most 30 seconds')
        self.grace = boundary_grace_s
        self.slot = None
        self.revision = None
        self.allowed = False
        self.end = None
        self.last_now = None
        self.decided_price = None
        self.phase = 'waiting_for_boundary'

    def evaluate(self, now, current, policy, revision, *, stale=False):
        now = timestamp(now)
        backwards = self.last_now is not None and now < self.last_now
        self.last_now = now
        start = math.floor(now / 1800) * 1800
        end = start + 1800
        changed = self.revision is not None and revision != self.revision
        previous = self.allowed and self.end == start
        new_slot = start != self.slot
        if new_slot:
            self.slot = start
            self.allowed = False
            self.decided_price = None
            self.phase = 'waiting_for_boundary'
        self.revision = revision
        try:
            price = current['effective_price_p']
            on, off = policy['on_price_p'], policy['off_price_p']
            if (any(type(v) not in (int, float) or not math.isfinite(v) for v in (price, on, off))
                    or off < on or timestamp(current['start']) != start
                    or timestamp(current['end']) != end):
                raise ValueError('Invalid current slot')
            valid = not stale and not backwards
        except (KeyError, TypeError, ValueError, AttributeError, OverflowError):
            valid = False
        if not valid or changed:
            self.allowed = False
            self.phase = 'unavailable' if not valid else 'policy_changed_wait_boundary'
        elif new_slot and now - start <= self.grace:
            self.allowed = price <= (off if previous else on)
            self.decided_price = price
            self.phase = 'boost_permitted' if self.allowed else 'price_off'
        # The same-slot branch deliberately never recovers an invalidated decision.
        self.end = end
        return dict(action='boost' if self.allowed else 'off', phase=self.phase,
                    price_allowed=self.allowed, decision_price_p=self.decided_price,
                    slot_start=datetime.fromtimestamp(start, UTC).isoformat(),
                    slot_end=datetime.fromtimestamp(end, UTC).isoformat(),
                    policy_revision=revision)
