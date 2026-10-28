"""Session correlation, rates, migration and signed cost estimates; no live calls."""
import test_history as fixtures
from test_history import event,NOW,UTC
from controller.history import iso
from datetime import datetime,timedelta
import unittest,sqlite3
class SessionTests(unittest.TestCase):
 setUp=fixtures.HistoryTests.setUp
 def pair(self,start=NOW,end=None,rates=None):
  end=end or start+timedelta(minutes=30)
  rates=rates if rates is not None else [dict(start=start.isoformat(),end=end.isoformat(),agile_price_p=-5,effective_price_p=-4,load_kw=3)]
  first=dict(event(start,ident='on'),details=dict(session_id='session',interval=rates[0])) if rates else event(start,ident='on')
  values=[first]
  for i,rate in enumerate(rates[1:]):values.append(dict(event(start,ident='rate'+str(i)),state='interval',details=dict(session_id='session',interval=rate)))
  values.append(dict(event(end,'off','off'),details=dict(session_id='session')) if rates else event(end,'off','off'))
  self.history.append(values,end)
  return self.history.week(str((start-timedelta(days=start.weekday())).date()),end)['sessions'][0]
 def test_negative_cost_uses_configured_load_and_effective_rate(self):
  s=self.pair();self.assertEqual(s['estimated_cost_gbp'],-0.06);self.assertEqual(s['estimated_energy_kwh'],1.5)
  self.assertEqual(s['duration_seconds'],1800);self.assertEqual(s['on_at'],iso(NOW));self.assertEqual(s['cost_status'],'estimated')
 def test_multislot_rate_and_load_changes_are_integrated(self):
  end=NOW+timedelta(hours=1);middle=NOW+timedelta(minutes=30)
  rates=[dict(start=NOW.isoformat(),end=middle.isoformat(),agile_price_p=-5,effective_price_p=-5,load_kw=2),dict(start=middle.isoformat(),end=end.isoformat(),agile_price_p=10,effective_price_p=8,load_kw=3)]
  s=self.pair(end=end,rates=rates);self.assertEqual(s['estimated_cost_gbp'],0.07);self.assertEqual(len(s['intervals']),2)
 def test_missing_interval_does_not_report_partial_cost_as_total(self):
  rate=dict(start=NOW.isoformat(),end=(NOW+timedelta(minutes=15)).isoformat(),effective_price_p=1,load_kw=3)
  s=self.pair(rates=[rate]);self.assertIsNone(s['estimated_cost_gbp']);self.assertEqual(s['cost_status'],'missing_rate_data')
 def test_legacy_pair_has_no_guessed_consumption(self):
  s=self.pair(rates=[]);self.assertEqual(s['duration_seconds'],1800);self.assertIsNone(s['estimated_cost_gbp'])
 def test_open_session_has_no_final_cost_or_fabricated_off(self):
  self.history.append([event()],NOW);s=self.history.week(now=NOW)['sessions'][0]
  self.assertIsNone(s['off_at']);self.assertIsNone(s['estimated_cost_gbp']);self.assertEqual(s['cost_status'],'end_unconfirmed')
 def test_cross_week_pair_visible_in_both_weeks(self):
  start=datetime(2026,10,25,23,45,tzinfo=UTC);end=start+timedelta(minutes=30)
  self.pair(start,end)
  for week in ['2026-10-19','2026-10-26']:
   self.assertEqual(self.history.week(week,end)['sessions'][0]['duration_seconds'],1800)
 def test_unmatched_off_is_not_paired(self):
  self.history.append([dict(event(),details=dict(session_id='one')),dict(event(NOW+timedelta(minutes=1),'off','off'),details=dict(session_id='other'))],NOW+timedelta(minutes=1))
  self.assertIsNone(self.history.week(now=NOW+timedelta(minutes=1))['sessions'][0]['off_at'])
 def test_migration_preserves_events(self):
  db=sqlite3.connect(self.path);db.execute('CREATE TABLE events (id TEXT PRIMARY KEY,at TEXT,epoch REAL,state TEXT,reason TEXT,price REAL,on_price REAL,off_price REAL,source TEXT)');db.commit();db.close()
  self.history.append([event()],NOW);self.assertEqual(len(self.history.week(now=NOW)['events']),1)

 def test_rates_remain_private_from_legacy_event_query(self):
  self.pair(rates=[dict(start=NOW.isoformat(),end=(NOW+timedelta(minutes=15)).isoformat(),effective_price_p=1,load_kw=3),dict(start=(NOW+timedelta(minutes=15)).isoformat(),end=(NOW+timedelta(minutes=30)).isoformat(),effective_price_p=2,load_kw=3)])
  db=sqlite3.connect(self.path)
  self.assertEqual(db.execute("SELECT count(*) FROM events WHERE state NOT IN ('on','off')").fetchone()[0],0);db.close()
 def test_dst_duration_uses_elapsed_utc_time(self):
  start=datetime(2026,10,25,0,30,tzinfo=UTC);end=start+timedelta(hours=1)
  self.assertEqual(self.pair(start,end)['duration_seconds'],3600)
 def test_off_rate_covers_delayed_confirmation_in_next_slot(self):
  end=NOW+timedelta(minutes=30,seconds=10);mid=NOW+timedelta(minutes=30)
  self.history.append([dict(event(NOW),details=dict(session_id='s',interval=dict(start=NOW.isoformat(),end=mid.isoformat(),effective_price_p=2,load_kw=3))),dict(event(end,'off','off'),details=dict(session_id='s',interval=dict(start=mid.isoformat(),end=(mid+timedelta(minutes=30)).isoformat(),effective_price_p=10,load_kw=3)))],end)
  self.assertAlmostEqual(self.history.week(now=end)['sessions'][0]['estimated_cost_gbp'],0.03083333)

 def test_session_ending_exactly_monday_is_not_repeated_in_next_week(self):
  end=datetime(2026,10,26,tzinfo=UTC);self.pair(end-timedelta(minutes=30),end)
  self.assertEqual(self.history.week('2026-10-26',end)['sessions'],[])
 def test_unconfirmed_old_session_does_not_leak_into_every_future_week(self):
  self.history.append([event()],NOW)
  self.assertEqual(self.history.week('2026-10-26',NOW+timedelta(days=1))['sessions'],[])
 def test_retention_applies_on_reads_even_if_no_recent_write(self):
  self.history.append([event()],NOW)
  later=NOW+timedelta(days=366,hours=1)
  self.assertEqual(self.history.week('2026-10-19',later)['events'],[])

 def test_confirmed_rate_in_new_week_keeps_open_session_visible(self):
  start=datetime(2026,10,25,23,45,tzinfo=UTC);monday=datetime(2026,10,26,tzinfo=UTC)
  self.history.append([dict(event(start),details=dict(session_id='s')),dict(event(monday,ident='rate'),state='interval',details=dict(session_id='s',interval=dict(start=monday.isoformat(),end=(monday+timedelta(minutes=30)).isoformat(),effective_price_p=0,load_kw=3)))],monday)
  self.assertEqual(len(self.history.week('2026-10-26',monday)['sessions']),1)
 def test_session_limit_reports_truncation_without_new_week_actions(self):
  monday=datetime(2026,10,26,tzinfo=UTC);values=[]
  interval=dict(start=monday.isoformat(),end=(monday+timedelta(minutes=30)).isoformat(),effective_price_p=0,load_kw=3)
  for i in range(2001):
   sid=str(i);values.append(dict(event(NOW,ident='on'+sid),details=dict(session_id=sid)))
   values.append(dict(event(monday,ident='rate'+sid),state='interval',details=dict(session_id=sid,interval=interval)))
  self.history.append(values,monday);r=self.history.week('2026-10-26',monday)
  self.assertEqual(r['events'],[]);self.assertEqual(len(r['sessions']),2000);self.assertTrue(r['truncated'])
 def test_concurrent_write_does_not_mix_history_snapshots(self):
  from unittest.mock import patch
  self.history.append([event()],NOW);connect=sqlite3.connect;history=self.history;triggered=[]
  class Reader:
   def __init__(self,db):self.db=db
   def __getattr__(self,key):return getattr(self.db,key)
   def execute(self,sql,*args):
    cursor=self.db.execute(sql,*args)
    if 'SELECT min(epoch)' in sql and not triggered:
     triggered.append(True);history.append([event(NOW+timedelta(seconds=1),'off','new')],NOW+timedelta(seconds=1))
    return cursor
  def connection(*args,**kwargs):
   db=connect(*args,**kwargs)
   return Reader(db) if kwargs.get('uri') else db
  with patch('controller.history.sqlite3.connect',side_effect=connection):r=self.history.week(now=NOW+timedelta(seconds=1))
  self.assertEqual(len(r['events']),1)
  self.assertEqual(len(self.history.week(now=NOW+timedelta(seconds=1))['events']),2)
