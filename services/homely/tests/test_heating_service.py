"""Safety integration tests: no live credentials, connections or heating writes."""
import copy
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
from zoneinfo import ZoneInfo

from controller.heating import (ControlUnavailable, ObservedHomely, SafeClient,
                                Supervisor, build_supervisor)
from controller.service import DEFAULT, State, effective_prices, fetch_radiation
from test_heating_boost import Fake, prices

UTC=timezone.utc
NOW=datetime(2026,10,24,12,tzinfo=UTC)


class HeatingServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        self.state=State(self.root/'policy.json')
        self.fake=Fake()
        self.before=self.fake.read()
        self.supervisor=Supervisor(self.state,self.root/'recovery.json',
            adapter=self.fake,identity='test-installation',requested=True)
        self.state.control=self.supervisor

    def publish(self, price=0, now=NOW):
        self.state.publish(self.state.revision,[dict(start=now.isoformat(),
            end=(now+timedelta(minutes=30)).isoformat(),effective_price_p=price)],now)
        self.fake.observed=now

    def test_default_and_flag_cannot_enable_real_control(self):
        for flag in ('false','true'):
            supervisor=build_supervisor(self.state,dict(HEATING_LIVE_ENABLED=flag,
                HEATING_RECOVERY_FILE=str(self.root/'unused.json')))
            self.assertIsNone(supervisor.adapter)
            self.assertFalse(supervisor.step(NOW)['control_enabled'])
        with self.assertRaises(ValueError): build_supervisor(self.state,{'HEATING_LIVE_ENABLED':'yes'})

    def test_hysteresis_effective_price_and_policy_save(self):
        doc=self.state.document();doc['policy']['off_price_p']=5;self.state.update(doc)
        self.publish(3)
        self.assertEqual(self.supervisor.step(NOW)['phase'],'no boost')
        self.publish(0)
        self.assertEqual(self.supervisor.step(NOW)['phase'],'boost started')
        self.publish(5)
        self.assertEqual(self.supervisor.step(NOW)['phase'],'boost active')
        self.publish(5.01)
        self.assertEqual(self.supervisor.step(NOW)['phase'],'previous state restored')
        self.assertEqual(self.fake.state,self.before)
        self.publish(0);self.supervisor.step(NOW)
        self.state.update(self.state.document())
        self.assertEqual(self.supervisor.step(NOW)['phase'],'previous state restored')

    def test_temperature_target_stops_without_claiming_native_setpoint(self):
        self.publish();self.supervisor.step(NOW)
        self.fake.room=DEFAULT['target_c']
        self.assertEqual(self.supervisor.step(NOW)['phase'],'previous state restored')
        self.assertEqual(self.fake.state,self.before)

    def test_stale_sensor_future_sensor_lost_prices_restore(self):
        for cause in ('stale','future','nonfinite','sensor_failure','prices'):
            with self.subTest(cause=cause):
                self.setUp();self.publish();self.supervisor.step(NOW)
                if cause=='stale':self.fake.observed=NOW-timedelta(seconds=121)
                elif cause=='future':self.fake.observed=NOW+timedelta(seconds=1)
                elif cause=='nonfinite':self.fake.room=float('nan')
                elif cause=='sensor_failure':self.fake.fail_sensor=True
                else:self.state.snapshot=None
                self.assertEqual(self.supervisor.step(NOW)['phase'],'previous state restored')
                self.assertEqual(self.fake.state,self.before)

    def test_restart_restores_before_considering_any_new_start(self):
        self.publish();self.supervisor.step(NOW)
        restarted=Supervisor(self.state,self.supervisor.journal.path,
            adapter=self.fake,identity='test-installation',requested=True)
        self.assertEqual(restarted.step(NOW)['phase'],'previous state restored')
        self.assertFalse(restarted.status()['recovery_pending'])
        self.assertEqual(self.fake.state,self.before)
        self.assertEqual(restarted.step(NOW)['phase'],'boost started')

    def test_restore_failure_retries_and_never_loses_recovery(self):
        self.publish();self.supervisor.step(NOW)
        self.fake.fail_write=True;self.state.snapshot=None
        result=self.supervisor.step(NOW)
        self.assertEqual(result['phase'],'recovery_required')
        self.assertTrue(result['recovery_pending'])
        self.fake.fail_write=False
        self.assertEqual(self.supervisor.step(NOW)['phase'],'previous state restored')
        self.assertEqual(self.fake.state,self.before)

    def test_uncertain_start_is_reconciled_after_restart(self):
        self.publish()
        original=self.fake.write
        def timeout(*args):
            original(*args)
            raise TimeoutError('private error must not escape')
        self.fake.write=timeout
        result=self.supervisor.step(NOW)
        self.assertTrue(result['recovery_pending'])
        self.assertNotIn('private error',str(result))
        self.fake.write=original
        restarted=Supervisor(self.state,self.supervisor.journal.path,
            adapter=self.fake,identity='test-installation',requested=False)
        restarted.step(NOW)
        self.assertEqual(self.fake.state,self.before)

    def test_uncertain_start_restores_before_next_tick_can_start(self):
        self.publish()
        original=self.fake.write
        def timeout(*args):
            original(*args)
            raise TimeoutError('response lost')
        self.fake.write=timeout
        self.assertEqual(self.supervisor.step(NOW)['phase'],'recovery_required')
        self.fake.write=original
        self.assertEqual(self.supervisor.step(NOW)['phase'],'previous state restored')
        self.assertEqual(self.fake.state,self.before)

    def test_manual_change_is_preserved(self):
        self.publish();self.supervisor.step(NOW)
        self.fake.state={'mode':'manual'}
        self.assertEqual(self.supervisor.step(NOW)['phase'],'external change preserved')
        self.assertEqual(self.fake.state,{'mode':'manual'})
        self.assertEqual(self.supervisor.step(NOW)['phase'],'manual change hold')
        restarted=Supervisor(self.state,self.supervisor.journal.path,
            adapter=self.fake,identity='test-installation',requested=True)
        self.assertEqual(restarted.step(NOW)['phase'],'manual change hold')
        self.assertEqual(self.fake.state,{'mode':'manual'})
        self.publish(6)
        self.assertEqual(restarted.step(NOW)['phase'],'no boost')
        self.publish(0)
        self.assertEqual(restarted.step(NOW)['phase'],'boost started')

    def test_unverified_native_expiry_prevents_start(self):
        self.publish();self.fake.server_expiry_verified=False
        self.assertFalse(self.supervisor.step(NOW)['control_enabled'])
        self.assertEqual(self.fake.writes,[])

    def test_orphan_corrupt_or_wrong_identity_journal_is_retained(self):
        path=self.supervisor.journal.path
        path.write_text('corrupt private journal')
        supervisor=Supervisor(self.state,path)
        self.assertEqual(supervisor.step(NOW)['phase'],'recovery_required')
        self.assertEqual(path.read_text(),'corrupt private journal')
        self.assertEqual(self.supervisor.step(NOW)['phase'],'recovery_required')
        self.assertTrue(path.exists())

    def test_process_lock_and_private_journal(self):
        self.supervisor.claim_process()
        self.addCleanup(self.supervisor.process_lock.close)
        other=Supervisor(self.state,self.supervisor.journal.path)
        with self.assertRaises(RuntimeError):other.claim_process()
        self.publish();self.supervisor.step(NOW)
        self.assertEqual(self.supervisor.journal.path.stat().st_mode & 0o777,0o600)

    def test_status_is_read_only_for_heating_and_api_compatible(self):
        self.publish();self.supervisor.step(NOW)
        count=len(self.fake.writes)
        status=self.state.status(NOW)
        self.assertIn('heating_control',status)
        self.assertEqual(len(self.fake.writes),count)
        self.assertEqual(status['price_basis'],'agile_plus_forecast_pv')

    def test_effective_price_and_solar_samples_cover_both_dst_days(self):
        for day,count in ((date(2026,3,29),46),(date(2026,10,25),50)):
            rates=prices(day)
            timestamps=[]
            for rate in rates:
                start=rate['start'].astimezone(UTC)
                timestamps.extend([int(start.timestamp()),int((start+timedelta(minutes=15)).timestamp())])
            payload={'minutely_15':{'time':timestamps,'shortwave_radiation':[0]*len(timestamps)}}
            with patch('controller.service.direct_session') as session:
                response=session.return_value.get.return_value
                response.json.return_value=payload
                radiation=fetch_radiation(DEFAULT,day,rates)
                slots=effective_prices(rates,radiation,DEFAULT)
            self.assertEqual(len(slots),count)
            self.assertEqual(len({s['start'] for s in slots}),count)
            self.assertTrue(all(s['effective_price_p']==-1 for s in slots))


class ObservedTransportTests(unittest.TestCase):
    def setUp(self):
        self.api=ObservedHomely('/not-used.env','Test','house','sensor-zone','0')
        self.client=Mock(house_id='house',user_id='user')
        self.api.client=self.client

    def test_disabled_transport_never_writes_or_authenticates(self):
        self.api.client=None
        with patch('controller.heating.homely_login') as login:
            for action in (lambda:self.api.set_disabled(False), self.api.cancel_boost):
                with self.assertRaises(ControlUnavailable):action()
            login.assert_not_called()

    def test_exact_captured_mode_and_cancel_payloads_only(self):
        self.api.allow_writes=True
        self.client.post.return_value={'settings':{'hotWaterOnlyMode':False},'schedules':{}}
        self.api.set_disabled(False)
        self.assertEqual(self.client.post.call_args.args[0],dict(method='setSettings',
            houseId='house',userId='user',payload={'hotWaterOnlyMode':False}))
        self.client.post.return_value={'boostActive':False,'zoneId':'0'}
        self.api.cancel_boost()
        self.assertEqual(self.client.post.call_args.args[0]['payload'],{'status':False,'zoneId':'0'})
        with self.assertRaises(ValueError):self.api.set_disabled('false')
        with self.assertRaises(ControlUnavailable):self.api.call('setHotWaterSchedule',{})

    def test_timeout_is_not_replayed_and_clears_session(self):
        self.api.allow_writes=True
        self.client.post.side_effect=TimeoutError('secret-body')
        with self.assertRaises(ControlUnavailable) as error:self.api.set_disabled(False)
        self.assertNotIn('secret-body',str(error.exception))
        self.assertEqual(self.client.post.call_count,1)
        self.assertIsNone(self.api.client)

    def test_cancel_requires_matching_zone_and_false_confirmation(self):
        self.api.allow_writes=True
        for result in ({'boostActive':True,'zoneId':'0'},{'boostActive':False,'zoneId':0},None):
            self.client.post.return_value=result
            with self.assertRaises(ControlUnavailable):self.api.cancel_boost()

    def test_observation_requires_unique_explicit_zone_and_valid_types(self):
        settings={'hotWaterOnlyMode':True}
        zone=dict(id='sensor-zone',temperature=19.5,lastUpdated=int(NOW.timestamp()*1000),
                  heatingOn=False,nodeLost=False)
        self.client.post.side_effect=[settings,[zone]]
        observation=self.api.observe(NOW)
        self.assertTrue(observation['sensor_candidate_fresh'])
        self.assertFalse(observation['sensor_contract_verified'])
        self.assertNotIn('sensor-zone',str(observation))
        for zones in ([],[zone,zone],[dict(zone,lastUpdated=float('nan'))],
                      [dict(zone,temperature=True)],[dict(zone,nodeLost='false')]):
            self.client.post.side_effect=[settings,zones]
            with self.assertRaises(ControlUnavailable):self.api.observe(NOW)
        self.client.post.side_effect=[settings,[dict(zone,nodeLost=True)]]
        self.assertFalse(self.api.observe(NOW)['sensor_candidate_fresh'])

    def test_native_start_is_write_gated_and_uses_observed_payload(self):
        end=NOW+timedelta(minutes=30)
        with self.assertRaises(ControlUnavailable):self.api.start_boost(NOW,end)
        self.client.post.assert_not_called()
        self.api.allow_writes=True
        self.client.post.return_value=dict(boostActive=True,zoneId='0',start=int(NOW.timestamp()*1000),end=int(end.timestamp()*1000))
        self.api.start_boost(NOW,end)
        self.assertEqual(self.client.post.call_args.args[0]['payload'],dict(status=True,zoneId='0',start=int(NOW.timestamp()*1000),end=int(end.timestamp()*1000)))

    def test_start_response_must_confirm_exact_zone_and_slot_end(self):
        self.api.allow_writes=True
        end=NOW+timedelta(minutes=30)
        correct=dict(boostActive=True,zoneId='0',start=int(NOW.timestamp()*1000),end=int(end.timestamp()*1000))
        for value in [None,dict(correct,boostActive=False),dict(correct,zoneId=0),dict(correct,end=correct['end']+60000),dict(correct,start=True)]:
            self.client.post.return_value=value
            with self.assertRaises(ControlUnavailable):self.api.start_boost(NOW,end)

    def test_start_rejects_naive_and_more_than_half_hour_before_write(self):
        self.api.allow_writes=True
        for start,end in [(NOW.replace(tzinfo=None),NOW),(NOW,NOW+timedelta(minutes=31)),(NOW,NOW)]:
            with self.assertRaises(ValueError):self.api.start_boost(start,end)
        self.client.post.assert_not_called()

    def test_stop_only_permission_cannot_enable_or_start(self):
        self.api.allow_stop=True
        self.client.post.return_value={'settings':{'hotWaterOnlyMode':True},'schedules':{}}
        self.api.set_disabled(True)
        self.client.post.return_value={'boostActive':False,'zoneId':'0'}
        self.api.cancel_boost()
        with self.assertRaises(ControlUnavailable):self.api.set_disabled(False)
        with self.assertRaises(ControlUnavailable):self.api.start_boost(NOW,NOW+timedelta(minutes=30))
        with self.assertRaises(ControlUnavailable):self.api.call('setSettings',dict(hotWaterOnlyMode=True,hwSetPoint='30'))

    def test_wrong_house_refused(self):
        self.api.client=None
        with patch('controller.heating.Config'),patch('controller.heating.homely_login',return_value={'access_token':'test'}),patch('controller.heating.SafeClient') as factory:
            factory.return_value.house_id='other'
            with self.assertRaises(ControlUnavailable):self.api.connect()
        self.assertIsNone(self.api.client)

    def test_safe_http_errors_redirects_and_invalid_json_do_not_leak(self):
        client=SafeClient('test-token')
        for status in (301,401,429,500):
            with patch.object(client.session,'post') as post:
                post.return_value.status_code=status
                post.return_value.text='private response'
                with self.assertRaises(ControlUnavailable) as error:client.post({'method':'getSettings'})
                self.assertNotIn('private',str(error.exception))
                self.assertFalse(post.call_args.kwargs['allow_redirects'])
                self.assertEqual(post.call_count,1)
        with patch.object(client.session,'post') as post:
            post.return_value.status_code=200
            post.return_value.json.side_effect=ValueError('private response')
            with self.assertRaises(ControlUnavailable):client.post({'method':'getSettings'})


if __name__=='__main__':unittest.main()
