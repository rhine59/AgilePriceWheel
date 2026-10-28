"""Authenticated automation switch API, persistence and validation."""
import json,tempfile,threading,unittest,time
from pathlib import Path
from http.server import ThreadingHTTPServer
from urllib.request import Request,urlopen
from urllib.error import HTTPError
from controller.service import State,handler_for

class Driver:
 def __init__(self):self.ready=False;self.applied=0
 def can_activate(self):return self.ready
 def status(self):return dict(phase='disabled',automation_applied_revision=self.applied,shutdown_pending=False)
class AutomationAPITests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
  self.state=State(Path(self.tmp.name)/'policy.json');self.driver=Driver();self.state.control=self.driver
  self.token='test-'+32*'a';self.server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(self.state,self.token))
  self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
  self.addCleanup(self.close)
 def close(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=5)
 def request(self,body=None,token=None):
  r=Request(f'http://127.0.0.1:{self.server.server_port}/v1/automation',headers={'Authorization':'Bearer '+(token or self.token)},data=json.dumps(body).encode() if body is not None else None,method='PUT' if body is not None else 'GET')
  with urlopen(r) as response:return json.load(response)
 def test_default_is_off_and_read_only(self):
  r=self.request();self.assertFalse(r['enabled']);self.assertFalse(r['can_enable']);self.assertFalse(self.state.automation.path.exists())
 def test_off_is_durable_private_and_reports_pending_until_acknowledged(self):
  r=self.request({'enabled':False});self.assertFalse(r['enabled']);self.assertTrue(r['shutdown_pending'])
  self.assertFalse(State(self.state.path).automation.load()['enabled']);self.assertEqual(self.state.automation.path.stat().st_mode&0o777,0o600)
  self.driver.applied=r['revision'];self.assertFalse(self.request()['shutdown_pending'])
 def test_on_requires_controller_activation_and_matching_capability(self):
  with self.assertRaises(HTTPError) as e:self.request({'enabled':True})
  self.assertEqual(e.exception.code,409);self.assertFalse(self.state.automation.load()['enabled'])
 def test_activated_controller_can_arm_and_pause(self):
  self.driver.ready=True;self.assertTrue(self.request({'enabled':True})['enabled'])
  self.assertFalse(self.request({'enabled':False})['enabled'])
 def test_only_a_boolean_single_field_is_accepted(self):
  for d in [{'enabled':'false'},{'enabled':0},{'enabled':False,'live':True},{},[]]:
   with self.assertRaises(HTTPError) as e:self.request(d)
   self.assertEqual(e.exception.code,400)
 def test_authentication_precedes_switch_changes(self):
  with self.assertRaises(HTTPError) as e:self.request({'enabled':False},token='wrong')
  self.assertEqual(e.exception.code,401);self.assertFalse(self.state.automation.path.exists())
 def test_off_repairs_corrupt_switch_state_and_preserves_evidence(self):
  self.state.automation.path.write_text('broken')
  self.assertIsNotNone(self.request()['error'])
  r=self.request({'enabled':False});self.assertTrue(r['shutdown_pending']);self.assertFalse(r['enabled'])
  self.assertEqual(self.state.automation.path.with_suffix('.invalid').read_text(),'broken')
 def test_switch_does_not_modify_price_policy(self):
  before=self.state.document();self.request({'enabled':False});self.assertEqual(self.state.document(),before)
 def test_nonobject_config_is_repairable_with_off(self):
  for invalid in ['null','[]','true']:
   self.state.automation.path.write_text(invalid)
   self.assertIsNotNone(self.request()['error'])
   self.assertFalse(self.request({'enabled':False})['enabled'])
 def test_off_is_saved_without_waiting_for_a_busy_control_tick(self):
  acquired=threading.Event();release=threading.Event()
  def busy():
   with self.state.control_lock:
    acquired.set();release.wait(3)
  thread=threading.Thread(target=busy);thread.start();self.assertTrue(acquired.wait(1))
  began=time.monotonic()
  try:result=self.request({'enabled':False})
  finally:release.set();thread.join(timeout=4)
  self.assertLess(time.monotonic()-began,1);self.assertFalse(result['enabled']);self.assertTrue(result['shutdown_pending'])
if __name__=='__main__':unittest.main()
