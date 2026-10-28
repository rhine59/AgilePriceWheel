"""No network calls: explicit live flag and stop-only recovery adapter checks."""
import importlib.util
from pathlib import Path
import sys,threading,unittest
from unittest.mock import Mock,patch
root=Path(__file__).resolve().parents[1]/'examples'
sys.path.insert(0,str(root))
spec=importlib.util.spec_from_file_location('supervised_boost_target_example',root/'supervised_boost_target.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class ProbeCLITests(unittest.TestCase):
    def test_run_requires_approval_before_reading_credentials(self):
        args=['run','--state-file','unused','--installation-file','unused','--homely-env-file','unused','--controller-url','https://example.com','--key-file','unused']
        with patch.object(module,'Adapter') as adapter:
            with self.assertRaises(SystemExit) as e:module.main(args)
            self.assertEqual(e.exception.code,2);adapter.assert_not_called()
    def test_stop_requires_explicit_approval_flag_too(self):
        args=['stop','--state-file','unused','--installation-file','unused','--homely-env-file','unused','--controller-url','https://example.com','--key-file','unused']
        with patch.object(module,'Adapter') as adapter:
            with self.assertRaises(SystemExit):module.main(args)
            adapter.assert_not_called()
    def test_stop_uses_its_own_session_after_main_session_lost(self):
        a=module.Adapter.__new__(module.Adapter);a.stop_lock=threading.Lock();a.stopper=Mock();a.observer=Mock(client=None)
        a.stop_only();a.stopper.set_disabled.assert_called_once_with(True);a.stopper.cancel_boost.assert_called_once_with()
    def test_disable_failure_cannot_skip_cancellation(self):
        a=module.Adapter.__new__(module.Adapter);a.stop_lock=threading.Lock();a.stopper=Mock();a.stopper.set_disabled.side_effect=TimeoutError()
        with self.assertRaises(RuntimeError):a.stop_only()
        a.stopper.set_disabled.assert_called_once_with(True);a.stopper.cancel_boost.assert_called_once_with()
    def test_help_default_never_constructs_live_adapter(self):
        with patch.object(sys,'argv',['supervised_boost_target.py']),patch.object(module,'Adapter') as adapter:
            self.assertEqual(module.main(),0);adapter.assert_not_called()

    def test_local_mode_cannot_send_key_to_external_http(self):
        from types import SimpleNamespace
        args=SimpleNamespace(local_controller=True,controller_url='http://example.com')
        with patch.object(module,'ObservedHomely') as observer:
            with self.assertRaises(ValueError):module.Adapter(args,{},None)
            observer.assert_not_called()

    def test_armed_claim_is_private_and_cannot_be_replayed(self):
        from types import SimpleNamespace
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            a=module.Adapter.__new__(module.Adapter);a.args=SimpleNamespace(state_file=Path(d)/'probe.json');a.trace=Mock()
            a.note('armed',maximum_seconds=60)
            claim=Path(d)/'probe-attempt.json';self.assertEqual(claim.stat().st_mode&0o777,0o600)
            with self.assertRaises(FileExistsError):a.note('armed',maximum_seconds=60)
            self.assertEqual(a.trace.write.call_count,1)
