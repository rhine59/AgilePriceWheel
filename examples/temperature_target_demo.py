#!/usr/bin/env python3
"""Narrated offline rehearsal of the captured schedule-target edit and restoration.

No credentials, HTTP requests, equipment controls or changes to the real policy.
"""
import copy
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from controller.schedule_target import plan_target, plan_period, readback_state, restoration_payload, ScheduleConflict


def main():
    original = dict(schedules=dict(heating=[dict(id='example-schedule', name='Synthetic example', data=[
        dict(id='example-day-'+str(day), weekdayId=day, start=300, end=960, temperature=16)
        for day in range(7)])], hotwater=['unchanged']))
    print('Offline use case: rehearse the observed 16 C -> 22 C -> 16 C edit.')
    print('The supplied identities and weekly schedule are synthetic, not a live payload.')
    plan = plan_target(original, 'example-schedule', 'example-day-1', 22, heating_disabled=True)
    print('1. Plan setHeatingSchedule: preserve all seven entries, names, IDs and times; change one target.')
    print('2. An HTTP 200/null response alone would not prove the target changed.')
    print('   A baseline read currently classifies as:', readback_state(plan, original))
    changed = copy.deepcopy(original)
    changed['schedules']['heating'][0] = plan.change_payload['schedule']
    print('3. Fake independent readback classifies as:', readback_state(plan, changed))
    restore = restoration_payload(plan, changed, heating_disabled=True)
    restored = copy.deepcopy(changed); restored['schedules']['heating'][0] = restore['schedule']
    assert restored == original
    print('4. Restore the exact original heating schedule; hot-water data stays unchanged.')
    assert restoration_payload(plan, restored, heating_disabled=True) is None
    print('5. A repeated restoration is a no-op; do not replay a write.')
    changed['schedules']['heating'][0]['data'][0]['temperature'] = 18
    try:
        restoration_payload(plan, changed, heating_disabled=True)
    except ScheduleConflict:
        print('6. A concurrent edit is preserved; automatic restoration is refused.')
    else:
        raise RuntimeError('Expected external edit to block restoration')
    period = plan_period(original, 'example-schedule', 'synthetic-new-period', 1, 960, 1020, 22, heating_disabled=True)
    added = copy.deepcopy(original); added['schedules']['heating'][0] = period.change_payload['schedule']
    assert len(added['schedules']['heating'][0]['data']) == 8
    removed = restoration_payload(period, added, heating_disabled=True)
    assert removed['schedule'] == original['schedules']['heating'][0]
    print('7. Add a synthetic one-hour period, then remove it without changing any original entry.')
    print('   One hour is the schedule editor minimum; no actual heating is requested.')
    print('No timed 22 C boost, physical ceiling, expiry, crash recovery or live ownership is claimed.')
    print('Production continues to reject setHeatingSchedule; this is offline planning only.')


if __name__ == '__main__':
    main()
