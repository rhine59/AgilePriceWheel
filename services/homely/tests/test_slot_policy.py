"""No network or heating writes: fixed half-hour price policy semantics."""
from datetime import datetime,timedelta,timezone
import unittest
from zoneinfo import ZoneInfo
from controller.slot_policy import SlotPolicy
UTC=timezone.utc
NOW=datetime(2026,10,25,12,tzinfo=UTC)
POLICY=dict(on_price_p=0,off_price_p=5)
def slot(start=NOW,price=0):
 return dict(start=start.isoformat(),end=(start+timedelta(minutes=30)).isoformat(),effective_price_p=price)
class SlotPolicyTests(unittest.TestCase):
 def test_start_boundary_and_end_are_aligned(self):
  p=SlotPolicy();r=p.evaluate(NOW,slot(),POLICY,1)
  self.assertTrue(r['price_allowed']);self.assertEqual(r['slot_end'],(NOW+timedelta(minutes=30)).isoformat())
 def test_mid_slot_start_waits_until_next_boundary(self):
  p=SlotPolicy();self.assertFalse(p.evaluate(NOW+timedelta(minutes=2),slot(),POLICY,1)['price_allowed'])
  later=NOW+timedelta(minutes=30);self.assertTrue(p.evaluate(later,slot(later),POLICY,1)['price_allowed'])
 def test_same_slot_forecast_refresh_does_not_restart_or_change_decision(self):
  p=SlotPolicy();p.evaluate(NOW,slot(),POLICY,1)
  r=p.evaluate(NOW+timedelta(minutes=10),slot(price=20),POLICY,1)
  self.assertTrue(r['price_allowed']);self.assertEqual(r['decision_price_p'],0)
 def test_hysteresis_at_following_boundaries(self):
  p=SlotPolicy()
  for n,price,wanted in [(0,0,True),(1,5,True),(2,5.01,False),(3,3,False),(4,-1,True)]:
   t=NOW+timedelta(minutes=30*n);self.assertEqual(p.evaluate(t,slot(t,price),POLICY,1)['price_allowed'],wanted)
 def test_api_failure_stops_and_recovery_waits_next_boundary(self):
  p=SlotPolicy();p.evaluate(NOW,slot(),POLICY,1)
  self.assertFalse(p.evaluate(NOW+timedelta(seconds=5),slot(),POLICY,1,stale=True)['price_allowed'])
  self.assertFalse(p.evaluate(NOW+timedelta(seconds=10),slot(),POLICY,1)['price_allowed'])
  later=NOW+timedelta(minutes=30);self.assertTrue(p.evaluate(later,slot(later),POLICY,1)['price_allowed'])
 def test_policy_edit_waits_next_boundary(self):
  p=SlotPolicy();p.evaluate(NOW,slot(),POLICY,1)
  self.assertFalse(p.evaluate(NOW+timedelta(seconds=5),slot(),POLICY,2)['price_allowed'])
  later=NOW+timedelta(minutes=30);self.assertTrue(p.evaluate(later,slot(later),POLICY,2)['price_allowed'])
 def test_missing_skipped_slot_loses_hysteresis(self):
  p=SlotPolicy();p.evaluate(NOW,slot(),POLICY,1)
  later=NOW+timedelta(hours=1);self.assertFalse(p.evaluate(later,slot(later,3),POLICY,1)['price_allowed'])
 def test_boundary_grace_does_not_allow_late_starts(self):
  for seconds,wanted in [(15,True),(16,False)]:
   self.assertEqual(SlotPolicy().evaluate(NOW+timedelta(seconds=seconds),slot(),POLICY,1)['price_allowed'],wanted)
 def test_invalid_price_slot_and_clock_fail_closed(self):
  for bad in [None,slot(price=float('nan')),slot(price=True),slot(NOW+timedelta(minutes=30))]:
   self.assertFalse(SlotPolicy().evaluate(NOW,bad,POLICY,1)['price_allowed'])
  p=SlotPolicy();p.evaluate(NOW+timedelta(seconds=5),slot(),POLICY,1)
  self.assertFalse(p.evaluate(NOW,slot(),POLICY,1)['price_allowed'])
 def test_both_dst_days_have_distinct_half_hours(self):
  london=ZoneInfo('Europe/London')
  for month,day,count in [(3,29,46),(10,25,50)]:
   begin=datetime(2026,month,day,tzinfo=london).astimezone(UTC)
   end=(datetime(2026,month,day,tzinfo=london)+timedelta(days=1)).astimezone(UTC)
   p=SlotPolicy();seen=[];t=begin
   while t<end:
    r=p.evaluate(t,slot(t),POLICY,1);self.assertTrue(r['price_allowed']);seen.append(r['slot_start']);t+=timedelta(minutes=30)
   self.assertEqual(len(set(seen)),count)
 def test_temperature_is_not_part_of_policy_decision(self):
  self.assertTrue(SlotPolicy().evaluate(NOW,slot(),POLICY,1)['price_allowed'])
if __name__=='__main__':unittest.main()
