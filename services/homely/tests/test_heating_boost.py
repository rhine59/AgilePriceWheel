import copy
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from zoneinfo import ZoneInfo

from heating_boost import Controller, Journal, Policy, eligible_slots, main
from homely import replace_weekday, HomelyClient

UTC = timezone.utc
LONDON = ZoneInfo('Europe/London')
NOW = datetime(2026, 10, 24, 12, tzinfo=UTC)
SLOT = dict(start=NOW, end=NOW + timedelta(minutes=30), price=0)


def prices(day):
    start = datetime.combine(day, datetime.min.time(), LONDON).astimezone(UTC)
    end = datetime.combine(day + timedelta(days=1), datetime.min.time(), LONDON).astimezone(UTC)
    slots = []
    while start < end:
        slots.append(dict(start=start.astimezone(LONDON),
                          end=(start + timedelta(minutes=30)).astimezone(LONDON), price=-1))
        start += timedelta(minutes=30)
    return slots


class Fake:
    server_expiry_verified = True
    def __init__(self):
        self.state = dict(mode='scheduled', override={'target': 18, 'end': 'original'})
        self.room, self.observed = 19, NOW
        self.writes = []
        self.fail_write = self.fail_read = self.fail_sensor = False
        self.dhw = {'sunamp': 'unchanged'}
    def read(self):
        if self.fail_read:
            raise ConnectionError('read failed')
        return copy.deepcopy(self.state)
    def temperature(self):
        if self.fail_sensor:
            raise ConnectionError('sensor failed')
        return self.room, self.observed
    def make_boost(self, previous, target_c, expires, operation_id):
        return dict(mode='temporary', target=target_c, end=expires.isoformat(), owner=operation_id)
    def write(self, expected, desired, operation_id):
        if self.state != expected:
            raise RuntimeError('concurrent change')
        if self.fail_write:
            raise ConnectionError('write failed')
        self.writes.append(operation_id)
        self.state = copy.deepcopy(desired)


class PlanningTests(unittest.TestCase):
    def test_dst_complete_days(self):
        for day, count in [(date(2026,3,29),46), (date(2026,10,25),50), (date(2026,10,24),48)]:
            with self.subTest(day=day):
                self.assertEqual(len(eligible_slots(prices(day), day, LONDON, Policy())), count)
    def test_both_repeated_hours_preserved(self):
        slots = eligible_slots(prices(date(2026,10,25)), date(2026,10,25), LONDON, Policy())
        ones = [s for s in slots if s['start'].hour == 1]
        self.assertEqual(len(ones),4)
        self.assertEqual(len({s['start'].astimezone(UTC) for s in ones}),4)
    def test_raw_threshold_inclusive(self):
        day = date(2026,10,24)
        slots = prices(day)
        for s in slots: s['price'] = 5
        slots[0]['price'], slots[1]['price'], slots[2]['price'] = -1, 0, 0.01
        slots[2]['adjusted_price'] = -10
        self.assertEqual(len(eligible_slots(slots,day,LONDON,Policy())),2)
        self.assertEqual(len(eligible_slots(slots,day,LONDON,Policy(on_price_p=-0.1))),1)
    def test_missing_duplicate_overlap_nonfinite(self):
        day = date(2026,10,24)
        for change in ('missing','duplicate','overlap','nan','inf'):
            with self.subTest(change=change):
                slots = prices(day)
                if change == 'missing': slots.pop()
                elif change == 'duplicate': slots.append(slots[0])
                elif change == 'overlap': slots[1]['start'] = slots[0]['start']
                else: slots[0]['price'] = float(change)
                with self.assertRaises((ValueError,RuntimeError)):
                    eligible_slots(slots,day,LONDON,Policy())
    def test_policy_validation(self):
        for kwargs in [dict(limit_c=26),dict(target_c=23),dict(on_price_p=float('nan')),dict(sensor_age_s=0)]:
            with self.assertRaises(ValueError): Policy(**kwargs)
    def test_price_config_precedence_and_legacy(self):
        from homely import Config
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'config.env'
            path.write_text('DEFAULT_PROFILE=Test\nHEATING_PRICE_THRESHOLD_P=-2\n')
            legacy=Policy.from_config(Config(path,None))
            self.assertEqual((legacy.on_price_p,legacy.off_price_p),(-2,-2))
            path.write_text('DEFAULT_PROFILE=Test\nHEATING_ON_PRICE_P=0\nHEATING_OFF_PRICE_P=5\nTest.HEATING_ON_PRICE_P=-1\n')
            policy=Policy.from_config(Config(path,None))
            self.assertEqual((policy.on_price_p,policy.off_price_p),(-1,5))
        for kwargs in [dict(on_price_p=5,off_price_p=0),dict(off_price_p=float('nan'))]:
            with self.assertRaises(ValueError): Policy(**kwargs)

    def test_live_refused_before_auth(self):
        with patch('homely.homely_login') as login:
            with self.assertRaises(SystemExit): main(['--live'])
            login.assert_not_called()
    def test_homely_api_failures(self):
        client = HomelyClient('test-token')
        with patch.object(client.session, 'post', side_effect=TimeoutError('timeout')):
            with self.assertRaises(TimeoutError): client.post({'method':'getSettings'})
        for status in (401, 429, 500):
            with patch.object(client.session, 'post') as request:
                request.return_value.ok = False
                request.return_value.status_code = status
                request.return_value.text = 'simulated failure'
                with self.assertRaises(RuntimeError): client.post({'method':'getSettings'})
        with patch.object(client.session, 'post') as request:
            request.return_value.ok = True
            request.return_value.json.side_effect = ValueError('invalid JSON')
            request.return_value.text = 'invalid'
            with self.assertRaises(RuntimeError): client.post({'method':'getSettings'})

    def test_plan_cli_never_writes_or_emails(self):
        day = date(2026,10,24)
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory)/'test.env'
            config.write_text('DEFAULT_PROFILE=Test\nTest.HOMELY_EMAIL=test@example.com\nOCTOPUS_PRODUCT=test\nOCTOPUS_TARIFF=test\nHEATING_BOOST_ENABLED=true\n')
            with patch('homely.homely_login', return_value={'access_token':'test'}), patch('homely.HomelyClient') as client, patch('homely.fetch_agile_prices', return_value=prices(day)), patch('homely.send_activity_email') as email, patch('builtins.print'):
                client.return_value.timezone_name = 'Europe/London'
                main(['--env-file',str(config),'--date',str(day)])
                client.return_value.set_hotwater_schedule.assert_not_called()
                client.return_value.post.assert_not_called()
                email.assert_not_called()

    def test_dhw_preserves_other_days(self):
        original = [dict(id=str(i),weekdayId=i,start=60,end=90) for i in range(7)]
        saved = copy.deepcopy(original)
        new = [dict(id='new',weekdayId=3,start=120,end=150)]
        result = replace_weekday(original,3,new)
        self.assertEqual([s for s in result if s['weekdayId'] != 3], [s for s in saved if s['weekdayId'] != 3])
        self.assertEqual(original,saved)


class ControlTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.fake = Fake()
        self.before = self.fake.read()
        self.journal = Journal(Path(self.tmp.name)/'state.json','test-house-zone')
        self.control = Controller(self.fake,self.journal,Policy(enabled=True))
    def start(self):
        self.assertEqual(self.control.tick(NOW,SLOT),'boost started')
    def test_end_restores_exact_prior_state_and_sunamp(self):
        self.start()
        self.control.tick(NOW+timedelta(minutes=30),None)
        self.assertEqual(self.fake.state,self.before)
        self.assertEqual(self.fake.dhw,{'sunamp':'unchanged'})
        self.assertIsNone(self.journal.load())
    def test_idempotent_poll(self):
        self.start()
        self.control.tick(NOW+timedelta(seconds=30),SLOT)
        self.assertEqual(len(self.fake.writes),1)
    def test_fail_closed_temperature(self):
        for room, observed in [(22,NOW),(float('nan'),NOW),(19,NOW-timedelta(seconds=121)),(19,NOW+timedelta(seconds=1))]:
            self.fake.room,self.fake.observed=room,observed
            self.assertEqual(self.control.tick(NOW,SLOT),'no boost')
            self.assertEqual(self.fake.writes,[])
    def test_active_boost_stops_on_safety_or_price_failure(self):
        for failure in ('sensor','temperature','prices','disabled'):
            with self.subTest(failure=failure):
                self.setUp()
                self.start()
                slot = SLOT
                if failure == 'sensor': self.fake.fail_sensor=True
                elif failure == 'temperature': self.fake.room=22
                elif failure == 'prices': slot=None
                else: self.control.policy=Policy()
                self.control.tick(NOW+timedelta(seconds=1),slot)
                self.assertEqual(self.fake.state,self.before)
    def test_restore_failure_retains_journal_then_retries_after_restart(self):
        self.start()
        self.fake.fail_write=True
        with self.assertRaises(ConnectionError): self.control.tick(NOW,None)
        self.assertIsNotNone(self.journal.load())
        self.fake.fail_write=False
        restarted=Controller(self.fake,self.journal,Policy())
        restarted.tick(NOW,None)
        self.assertEqual(self.fake.state,self.before)
    def test_manual_change_preserved(self):
        self.start()
        self.fake.state={'mode':'occupant-choice'}
        self.assertEqual(self.control.tick(NOW,None),'external change preserved')
        self.assertEqual(self.fake.state,{'mode':'occupant-choice'})
    def test_timeout_after_success_recovered(self):
        original=self.fake.write
        def timed_out(*args):
            original(*args)
            raise TimeoutError('response lost after server accepted')
        self.fake.write=timed_out
        with self.assertRaises(TimeoutError): self.control.tick(NOW,SLOT)
        self.assertIsNotNone(self.journal.load())
        self.fake.write=original
        self.control.tick(NOW,None)
        self.assertEqual(self.fake.state,self.before)
    def test_native_expiry_and_pending_intent(self):
        self.start()
        self.fake.state=copy.deepcopy(self.before)
        self.assertEqual(self.control.tick(NOW,None),'previous state confirmed')
    def test_wrong_house_and_corruption_refused(self):
        self.start()
        wrong=Controller(self.fake,Journal(self.journal.path,'other-house'),Policy())
        with self.assertRaises(RuntimeError): wrong.tick(NOW,None)
        self.journal.path.write_text('invalid json')
        with self.assertRaises(ValueError): self.control.tick(NOW,None)
    def test_missing_native_expiry_refuses_write(self):
        self.fake.server_expiry_verified=False
        with self.assertRaises(RuntimeError): self.control.tick(NOW,SLOT)
        self.assertEqual(self.fake.writes,[])
    def test_separate_on_off_prices_and_boundaries(self):
        self.control.policy=Policy(enabled=True,on_price_p=0,off_price_p=5)
        band=dict(SLOT,price=2)
        self.assertEqual(self.control.tick(NOW,band),'no boost')
        self.start()
        self.assertEqual(self.control.tick(NOW,band),'boost active')
        self.assertEqual(self.control.tick(NOW,dict(SLOT,price=5)),'boost active')
        self.assertEqual(self.control.tick(NOW,dict(SLOT,price=5.01)),'previous state restored')
        self.assertEqual(self.control.tick(NOW,band),'no boost')

    def test_hold_band_survives_restart_and_adjacent_slot_expiry(self):
        self.control.policy=Policy(enabled=True,on_price_p=0,off_price_p=5)
        self.start()
        next_time=NOW+timedelta(minutes=30)
        self.fake.observed=next_time
        restarted=Controller(self.fake,self.journal,self.control.policy)
        next_slot=dict(start=next_time,end=next_time+timedelta(minutes=30),price=3)
        self.assertEqual(restarted.tick(next_time,next_slot),'boost started')
        self.assertEqual(self.journal.load()['previous'],self.before)
        restarted.tick(next_time,dict(next_slot,price=6))
        self.assertEqual(self.fake.state,self.before)

    def test_gap_does_not_restart_in_hold_band(self):
        self.control.policy=Policy(enabled=True,on_price_p=0,off_price_p=5)
        self.start()
        later=NOW+timedelta(hours=2)
        self.fake.observed=later
        self.control.tick(later,dict(start=later,end=later+timedelta(minutes=30),price=3))
        self.assertEqual(self.fake.state,self.before)

    def test_no_price_or_expired_slot_no_start(self):
        self.assertEqual(self.control.tick(NOW,None),'no boost')
        self.assertEqual(self.control.tick(NOW+timedelta(minutes=30),SLOT),'no boost')
    def test_read_failure_preserves_recovery(self):
        self.start()
        self.fake.fail_read=True
        with self.assertRaises(ConnectionError): self.control.tick(NOW,None)
        self.assertIsNotNone(self.journal.load())


if __name__ == '__main__': unittest.main()
