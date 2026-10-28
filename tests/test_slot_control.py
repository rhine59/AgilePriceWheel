"""Native price-only driver tests. No live credentials, cloud or heating calls."""
import copy,json,tempfile,unittest
from unittest.mock import patch
from datetime import datetime,timedelta,timezone
from pathlib import Path
from controller.service import State
from controller.slot_control import SlotSupervisor,installation_identity
UTC=timezone.utc
NOW=datetime(2026,10,25,12,tzinfo=UTC)

class FakeHomely:
 profile='test';house_id='test-house';boost_zone_id='0'
 def __init__(self,clock):
  self.clock=clock;self.allow_writes=False;self.disabled=True;self.active=None
  self.settings={'hotWaterOnlyMode':True,'optimisationType':'normal','hwSetPoint':'50'}
  self.schedules={'schedules':{'heating':[{'temperature':20}],'temporary':[{'min':18,'max':22}], 'hotwater':[{'start':600}]}}
  self.baseline=[dict(zoneId=0,start=0,end=0,min=18,max=22,temperature=20)]
  self.writes=[];self.fail=None;self.sensor_fail=False;self.read_fail=False
 def observe(self,now):
  if self.sensor_fail:raise RuntimeError('private telemetry error')
  return dict(disabled=self.disabled,reported_heating_on=not self.disabled,room_c=99,observed_at=NOW.isoformat(),sensor_age_s=9999,sensor_candidate_fresh=False,sensor_contract_verified=False)
 def call(self,method):
  if self.read_fail:raise TimeoutError('private API error')
  if self.active and self.clock()>=datetime.fromtimestamp(self.active['end']/1000,UTC):self.active=None
  if method=='getSettings':return dict(copy.deepcopy(self.settings),hotWaterOnlyMode=self.disabled)
  if method=='getAllSchedules':return copy.deepcopy(self.schedules)
  if method=='getHeatingBoost':return [copy.deepcopy(self.active)] if self.active else copy.deepcopy(self.baseline)
  raise AssertionError(method)
 def set_disabled(self,value):
  assert self.allow_writes or (getattr(self,'allow_stop',False) and value is True)
  self.writes.append(('disabled',value));self.disabled=value
  self.schedules['schedules']['temporary']=[dict(min=16 if value else 18,max=22)]
  if self.fail=='mode_timeout':self.fail=None;raise TimeoutError('private timeout')
 def start_boost(self,start,end):
  assert self.allow_writes
  self.writes.append(('boost',int(end.timestamp()*1000)))
  self.active=dict(zoneId=0,end=int(end.timestamp()*1000))
  if self.fail=='start_timeout':self.fail=None;raise TimeoutError('private timeout')
  if self.fail=='crash_after_start':raise KeyboardInterrupt()
 def cancel_boost(self):
  assert self.allow_writes or getattr(self,'allow_stop',False)
  self.writes.append(('cancel',False))
  if self.fail=='cancel_timeout':self.fail=None;raise TimeoutError('private timeout')
  self.active=None

class SlotControlTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
  self.now=NOW;self.state=State(self.root/'policy.json');self.state.automation.save(True);self.api=FakeHomely(lambda:self.now)
  self.path=self.root/'recovery.json';self.proof=self.root/'native-expiry-proof.json'
  self.proof.write_text(json.dumps(dict(version=1,identity=installation_identity(self.api),native_expiry_records_verified=True,slot_seconds=1800)))
  self.driver=self.make();self.state.control=self.driver
 def make(self,requested=True):return SlotSupervisor(self.state,self.path,observer=self.api,requested=requested,proof_path=self.proof,clock=lambda:self.now)
 def publish(self,price=0):
  start=self.now.replace(minute=self.now.minute//30*30,second=0,microsecond=0)
  self.state.publish(self.state.revision,[dict(start=start.isoformat(),end=(start+timedelta(minutes=30)).isoformat(),effective_price_p=price)],self.now)
 def step(self,price=0):self.publish(price);return self.driver.step()
 def test_gate_false_never_writes_even_with_matching_proof(self):
  self.driver=self.make(False);r=self.step();self.assertFalse(r['control_enabled']);self.assertFalse(self.api.allow_writes);self.assertEqual(self.api.writes,[])
 def test_proof_missing_or_wrong_installation_never_writes(self):
  for proof in [None,dict(version=1,identity='other',native_expiry_records_verified=True,slot_seconds=1800)]:
   if proof is None:self.proof.unlink(missing_ok=True)
   else:self.proof.write_text(json.dumps(proof))
   self.assertFalse(self.step()['control_enabled']);self.assertEqual(self.api.writes,[])
 def test_start_and_no_mid_slot_renewal_no_temperature_gate(self):
  self.assertEqual(self.step()['phase'],'boost_active');writes=copy.deepcopy(self.api.writes)
  self.now+=timedelta(minutes=5);self.assertEqual(self.step(100)['phase'],'boost_active');self.assertEqual(self.api.writes,writes)
  self.assertEqual(writes,[('disabled',False),('boost',int((NOW+timedelta(minutes=30)).timestamp()*1000))])
 def test_consecutive_slots_renew_once_and_above_off_disables(self):
  doc=self.state.document();doc['policy'].update(on_price_p=-5,off_price_p=-1);self.state.update(doc)
  self.assertEqual(self.step(-5)['phase'],'boost_active')
  self.now+=timedelta(minutes=30);self.assertEqual(self.step(-1)['phase'],'boost_active')
  self.now+=timedelta(minutes=30);self.assertEqual(self.step(0)['phase'],'heating_off');self.assertTrue(self.api.disabled)
  self.assertEqual(len([w for w in self.api.writes if w[0]=='boost']),2)
 def test_off_price_disables_existing_normal_heating(self):
  self.api.disabled=False;self.assertEqual(self.step(1)['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_startup_mid_slot_waits_and_keeps_heating_off(self):
  self.now+=timedelta(minutes=2);self.assertEqual(self.step()['phase'],'heating_off');self.assertEqual(self.api.writes,[])
 def test_price_failure_cancels_owned_boost_and_disables(self):
  self.step();self.now+=timedelta(minutes=1);self.state.snapshot=None
  r=self.driver.step();self.assertEqual(r['phase'],'heating_off');self.assertTrue(self.api.disabled);self.assertIsNone(self.api.active)
  self.now+=timedelta(seconds=1);self.step();self.assertEqual(len([w for w in self.api.writes if w[0]=='boost']),1)
 def test_stale_or_missing_temperature_does_not_block_price_driver(self):
  self.api.sensor_fail=True;self.assertEqual(self.step()['phase'],'boost_active')
 def test_lost_start_response_is_not_replayed_and_is_reconciled(self):
  self.api.fail='start_timeout';r=self.step();self.assertTrue(r['recovery_pending']);self.assertNotIn('private timeout',str(r))
  self.now+=timedelta(seconds=1);self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
  self.assertEqual(len([w for w in self.api.writes if w[0]=='boost']),1)
 def test_uncertain_enable_is_reconciled_to_disabled(self):
  self.api.fail='mode_timeout';self.assertTrue(self.step()['recovery_pending'])
  self.now+=timedelta(seconds=1);self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_restart_recovers_before_any_new_start(self):
  self.step();self.driver=self.make();self.state.control=self.driver
  self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
  self.assertEqual(len([w for w in self.api.writes if w[0]=='boost']),1)
 def test_crash_after_start_recovers_from_persisted_intent(self):
  self.api.fail='crash_after_start'
  with self.assertRaises(KeyboardInterrupt):self.step()
  self.api.fail=None;self.driver=self.make();self.state.control=self.driver
  self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_manual_off_is_preserved_and_hold_survives_restart(self):
  self.step();self.api.disabled=True;self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'manual_change_hold');self.assertTrue(self.api.disabled)
  self.driver=self.make();self.state.control=self.driver
  self.assertEqual(self.step()['phase'],'manual_change_hold');self.assertTrue(self.api.disabled)
 def test_manual_new_boost_is_not_cancelled(self):
  self.step();self.api.active['end']+=60000;self.now+=timedelta(seconds=1);writes=len(self.api.writes)
  self.assertEqual(self.step()['phase'],'manual_change_hold');self.assertEqual(len(self.api.writes),writes)
 def test_manual_normal_mode_change_is_not_fought(self):
  self.step(1);self.api.disabled=False;self.now+=timedelta(seconds=1)
  self.assertEqual(self.step(1)['phase'],'manual_change_hold');self.assertFalse(self.api.disabled)
 def test_hot_water_schedule_and_setpoint_changes_are_ignored(self):
  self.step();self.api.schedules['schedules']['hotwater']=[{'start':123}];self.api.settings['hwSetPoint']='55';self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'boost_active')
 def test_manual_temperature_change_cancels_owned_boost_and_holds(self):
  self.step();self.api.schedules['schedules']['temporary']=[dict(min=19,max=21)];self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'manual_change_hold');self.assertIsNone(self.api.active)
  self.assertEqual(self.api.schedules['schedules']['temporary'],[dict(min=19,max=21)])
 def test_policy_save_stops_active_boost(self):
  self.step();self.state.update(self.state.document());self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_hold_rearms_only_after_policy_revision_changes(self):
  self.step(1);self.api.disabled=False;self.now+=timedelta(seconds=1);self.step(1)
  self.state.update(self.state.document());self.now+=timedelta(seconds=1)
  self.assertEqual(self.step(1)['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_cancel_failure_retains_lease_for_reconciled_retry(self):
  self.step();self.api.fail='cancel_timeout';self.state.snapshot=None;self.now+=timedelta(seconds=1)
  self.assertTrue(self.driver.step()['recovery_pending']);self.assertTrue(self.driver.store.load()['lease'])
  self.now+=timedelta(seconds=1);self.assertEqual(self.driver.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_api_read_failure_cannot_start_and_retains_recovery(self):
  self.step();self.api.read_fail=True;self.now+=timedelta(seconds=1);n=len(self.api.writes)
  r=self.step();self.assertTrue(r['recovery_pending']);self.assertEqual(len(self.api.writes),n)
  self.api.read_fail=False;self.now+=timedelta(seconds=1);self.assertEqual(self.step()['phase'],'heating_off')
 def test_corrupt_or_wrong_identity_store_is_retained(self):
  self.driver.store.path.write_text('corrupt');r=self.step();self.assertEqual(r['phase'],'recovery_required');self.assertEqual(self.api.writes,[]);self.assertEqual(self.driver.store.path.read_text(),'corrupt')
 def test_disabled_configuration_never_recovers_by_writing(self):
  self.step();n=len(self.api.writes);self.driver=self.make(False);self.state.control=self.driver
  r=self.step();self.assertTrue(r['recovery_pending']);self.assertEqual(len(self.api.writes),n)
 def test_ledger_is_private_and_status_has_no_identifiers(self):
  self.step();self.assertEqual(self.driver.store.path.stat().st_mode&0o777,0o600)
  r=str(self.driver.status());self.assertNotIn('test-house',r);self.assertNotIn('test-user',r)
 def test_status_get_never_writes_heating(self):
  self.step();n=len(self.api.writes)
  self.state.status(self.now);self.state.status(self.now);self.assertEqual(len(self.api.writes),n)
 def test_cancel_failure_still_attempts_disable_before_returning(self):
  self.step();self.api.fail='cancel_timeout';self.state.snapshot=None;self.now+=timedelta(seconds=1)
  self.assertTrue(self.driver.step()['recovery_pending']);self.assertTrue(self.api.disabled)
 def test_manual_cancel_failure_reconciles_without_disabling_normal_mode(self):
  self.step();self.api.schedules['schedules']['temporary']=[dict(min=19,max=21)];self.api.fail='cancel_timeout';self.now+=timedelta(seconds=1)
  self.assertTrue(self.step()['recovery_pending']);self.assertFalse(self.api.disabled)
  self.now+=timedelta(seconds=1);r=self.step();self.assertEqual(r['phase'],'manual_change_hold');self.assertIsNone(self.api.active);self.assertFalse(self.api.disabled)
 def test_full_existing_temperature_override_is_preserved(self):
  self.api.baseline[0]['end']=9999999999999
  self.assertEqual(self.step()['phase'],'boost_active')
  self.assertEqual(self.api.baseline[0]['temperature'],20)
 def test_uncertain_disable_is_read_back_without_reenabling_or_restarting(self):
  self.step();self.api.fail='mode_timeout';self.state.snapshot=None;self.now+=timedelta(seconds=1)
  self.assertTrue(self.driver.step()['recovery_pending']);self.assertTrue(self.api.disabled)
  self.now+=timedelta(seconds=1);self.assertEqual(self.driver.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
 def test_enable_generated_boost_is_cancelled_then_replaced_with_slot_end(self):
  original=self.api.set_disabled
  def enable(value):
   original(value)
   if not value:self.api.active=dict(zoneId=0,end=int((self.now+timedelta(hours=1)).timestamp()*1000))
  self.api.set_disabled=enable
  self.assertEqual(self.step()['phase'],'boost_active')
  self.assertEqual(self.api.writes[1],('cancel',False))
  self.assertEqual(self.api.active['end'],int((NOW+timedelta(minutes=30)).timestamp()*1000))
 def test_uncertain_enable_generated_boost_is_stopped_not_replayed(self):
  original=self.api.set_disabled
  def enable(value):
   original(value)
   if not value:
    self.api.active=dict(zoneId=0,end=int((self.now+timedelta(hours=1)).timestamp()*1000));raise TimeoutError()
  self.api.set_disabled=enable
  self.assertTrue(self.step()['recovery_pending']);self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled);self.assertIsNone(self.api.active)
  self.assertFalse(any(w[0]=='boost' for w in self.api.writes))
 def test_latency_before_start_disables_already_enabled_normal_heating(self):
  self.api.disabled=False;original=self.api.observe
  def slow(now):
   self.now+=timedelta(seconds=16);return original(now)
  self.api.observe=slow
  self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
  self.assertFalse(any(w[0]=='boost' for w in self.api.writes))
 def test_slow_enable_finishes_boundary_attempt_without_extending_slot(self):
  original=self.api.set_disabled
  def slow(value):
   original(value)
   if not value:self.now+=timedelta(seconds=23)
  self.api.set_disabled=slow
  self.assertEqual(self.step()['phase'],'boost_active')
  self.assertEqual(self.api.active['end'],int((NOW+timedelta(minutes=30)).timestamp()*1000))
 def test_setup_over_one_minute_stops_and_logs_timeout(self):
  original=self.api.set_disabled
  def slow(value):
   original(value)
   if not value:self.now+=timedelta(seconds=61)
  self.api.set_disabled=slow
  self.assertEqual(self.step()['phase'],'heating_off');self.assertTrue(self.api.disabled)
  self.assertFalse(any(w[0]=='boost' for w in self.api.writes))
  events=self.state.history.week(now=self.now)['events']
  self.assertEqual(events[0]['reason'],'setup_timeout')
 def test_app_off_cancels_boost_disables_and_survives_restart(self):
  self.step();self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled);self.assertIsNone(self.api.active)
  self.driver=self.make();self.state.control=self.driver;self.now+=timedelta(minutes=30)
  n=len(self.api.writes);self.assertEqual(self.step()['phase'],'automation_off');self.assertEqual(len(self.api.writes),n)
 def test_explicit_app_off_works_with_start_activation_disabled(self):
  self.step();self.driver=self.make(False);self.state.control=self.driver
  self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled);self.assertIsNone(self.api.active)
  self.assertFalse(self.api.allow_writes)
 def test_app_on_is_blocked_when_controller_not_activated(self):
  self.driver=self.make(False);self.state.control=self.driver
  self.state.update_automation({'enabled':False})
  from controller.service import Conflict
  with self.assertRaises(Conflict):self.state.update_automation({'enabled':True})
  self.assertFalse(self.state.automation.load()['enabled'])
 def test_paused_automation_does_not_fight_later_manual_heating(self):
  self.step();self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1);self.step()
  self.api.disabled=False;self.now+=timedelta(seconds=1);n=len(self.api.writes)
  self.step();self.assertFalse(self.api.disabled);self.assertEqual(len(self.api.writes),n)
 def test_on_after_off_waits_for_next_boundary(self):
  self.step();self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1);self.step()
  self.state.update_automation({'enabled':True});self.now+=timedelta(seconds=1);self.step()
  self.assertTrue(self.api.disabled)
  self.now=NOW+timedelta(minutes=30);self.assertEqual(self.step()['phase'],'boost_active')
 def test_off_retries_shutdown_after_failure_without_new_start(self):
  self.step();self.state.update_automation({'enabled':False});self.api.read_fail=True;self.now+=timedelta(seconds=1)
  self.assertTrue(self.step()['shutdown_pending']);self.api.read_fail=False;self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled)
 def test_explicit_off_repairs_corrupt_ledger_without_replaying_start(self):
  self.step();self.driver.store.path.write_text('corrupt');self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled)
  self.assertEqual(self.driver.store.path.with_suffix('.invalid').read_text(),'corrupt')
 def test_default_switch_is_off_and_requires_no_stop_write(self):
  self.state.automation.path.unlink();self.assertEqual(self.step()['phase'],'automation_off');self.assertEqual(self.api.writes,[])
 def test_explicit_off_repairs_nonobject_ledger(self):
  self.step();self.driver.store.path.write_text('null');self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1)
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled)
 def test_status_reflects_saved_off_before_worker_shutdown_finishes(self):
  self.step();self.state.update_automation({'enabled':False})
  r=self.state.status(self.now);self.assertFalse(r['control_enabled']);self.assertFalse(r['price_requests_heat']);self.assertEqual(r['mode'],'plan_only');self.assertTrue(r['automation']['shutdown_pending'])
 def test_policy_revision_change_masks_old_permission_before_stop_ack(self):
  self.step();self.state.update(self.state.document());self.publish(50)
  self.assertFalse(self.state.status(self.now)['price_requests_heat'])
 def test_expired_slot_decision_is_not_advertised_as_current_permission(self):
  self.step();self.now+=timedelta(minutes=30);self.publish(50)
  self.assertFalse(self.state.status(self.now)['price_requests_heat'])
 def test_off_during_observation_prevents_enable_or_boost(self):
  original=self.api.observe
  def stop(now):
   self.state.update_automation({'enabled':False});return original(now)
  self.api.observe=stop
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled);self.assertEqual(self.api.writes,[])
 def test_off_during_enable_prevents_boost_and_reconciles_disabled(self):
  original=self.api.set_disabled
  def stop(value):
   original(value)
   if not value:self.state.update_automation({'enabled':False})
  self.api.set_disabled=stop
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled)
  self.assertFalse(any(w[0]=='boost' for w in self.api.writes))
 def test_off_during_start_cancels_the_inflight_boost(self):
  original=self.api.start_boost
  def stop(start,end):
   original(start,end);self.state.update_automation({'enabled':False})
  self.api.start_boost=stop
  self.assertEqual(self.step()['phase'],'automation_off');self.assertTrue(self.api.disabled);self.assertIsNone(self.api.active)
 def test_history_records_confirmed_on_and_off_once(self):
  self.step();self.now+=timedelta(minutes=30);self.step(50)
  rows=self.state.history.week(now=self.now)['events']
  self.assertEqual([r['state'] for r in rows],['off','on']);self.assertEqual(rows[0]['reason'],'price_above_off')
  self.now+=timedelta(seconds=1);self.step(50);self.assertEqual(len(self.state.history.week(now=self.now)['events']),2)
 def test_boost_renewal_does_not_add_another_heating_on(self):
  self.step();self.now+=timedelta(minutes=30);self.step()
  self.assertEqual(len(self.state.history.week(now=self.now)['events']),1)
 def test_app_off_is_recorded_with_its_reason(self):
  self.step();self.state.update_automation({'enabled':False});self.now+=timedelta(seconds=1);self.step()
  self.assertEqual(self.state.history.week(now=self.now)['events'][0]['reason'],'automation_off')
 def test_already_off_without_a_command_creates_no_history(self):
  self.step(50);self.assertEqual(self.state.history.week(now=self.now)['events'],[])
 def test_history_failure_never_replays_or_blocks_heat_control(self):
  with patch.object(self.state.history,'append',side_effect=OSError('private error')):
   r=self.step();self.assertEqual(r['phase'],'boost_active');self.assertIsNone(r['error']);self.assertTrue(r['history_error'])
  writes=copy.deepcopy(self.api.writes);self.now+=timedelta(seconds=1);r=self.step()
  self.assertIsNone(r['history_error']);self.assertEqual(self.api.writes,writes);self.assertEqual(len(self.state.history.week(now=self.now)['events']),1)
 def test_history_commit_response_loss_deduplicates_outbox_retry(self):
  real=self.state.history.append
  def uncertain(*a,**k):real(*a,**k);raise OSError()
  with patch.object(self.state.history,'append',side_effect=uncertain):self.step()
  self.now+=timedelta(seconds=1);self.step();self.assertEqual(len(self.state.history.week(now=self.now)['events']),1)
 def test_manual_change_is_not_misreported_as_an_automation_off(self):
  self.step();self.api.disabled=True;self.now+=timedelta(seconds=1);self.step()
  self.assertEqual([v['state'] for v in self.state.history.week(now=self.now)['events']],['on'])
 def test_corrupt_history_item_does_not_break_heating_control(self):
  self.step(50);d=self.driver.store.load();d['history_pending']=['broken'];self.driver.store.save(d)
  self.now+=timedelta(minutes=30);r=self.step()
  self.assertEqual(r['phase'],'boost_active');self.assertIsNone(r['error']);self.assertTrue(r['history_error'])

 def test_session_id_survives_slot_renewal_and_off(self):
  self.step();sid=self.driver.store.load()['history_session_id']
  self.now+=timedelta(minutes=30);self.step();self.assertEqual(self.driver.store.load()['history_session_id'],sid)
  self.now+=timedelta(minutes=30);self.step(50)
  session=self.state.history.week(now=self.now)['sessions'][0]
  self.assertEqual(session['id'],sid);self.assertEqual(session['duration_seconds'],3600)
  self.assertEqual(session['estimated_cost_gbp'],0)
 def test_manual_change_does_not_pair_next_session_with_previous(self):
  self.step();sid=self.driver.store.load()['history_session_id'];self.api.disabled=True;self.now+=timedelta(seconds=1);self.step()
  self.assertIsNone(self.driver.store.load()['history_session_id'])
  self.assertIsNone(self.state.history.week(now=self.now)['sessions'][0]['off_at'])

if __name__=='__main__':unittest.main()
