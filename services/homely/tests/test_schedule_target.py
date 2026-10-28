"""Offline regression for the observed schedule-edit contract; no Homely writes."""
import copy
import unittest
from controller.schedule_target import plan_target, plan_period, readback_state, restoration_payload, ScheduleConflict
from controller.heating import ObservedHomely, ControlUnavailable, OBSERVED_WRITES


def baseline():
    return dict(schedules=dict(heating=[dict(id='schedule-a', name='Example', data=[
        dict(id='monday', start=300, end=960, weekdayId=0, temperature=16),
        dict(id='tuesday', start=300, end=960, weekdayId=1, temperature=16, extra='preserve')])],
        hotwater=[dict(id='water', data=['unchanged'])], temporary=[dict(temperature=20)]), zones=1)


class ScheduleTargetTests(unittest.TestCase):
    def setUp(self):
        self.original = baseline()
        self.plan = plan_target(self.original, 'schedule-a', 'tuesday', 22, heating_disabled=True)
        self.changed = copy.deepcopy(self.original)
        self.changed['schedules']['heating'][0] = self.plan.change_payload['schedule']

    def test_full_payload_changes_only_the_selected_temperature(self):
        expected = copy.deepcopy(self.original['schedules']['heating'][0])
        expected['data'][1]['temperature'] = 22
        self.assertEqual(self.plan.change_payload, dict(scheduleId='schedule-a', schedule=expected))
        self.assertEqual(self.original, baseline())

    def test_fresh_changed_readback_can_restore_exact_original(self):
        self.assertEqual(readback_state(self.plan, self.changed), 'changed')
        payload = restoration_payload(self.plan, self.changed, heating_disabled=True)
        self.assertEqual(payload['schedule'], self.original['schedules']['heating'][0])
        restored = copy.deepcopy(self.changed); restored['schedules']['heating'][0] = payload['schedule']
        self.assertEqual(restored, self.original)

    def test_baseline_or_uncertain_write_response_does_not_prove_change(self):
        self.assertEqual(readback_state(self.plan, self.original), 'baseline')
        with self.assertRaises(ValueError):readback_state(self.plan, None)

    def test_already_restored_is_a_noop(self):
        self.assertIsNone(restoration_payload(self.plan, self.original, heating_disabled=True))

    def test_external_temperature_edit_is_preserved(self):
        self.changed['schedules']['heating'][0]['data'][1]['temperature'] = 19
        with self.assertRaises(ScheduleConflict):restoration_payload(self.plan, self.changed, heating_disabled=True)
        self.assertEqual(self.changed['schedules']['heating'][0]['data'][1]['temperature'], 19)

    def test_other_entry_time_change_prevents_restore(self):
        self.changed['schedules']['heating'][0]['data'][0]['start'] = 360
        with self.assertRaises(ScheduleConflict):restoration_payload(self.plan, self.changed, heating_disabled=True)

    def test_other_heating_schedule_change_prevents_restore(self):
        self.changed['schedules']['heating'].append(dict(id='new', name='External', data=[]))
        with self.assertRaises(ScheduleConflict):restoration_payload(self.plan, self.changed, heating_disabled=True)

    def test_hot_water_changes_are_never_overwritten(self):
        self.changed['schedules']['hotwater'] = ['external hot-water edit']
        payload = restoration_payload(self.plan, self.changed, heating_disabled=True)
        self.assertEqual(set(payload), {'scheduleId', 'schedule'})
        self.assertNotIn('hotwater', payload['schedule'])

    def test_mode_must_be_confirmed_disabled(self):
        for value in (False, None, 1, 'true'):
            with self.assertRaises(ValueError):plan_target(self.original, 'schedule-a', 'tuesday', 22, heating_disabled=value)
            with self.assertRaises(ValueError):restoration_payload(self.plan, self.changed, heating_disabled=value)

    def test_invalid_targets_are_rejected(self):
        for value in (True, '22', float('nan'), float('inf'), 4, 26):
            with self.assertRaises(ValueError):plan_target(self.original, 'schedule-a', 'tuesday', value, heating_disabled=True)

    def test_missing_or_duplicate_identities_are_rejected(self):
        with self.assertRaises(ValueError):plan_target(self.original, 'missing', 'tuesday', 22, heating_disabled=True)
        self.original['schedules']['heating'][0]['data'].append(copy.deepcopy(self.original['schedules']['heating'][0]['data'][1]))
        with self.assertRaises(ValueError):plan_target(self.original, 'schedule-a', 'tuesday', 22, heating_disabled=True)

    def test_missing_selected_entry_is_not_recreated(self):
        self.changed['schedules']['heating'][0]['data'].pop()
        with self.assertRaises(ScheduleConflict):restoration_payload(self.plan, self.changed, heating_disabled=True)

    def test_payload_mutation_does_not_change_saved_baseline(self):
        self.plan.change_payload['schedule']['data'].clear()
        self.assertEqual(len(self.plan.change_payload['schedule']['data']), 2)

    def test_production_transport_still_refuses_schedule_write(self):
        self.assertNotIn('setHeatingSchedule', OBSERVED_WRITES)
        observer = ObservedHomely('/not-read', 'example', 'house', 'sensor', '0', allow_writes=True)
        with self.assertRaises(ControlUnavailable):observer.call('setHeatingSchedule', self.plan.change_payload)


class SchedulePeriodTests(unittest.TestCase):
    def setUp(self):
        self.original = baseline()
        self.plan = plan_period(self.original, 'schedule-a', 'synthetic-new-entry', 1, 960, 1020, 22, heating_disabled=True)
        self.changed = copy.deepcopy(self.original)
        self.changed['schedules']['heating'][0] = self.plan.change_payload['schedule']

    def test_add_then_remove_restores_exact_original(self):
        rows = self.plan.change_payload['schedule']['data']
        self.assertEqual(rows[:-1], self.original['schedules']['heating'][0]['data'])
        self.assertEqual(rows[-1], dict(id='synthetic-new-entry', weekdayId=1, start=960, end=1020, temperature=22))
        payload = restoration_payload(self.plan, self.changed, heating_disabled=True)
        restored = copy.deepcopy(self.changed); restored['schedules']['heating'][0] = payload['schedule']
        self.assertEqual(restored, self.original)
        self.assertIsNone(restoration_payload(self.plan, restored, heating_disabled=True))

    def test_refuses_overlapping_entry_but_allows_adjacency(self):
        with self.assertRaises(ValueError):plan_period(self.original, 'schedule-a', 'new', 1, 900, 1020, 22, heating_disabled=True)
        self.assertEqual(readback_state(self.plan, self.changed), 'changed')

    def test_conservative_editor_minimum_is_one_hour(self):
        with self.assertRaises(ValueError):plan_period(self.original, 'schedule-a', 'new', 1, 960, 990, 22, heating_disabled=True)

    def test_invalid_day_time_or_target_does_not_produce_payload(self):
        for day,start,end,target in [(True,960,1020,22),(7,960,1020,22),(1,True,1020,22),(1,1380,1500,22),(1,960,1020,True),(1,960,1020,float('nan'))]:
            with self.assertRaises(ValueError):plan_period(self.original, 'schedule-a', 'new', day, start, end, target, heating_disabled=True)

    def test_reused_or_missing_identity_is_rejected(self):
        for ident in ('tuesday','monday','',None):
            with self.assertRaises(ValueError):plan_period(self.original, 'schedule-a', ident, 1, 960, 1020, 22, heating_disabled=True)

    def test_refuses_added_period_changed_externally(self):
        self.changed['schedules']['heating'][0]['data'][-1]['temperature'] = 23
        with self.assertRaises(ScheduleConflict):restoration_payload(self.plan, self.changed, heating_disabled=True)
        self.assertEqual(self.changed['schedules']['heating'][0]['data'][-1]['temperature'],23)

    def test_refuses_to_erase_another_new_period(self):
        self.changed['schedules']['heating'][0]['data'].append(dict(id='external',weekdayId=1,start=1080,end=1140,temperature=18))
        with self.assertRaises(ScheduleConflict):restoration_payload(self.plan, self.changed, heating_disabled=True)

    def test_no_implicit_arming_or_input_mutation(self):
        with self.assertRaises(ValueError):plan_period(self.original, 'schedule-a', 'new', 1, 960, 1020, 22, heating_disabled=False)
        self.assertEqual(self.original,baseline())
