#!/usr/bin/env python3
"""Unit tests for run_ia_scenario.py's pure logic -- no network access.

Usage: python -m unittest tools/integration-runner/test_run_ia_scenario.py
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import run_ia_scenario as ria  # noqa: E402
import run_scenarios as rs  # noqa: E402


class DeriveInstrVarTests(unittest.TestCase):
    def test_finds_instr_var(self):
        source = 'local x = 1\n_SCN_CMFV_INSTR = "hello"\n'
        self.assertEqual(ria.derive_instr_var(source), "_SCN_CMFV_INSTR")

    def test_none_when_absent(self):
        self.assertIsNone(ria.derive_instr_var("return 1"))


class DeriveCleanupVarTests(unittest.TestCase):
    def test_finds_cleanup_var(self):
        source = "_SCN_TMFV_CLEANUP = cleanup\n"
        self.assertEqual(ria.derive_cleanup_var(source), "_SCN_TMFV_CLEANUP")

    def test_none_when_absent(self):
        self.assertIsNone(ria.derive_cleanup_var("return 1"))


class ResetStuckStateTests(unittest.TestCase):
    def test_noop_when_no_cleanup_var(self):
        calls = []
        ria.reset_stuck_state(lambda code: calls.append(code) or (None, None), None)
        self.assertEqual(calls, [])

    def test_calls_cleanup_guarded_by_nil_check(self):
        calls = []

        def http_post(code):
            calls.append(code)
            return "reset", None

        ria.reset_stuck_state(http_post, "_SCN_CMFV_CLEANUP")
        self.assertEqual(len(calls), 1)
        self.assertIn("if _SCN_CMFV_CLEANUP then _SCN_CMFV_CLEANUP() end", calls[0])


class RunInteractiveTests(unittest.TestCase):
    def _write_scenario(self, tmp, text):
        path = Path(tmp) / "scenario.lua"
        path.write_text(text, encoding="utf-8")
        return rs.ScenarioInfo(path=path, rel_dir="pilotActive", tier="ia")

    def test_terminal_pass_on_first_injection(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: ia\nreturn 1")

            def http_post(code):
                return "[F-046] PASS", None

            code = ria.run_interactive(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(code, 0)

    def test_polls_until_pass_and_mirrors_instructions(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp,
                "-- @tier: ia\n_SCN_TMFV_INSTR = ''\n_SCN_TMFV_RESULT = 'x'\n"
                "_SCN_TMFV_CLEANUP = cleanup\nreturn _SCN_TMFV_RESULT",
            )
            calls = []
            responses = iter([
                ("reset", None),                     # reset-guard (return value ignored)
                ("[TMFV] STARTED", None),            # injection
                ("Step 1/5 instructions", None),      # instr poll, iteration 1
                ("[TMFV] STARTED", None),            # result poll, iteration 1 -- still running
                ("Step 1/5 instructions", None),      # instr poll, iteration 2 (unchanged, no reprint)
                ("[TMFV] PASS 5/5", None),            # result poll, iteration 2 -- terminal
            ])

            def http_post(code):
                calls.append(code)
                return next(responses)

            code = ria.run_interactive(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(code, 0)
            self.assertEqual(len(calls), 6)
            # First call must be the reset-guard, second the actual injection (full source).
            self.assertIn("_SCN_TMFV_CLEANUP", calls[0])
            self.assertIn("_SCN_TMFV_RESULT", calls[1])

    def test_fail_verdict_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: ia\n_SCN_X_RESULT = 'x'\nreturn _SCN_X_RESULT")
            responses = iter([
                ("[X] STARTED", None),
                ("[X] FAIL 1/5: something broke", None),
            ])

            def http_post(code):
                return next(responses)

            code = ria.run_interactive(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(code, 1)

    def test_http_error_on_injection_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: ia\nreturn 1")

            def http_post(code):
                return None, "connection error: refused"

            code = ria.run_interactive(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(code, 1)

    def test_missing_result_var_after_started_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            # STARTED but no _SCN_<ID>_RESULT global anywhere in source -- can't poll.
            scenario = self._write_scenario(tmp, "-- @tier: ia\nreturn 'STARTED'")

            def http_post(code):
                return "[X] STARTED", None

            code = ria.run_interactive(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
