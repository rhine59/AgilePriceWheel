"""Launcher gates: no SSH or credentials are accessed by these tests."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch
p=Path(__file__).resolve().parents[1]/'examples/launch_supervised_probe.py'
s=importlib.util.spec_from_file_location('probe_launcher',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class LauncherTests(unittest.TestCase):
    def test_run_without_approval_never_opens_ssh(self):
        args=['run','--ssh-target','example@nas.example.com','--installation-file','missing','--state-file','/data/supervised-target-test.json']
        with patch.object(m.subprocess,'run') as ssh:
            with self.assertRaises(SystemExit) as error:m.main(args)
            self.assertEqual(error.exception.code,2);ssh.assert_not_called()
    def test_runtime_policy_file_is_not_a_probe_state_file(self):
        args=['prepare','--ssh-target','example@nas.example.com','--installation-file','missing','--state-file','/data/policy.json']
        with patch.object(m.subprocess,'run') as ssh:
            with self.assertRaises(SystemExit):m.main(args)
            ssh.assert_not_called()
    def test_parent_paths_are_not_accepted_for_state(self):
        args=['prepare','--ssh-target','example@nas.example.com','--installation-file','missing','--state-file','/data/../data/supervised-target-test.json']
        with patch.object(m.subprocess,'run') as ssh:
            with self.assertRaises(SystemExit):m.main(args)
            ssh.assert_not_called()
