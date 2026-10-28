"""Probe lifecycle rehearsals only: fake equipment, no credentials or requests."""
from datetime import datetime,timedelta,timezone
import copy,unittest
from controller.boost_target_probe import probe
UTC=timezone.utc
class Timer:
    def __init__(self,seconds,callback):self.callback=callback;self.cancelled=False
    def start(self):pass
    def cancel(self):self.cancelled=True
class Fake:
    zone_id='0'
    def __init__(self):
        self.disabled=True;self.boost=[];self.writes=[];self.notes=[];self.target=22;self.seconds=0;self.fail=None;self.timer=None
    def preflight(self):
        if self.fail=='preflight':raise ValueError('Not ready')
    def context_unchanged(self):
        if self.fail=='context' and self.writes:raise ValueError('Policy or hold changed')
    def note(self,event,**fields):self.notes.append((event,fields))
    def is_disabled(self):return self.disabled
    def read_boost(self):return copy.deepcopy(self.boost)
    def enable(self):
        self.writes.append('enable');self.disabled=False
        if self.fail=='enable_timeout':raise TimeoutError()
        if self.fail=='generated':self.boost=[dict(zoneId=0,end=1)]
        if self.fail=='deadline':self.seconds=61
        if self.fail=='watchdog':self.timer.callback()
    def start(self,first,last):
        self.writes.append('start');self.boost=[dict(zoneId=0,end=int(last.timestamp()*1000))]
        if self.fail=='start_timeout':raise TimeoutError()
        if self.fail=='bad_readback':self.boost[0]['end']+=1
        return dict(boostActive=True,zoneId='0',start=int(first.timestamp()*1000),end=int(last.timestamp()*1000),temperature=self.target,min=self.target,max=self.target)
    def cancel(self):self.writes.append('cancel');self.boost=[]
    def stop_only(self):
        self.writes.append('disable');self.disabled=True
        if self.fail=='stop_failure':raise TimeoutError()
        self.cancel()
    def timer_factory(self,seconds,callback):self.timer=Timer(seconds,callback);return self.timer
class ProbeTests(unittest.TestCase):
    def setUp(self):self.api=Fake()
    def run_probe(self,**kwargs):
        return probe(self.api,authorised=True,clock=lambda:datetime(2026,10,27,18,5,tzinfo=UTC),monotonic=lambda:self.api.seconds,timer_factory=self.api.timer_factory,**kwargs)
    def test_default_refuses_writes_without_approval(self):
        with self.assertRaises(ValueError):probe(self.api)
        self.assertEqual(self.api.writes,[])
    def test_target22_is_observed_then_immediately_stopped(self):
        result=self.run_probe();self.assertTrue(result['returned_target_matches_22']);self.assertTrue(result['stop_confirmed']);self.assertTrue(self.api.timer.cancelled)
        self.assertFalse(result['physical_temperature_ceiling_verified']);self.assertTrue(result['schedule_restoration_pending'])
        self.assertEqual(self.api.writes,['enable','start','disable','cancel'])
    def test_target20_is_valid_negative_evidence_not_successful22(self):
        self.api.target=20;r=self.run_probe();self.assertEqual(r['returned_target_c'],20);self.assertFalse(r['returned_target_matches_22']);self.assertTrue(r['stop_confirmed'])
    def test_lost_enable_response_is_stopped_without_start(self):
        self.api.fail='enable_timeout';r=self.run_probe();self.assertTrue(r['stop_confirmed']);self.assertNotIn('start',self.api.writes)
    def test_lost_start_response_is_not_replayed(self):
        self.api.fail='start_timeout';r=self.run_probe();self.assertEqual(self.api.writes.count('start'),1);self.assertTrue(r['stop_confirmed'])
    def test_policy_or_hold_change_stops_before_boost(self):
        self.api.fail='context';r=self.run_probe();self.assertNotIn('start',self.api.writes);self.assertTrue(r['stop_confirmed'])
    def test_elapsed_deadline_prevents_late_start(self):
        self.api.fail='deadline';r=self.run_probe();self.assertNotIn('start',self.api.writes);self.assertTrue(r['stop_confirmed'])
    def test_watchdog_only_stops_and_prevents_new_start(self):
        self.api.fail='watchdog';r=self.run_probe();self.assertTrue(r['watchdog_fired']);self.assertNotIn('start',self.api.writes);self.assertTrue(r['stop_confirmed'])
    def test_enable_generated_boost_is_cancelled_before_explicit_start(self):
        self.api.fail='generated';r=self.run_probe();self.assertTrue(r['boost_readback_verified']);self.assertLess(self.api.writes.index('cancel'),self.api.writes.index('start'))
    def test_wrong_readback_cannot_be_called_verified(self):
        self.api.fail='bad_readback';r=self.run_probe();self.assertFalse(r['boost_readback_verified']);self.assertTrue(r['stop_confirmed'])
    def test_failed_cleanup_leaves_stop_timer_armed(self):
        self.api.fail='stop_failure';r=self.run_probe();self.assertFalse(r['stop_confirmed']);self.assertFalse(self.api.timer.cancelled)
    def test_failed_preflight_never_arms_or_writes(self):
        self.api.fail='preflight'
        with self.assertRaises(ValueError):self.run_probe()
        self.assertEqual(self.api.writes,[]);self.assertIsNone(self.api.timer)
    def test_invalid_stop_budget_is_rejected(self):
        for seconds in [0,61,True,float('nan')]:
            with self.assertRaises(ValueError):self.run_probe(maximum_seconds=seconds)
        self.assertEqual(self.api.writes,[])

    def test_trace_failure_cannot_prevent_cleanup(self):
        original=self.api.note
        def note(event,**fields):
            if event=='stop_intent':raise OSError('disk full')
            return original(event,**fields)
        self.api.note=note;r=self.run_probe();self.assertTrue(r['trace_error']);self.assertTrue(r['stop_confirmed'])

    def test_context_request_cannot_allow_enable_after_deadline(self):
        def slow_context():self.api.seconds=61
        self.api.context_unchanged=slow_context;r=self.run_probe()
        self.assertNotIn('enable',self.api.writes);self.assertTrue(r['stop_confirmed'])
