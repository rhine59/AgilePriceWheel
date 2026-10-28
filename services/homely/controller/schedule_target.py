"""Offline planner for the captured whole-schedule temperature edit.

No network, actuator, timer, write permission or production integration. A future
controller still needs a reviewed lifecycle and crash/restore journal. This module
does not establish a timed boost target or a physical room-temperature ceiling.
"""
from dataclasses import dataclass
import copy
import json
import math


class ScheduleConflict(ValueError):
    """The fresh heating schedule no longer matches the planned state."""


def _json(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False)


def _heating(document):
    if not isinstance(document, dict) or not isinstance(document.get('schedules'), dict):
        raise ValueError('Expected getAllSchedules response')
    schedules = document['schedules'].get('heating')
    if not isinstance(schedules, list) or not schedules:
        raise ValueError('No heating schedules')
    identities = []
    for schedule in schedules:
        if (not isinstance(schedule, dict) or not isinstance(schedule.get('id'), str)
                or not schedule['id'] or not isinstance(schedule.get('name'), str)
                or not isinstance(schedule.get('data'), list)):
            raise ValueError('Unexpected heating schedule')
        identities.append(schedule['id'])
        rows = []
        for row in schedule['data']:
            if (not isinstance(row, dict) or not isinstance(row.get('id'), str) or not row['id']
                    or type(row.get('start')) is not int or type(row.get('end')) is not int
                    or not 0 <= row['start'] < row['end'] <= 1440
                    or type(row.get('weekdayId')) is not int or not 0 <= row['weekdayId'] <= 6
                    or type(row.get('temperature')) not in (int, float)
                    or not math.isfinite(row['temperature'])):
                raise ValueError('Unexpected heating entry')
            rows.append(row['id'])
        if len(set(rows)) != len(rows):
            raise ValueError('Duplicate heating entry identity')
    if len(set(identities)) != len(identities):
        raise ValueError('Duplicate heating schedule identity')
    _json(schedules)  # Reject non-JSON or nonfinite unknown fields too.
    return schedules


def _disabled(value):
    if value is not True:
        raise ValueError('Confirm heating disabled before planning a schedule write')


@dataclass(frozen=True)
class TargetPlan:
    schedule_id: str
    row_id: str
    _before: str
    _after: str
    _others: str

    @property
    def change_payload(self):
        return dict(scheduleId=self.schedule_id, schedule=json.loads(self._after))


def plan_target(document, schedule_id, row_id, target_c, *, heating_disabled):
    """Change exactly one existing row, preserving the complete schedule object."""
    _disabled(heating_disabled)
    if type(target_c) not in (int, float) or not math.isfinite(target_c) or not 5 <= target_c <= 25:
        raise ValueError('Target must be a finite number from 5 through 25 C')
    heating = _heating(document)
    matches = [s for s in heating if s['id'] == schedule_id]
    if len(matches) != 1:
        raise ValueError('Select an existing schedule by identity')
    before = matches[0]
    after = copy.deepcopy(before)
    rows = [r for r in after['data'] if r['id'] == row_id]
    if len(rows) != 1:
        raise ValueError('Select an existing entry by identity')
    if rows[0]['temperature'] == target_c:
        raise ValueError('Target is already set; no write is needed')
    rows[0]['temperature'] = target_c
    return TargetPlan(schedule_id, row_id, _json(before), _json(after),
                      _json([s for s in heating if s['id'] != schedule_id]))



def plan_period(document, schedule_id, row_id, weekday_id, start, end, target_c, *, heating_disabled):
    """Offline rehearsal of the captured add/remove whole-schedule replacement.

    The caller supplies an explicit unused identity. Its generation contract is
    not established for live use. Enforce the phone editor's reported one-hour
    minimum conservatively; the server's minimum is not independently proven.
    Minutes are local schedule values, not a UTC slot/DST conversion.
    """
    _disabled(heating_disabled)
    heating = _heating(document)
    matches = [s for s in heating if s['id'] == schedule_id]
    if len(matches) != 1:
        raise ValueError('Select an existing schedule by identity')
    if (not isinstance(row_id, str) or not row_id
            or any(row['id'] == row_id for schedule in heating for row in schedule['data'])):
        raise ValueError('Supply an explicit unused entry identity')
    if type(weekday_id) is not int or not 0 <= weekday_id <= 6:
        raise ValueError('Invalid weekday')
    if type(start) is not int or type(end) is not int or not 0 <= start < end <= 1440 or end-start < 60:
        raise ValueError('Use at least one hour within a local calendar day')
    if type(target_c) not in (int, float) or not math.isfinite(target_c) or not 5 <= target_c <= 25:
        raise ValueError('Target must be a finite number from 5 through 25 C')
    before = matches[0]
    if any(r['weekdayId'] == weekday_id and start < r['end'] and end > r['start'] for r in before['data']):
        raise ValueError('New period overlaps an existing entry')
    after = copy.deepcopy(before)
    after['data'].append(dict(id=row_id, weekdayId=weekday_id, start=start, end=end, temperature=target_c))
    return TargetPlan(schedule_id, row_id, _json(before), _json(after),
                      _json([s for s in heating if s['id'] != schedule_id]))


def readback_state(plan, document):
    """Compare a fresh read; a null write response never counts as verification."""
    heating = _heating(document)
    matches = [s for s in heating if s['id'] == plan.schedule_id]
    if len(matches) != 1:
        return 'conflict'
    current = _json(matches[0])
    if current == plan._before:
        return 'baseline'
    if current == plan._after and _json([s for s in heating if s['id'] != plan.schedule_id]) == plan._others:
        return 'changed'
    return 'conflict'


def restoration_payload(plan, document, *, heating_disabled):
    """Return the original selected schedule only if the fresh state is expected.

    None means already restored: a caller must not send another write. A mismatch
    raises rather than overwriting an external edit. Read/compare/write is not
    atomic and cannot remove the Homely API's concurrent-writer race.
    """
    _disabled(heating_disabled)
    state = readback_state(plan, document)
    if state == 'baseline':
        return None
    if state != 'changed':
        raise ScheduleConflict('Heating schedule changed; preserve external changes')
    return dict(scheduleId=plan.schedule_id, schedule=json.loads(plan._before))
