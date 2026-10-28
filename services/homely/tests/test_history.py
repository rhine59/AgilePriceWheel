"""History durability, authentication and UK/DST calendar-week behaviour."""
from datetime import datetime,timedelta,timezone
from pathlib import Path
import json,tempfile,threading,unittest
from http.server import ThreadingHTTPServer
from urllib.request import Request,urlopen
from urllib.error import HTTPError
from controller.history import History,HistoryUnavailable,week_bounds
from controller.service import State,handler_for
UTC=timezone.utc;NOW=datetime(2026,10,25,18,tzinfo=UTC)
def event(at=NOW,state='on',ident='one'):
 return dict(id=ident,at=at.isoformat(),state=state,reason='price_policy_start',price_p=-5,on_price_p=-5,off_price_p=-1,source='automation')
class HistoryTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.path=Path(self.tmp.name)/'history.sqlite3';self.history=History(self.path)
 def test_empty_get_does_not_create_file(self):
  r=self.history.week(now=NOW);self.assertEqual(r['events'],[]);self.assertEqual(r['week_start'],'2026-10-19');self.assertFalse(self.path.exists())
 def test_events_persist_private_and_duplicate_retry_is_idempotent(self):
  e=event();self.history.append([e],NOW);self.history.append([e],NOW)
  r=History(self.path).week(now=NOW);self.assertEqual(len(r['events']),1);self.assertEqual(r['events'][0]['price_p'],-5)
  self.assertEqual(self.path.stat().st_mode&0o777,0o600)
 def test_boundaries_are_exclusive_end_and_sorted_newest_first(self):
  _,_,start,end=week_bounds('2026-10-19',NOW)
  values=[event(start,ident='start'),event(end-timedelta(seconds=1),'off','last'),event(end,ident='next')]
  self.history.append(values,end)
  r=self.history.week('2026-10-19',end);self.assertEqual([v['id'] for v in r['events']],['last','start'])
 def test_spring_and_autumn_weeks_have_167_and_169_hours(self):
  for week,now,hours in [('2026-03-23',datetime(2026,3,29,18,tzinfo=UTC),167),('2026-10-19',NOW,169)]:
   _,_,a,b=week_bounds(week,now);self.assertEqual((b-a).total_seconds()/3600,hours)
 def test_repeated_autumn_hour_retains_distinct_events(self):
  a=datetime(2026,10,25,0,30,tzinfo=UTC);b=a+timedelta(hours=1)
  self.history.append([event(a,ident='bst'),event(b,'off','gmt')],NOW)
  r=self.history.week(now=NOW);self.assertEqual([v['id'] for v in r['events']],['gmt','bst'])
 def test_invalid_week_and_future_weeks_rejected(self):
  for week in ['2026-10-20','bad','2026-W43-1','2026-11-02','2020-01-06']:
   with self.assertRaises(ValueError):self.history.week(week,NOW)
 def test_retention_purges_old_events(self):
  self.history.append([event(NOW-timedelta(days=367),ident='old'),event()],NOW)
  self.assertEqual([v['id'] for v in self.history.week(now=NOW)['events']],['one'])
 def test_corrupt_database_is_sanitized(self):
  self.path.write_text('private corrupt data')
  with self.assertRaises(HistoryUnavailable) as e:self.history.week(now=NOW)
  self.assertNotIn('private',str(e.exception))
 def test_history_fields_never_include_house_or_credentials(self):
  self.history.append([event()],NOW);row=self.history.week(now=NOW)['events'][0]
  self.assertEqual(set(row),{'id','at','state','reason','price_p','on_price_p','off_price_p','source'})
 def test_nonfinite_future_or_invalid_events_rejected(self):
  for change in [dict(price_p=float('nan')),dict(state='maybe'),dict(source='unknown'),dict(at=(NOW+timedelta(minutes=1)).isoformat())]:
   with self.assertRaises(ValueError):self.history.append([dict(event(),**change)],NOW)

class HistoryAPITests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.state=State(Path(self.tmp.name)/'policy.json');self.token='test-'+32*'a'
  self.server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(self.state,self.token));self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start();self.addCleanup(self.close)
 def close(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=5)
 def get(self,suffix='',token=None):
  with urlopen(Request(f'http://127.0.0.1:{self.server.server_port}/v1/history'+suffix,headers={'Authorization':'Bearer '+(token or self.token)})) as response:return json.load(response)
 def test_authenticated_history_get_is_read_only_for_controls(self):
  before=self.state.document();r=self.get();self.assertEqual(r['timezone'],'Europe/London');self.assertEqual(r['events'],[]);self.assertEqual(self.state.document(),before)
 def test_history_requires_key(self):
  with self.assertRaises(HTTPError) as e:self.get(token='wrong')
  self.assertEqual(e.exception.code,401)
 def test_bad_duplicate_or_unknown_query_returns_400(self):
  for q in ['?week=bad','?week=','?week=2026-10-19&week=2026-10-19','?other=1','?week']:
   with self.assertRaises(HTTPError) as e:self.get(q)
   self.assertEqual(e.exception.code,400)
 def test_bad_database_does_not_break_other_services(self):
  self.state.history.path.write_text('broken')
  with self.assertRaises(HTTPError) as e:self.get()
  self.assertEqual(e.exception.code,503);self.assertEqual(self.state.document()['revision'],0)
if __name__=='__main__':unittest.main()
