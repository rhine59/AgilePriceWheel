import json
from datetime import datetime,timedelta,timezone
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch
from http.server import ThreadingHTTPServer
from urllib.request import Request,urlopen
from urllib.error import HTTPError
from controller.service import DEFAULT,State,Conflict,effective_prices,handler_for,validate_policy
UTC=timezone.utc
NOW=datetime(2026,10,24,12,tzinfo=UTC)

class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.state=State(Path(self.temp.name)/'policy.json')
    def test_pv_effective_price_matches_app(self):
        rates=[dict(start=NOW,end=NOW+timedelta(minutes=30),price=20)]
        slot=effective_prices(rates,{NOW:600},DEFAULT)[0]
        self.assertAlmostEqual(slot['pv_kwh'],1.275)
        self.assertAlmostEqual(slot['grid_kwh'],0.225)
        self.assertAlmostEqual(slot['effective_price_p'],3)
        slot=effective_prices(rates,{NOW:2000},DEFAULT)[0]
        self.assertEqual(slot['effective_price_p'],0)
    def test_no_pv_and_negative_import(self):
        rates=[dict(start=NOW,end=NOW+timedelta(minutes=30),price=-5)]
        self.assertEqual(effective_prices(rates,{NOW:0},DEFAULT)[0]['effective_price_p'],-5)
        with self.assertRaises(KeyError): effective_prices(rates,{},DEFAULT)
        with self.assertRaises(ValueError): effective_prices(rates,{NOW:float('nan')},DEFAULT)
    def test_invalid_policy(self):
        for change in [dict(off_price_p=-1),dict(limit_c=26),dict(latitude=91),dict(load_kw=0),dict(array_kwp=float('nan')),dict(product='../../bad')]:
            with self.assertRaises(ValueError): validate_policy(dict(DEFAULT,**change))
    def test_signed_thresholds_persist_without_clamping(self):
        document=self.state.document();document['policy'].update(on_price_p=-5.5,off_price_p=-1)
        self.state.update(document)
        result=State(self.state.path).document()['policy']
        self.assertEqual(result['on_price_p'],-5.5);self.assertEqual(result['off_price_p'],-1)
        with self.assertRaises(ValueError):validate_policy(dict(result,off_price_p=-6))

    def test_persist_conflict_and_restart(self):
        document=self.state.document(); document['policy']['off_price_p']=5
        self.state.update(document)
        with self.assertRaises(Conflict): self.state.update(document)
        restarted=State(self.state.path)
        self.assertEqual(restarted.document()['policy']['off_price_p'],5)
        self.assertEqual(restarted.document()['revision'],1)
        self.assertFalse(restarted.status(NOW)['control_enabled'])
    def test_price_band_and_expiry_fail_closed(self):
        document=self.state.document(); document['policy']['off_price_p']=5
        self.state.update(document)
        def publish(price):
            self.state.publish(1,[dict(start=NOW.isoformat(),end=(NOW+timedelta(minutes=30)).isoformat(),effective_price_p=price)],NOW)
        publish(3); self.assertFalse(self.state.status(NOW)['price_requests_heat'])
        publish(0); self.assertTrue(self.state.status(NOW)['price_requests_heat'])
        publish(5); self.assertTrue(self.state.status(NOW)['price_requests_heat'])
        publish(5.01); self.assertFalse(self.state.status(NOW)['price_requests_heat'])
        publish(0); self.assertTrue(self.state.status(NOW)['price_requests_heat'])
        self.assertFalse(self.state.status(NOW+timedelta(minutes=16))['price_requests_heat'])
    def test_policy_change_invalidates_old_fetch(self):
        self.state.update(self.state.document())
        self.state.publish(0,[],NOW)
        self.assertIsNone(self.state.snapshot)
    def test_api_failure_clears_plan(self):
        with patch('controller.service.fetch_agile_prices',side_effect=TimeoutError):
            self.state.refresh()
        self.assertIsNone(self.state.status()['current'])
        self.assertFalse(self.state.status()['price_requests_heat'])
    def test_authenticated_http_policy_and_status(self):
        from controller.heating import build_supervisor
        self.state.control=build_supervisor(self.state,{'HEATING_RECOVERY_FILE':str(Path(self.temp.name)/'recovery.json')})
        self.state.control.step(NOW)
        token='test-key-'+'a'*32
        server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(self.state,token))
        self.addCleanup(server.server_close)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        self.addCleanup(server.shutdown)
        base=f'http://127.0.0.1:{server.server_port}'
        with self.assertRaises(HTTPError) as failure: urlopen(base+'/v1/policy')
        self.assertEqual(failure.exception.code,401)
        headers={'Authorization':'Bearer '+token}
        with urlopen(Request(base+'/v1/policy',headers=headers)) as response: document=json.load(response)
        document['policy']['off_price_p']=4
        request=Request(base+'/v1/policy',headers=headers,data=json.dumps(document).encode(),method='PUT')
        with urlopen(request) as response: self.assertEqual(json.load(response)['revision'],1)
        with self.assertRaises(HTTPError) as failure: urlopen(request)
        self.assertEqual(failure.exception.code,409)
        with urlopen(Request(base+'/v1/status',headers=headers)) as response:
            status=json.load(response);self.assertFalse(status['control_enabled']);self.assertEqual(status['mode'],'plan_only')
            self.assertEqual(status['heating_control']['phase'],'disabled')
            self.assertFalse(status['heating_control']['recovery_pending'])

if __name__=='__main__':unittest.main()
