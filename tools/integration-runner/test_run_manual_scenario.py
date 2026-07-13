#!/usr/bin/env python3
"""Unit tests for run_manual_scenario.py's pure logic -- no network access.

Usage: python -m unittest tools/integration-runner/test_run_manual_scenario.py
"""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import run_manual_scenario as rms  # noqa: E402
import run_scenarios as rs  # noqa: E402


class DeriveInstrVarTests(unittest.TestCase):
    def test_finds_instr_var(self):
        source = 'local x = 1\n_SCN_CMFV_INSTR = "hello"\n'
        self.assertEqual(rms.derive_instr_var(source), "_SCN_CMFV_INSTR")

    def test_none_when_absent(self):
        self.assertIsNone(rms.derive_instr_var("return 1"))

    def test_finds_compound_id_instr_var(self):
        self.assertEqual(rms.derive_instr_var("_SCN_FI_ATK_INSTR = ''"), "_SCN_FI_ATK_INSTR")


class DeriveCleanupVarTests(unittest.TestCase):
    def test_finds_cleanup_var(self):
        source = "_SCN_TMFV_CLEANUP = cleanup\n"
        self.assertEqual(rms.derive_cleanup_var(source), "_SCN_TMFV_CLEANUP")

    def test_none_when_absent(self):
        self.assertIsNone(rms.derive_cleanup_var("return 1"))


class FmtElapsedTests(unittest.TestCase):
    def test_under_a_minute(self):
        self.assertEqual(rms._fmt_elapsed(5), "0:05")

    def test_minutes_seconds(self):
        self.assertEqual(rms._fmt_elapsed(150), "2:30")

    def test_past_an_hour(self):
        self.assertEqual(rms._fmt_elapsed(3661), "1:01:01")


class ResetStuckStateTests(unittest.TestCase):
    def test_noop_when_no_cleanup_var(self):
        calls = []
        rms.reset_stuck_state(lambda code: calls.append(code) or (None, None), None)
        self.assertEqual(calls, [])

    def test_calls_cleanup_guarded_by_nil_check(self):
        calls = []

        def http_post(code):
            calls.append(code)
            return "reset", None

        rms.reset_stuck_state(http_post, "_SCN_CMFV_CLEANUP")
        self.assertEqual(len(calls), 1)
        self.assertIn("if _SCN_CMFV_CLEANUP then _SCN_CMFV_CLEANUP() end", calls[0])


class RunInteractiveTests(unittest.TestCase):
    def _write_scenario(self, tmp, text):
        path = Path(tmp) / "scenario.lua"
        path.write_text(text, encoding="utf-8")
        return rs.ScenarioInfo(path=path, rel_dir="pilotActive", tier="human")

    def test_reset_source_injected_before_scenario(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: human\nreturn 1")
            calls = []

            def http_post(code):
                calls.append(code)
                return "[F-046] PASS", None

            code = rms.run_interactive(scenario, http_post, sleep=lambda s: None,
                                       reset_source="-- RESET SNIPPET --")
            self.assertEqual(code, 0)
            # No _SCN_*_CLEANUP in the scenario, so no reset_stuck_state call; the shared reset
            # snippet must be posted before the scenario source.
            self.assertIn("-- RESET SNIPPET --", calls)
            self.assertLess(calls.index("-- RESET SNIPPET --"),
                            next(i for i, c in enumerate(calls) if "@tier: human" in c))

    def test_terminal_pass_on_first_injection(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: human\nreturn 1")

            def http_post(code):
                return "[F-046] PASS", None

            code = rms.run_interactive(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(code, 0)

    def test_polls_until_pass_and_mirrors_instructions(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp,
                "-- @tier: human\n_SCN_TMFV_INSTR = ''\n_SCN_TMFV_RESULT = 'x'\n"
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

            code = rms.run_interactive(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(code, 0)
            self.assertEqual(len(calls), 6)
            # First call must be the reset-guard, second the actual injection (full source).
            self.assertIn("_SCN_TMFV_CLEANUP", calls[0])
            self.assertIn("_SCN_TMFV_RESULT", calls[1])

    def test_fail_verdict_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: human\n_SCN_X_RESULT = 'x'\nreturn _SCN_X_RESULT")
            responses = iter([
                ("[X] STARTED", None),
                ("[X] FAIL 1/5: something broke", None),
            ])

            def http_post(code):
                return next(responses)

            code = rms.run_interactive(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(code, 1)

    def test_running_token_reinjects_full_source_to_advance(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = "-- @tier: human\n_SCN_JTAC_RESULT = 'x'\nreturn _SCN_JTAC_RESULT"
            scenario = self._write_scenario(tmp, source)
            calls = []
            responses = iter([
                ("[JTAC] RUNNING: step=1 SUCCESS", None),  # injection
                ("[JTAC] RUNNING: step=2 SUCCESS", None),  # re-injection 1
                ("[JTAC] PASS (120ms)", None),             # re-injection 2 -- terminal
            ])

            def http_post(code):
                calls.append(code)
                return next(responses)

            code = rms.run_interactive(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(code, 0)
            self.assertEqual(len(calls), 3)
            # Every call after the RUNNING verdict must re-post the FULL source, not a small
            # "return <var>" poll -- that's what actually advances the step machine.
            self.assertEqual(calls[1], source)
            self.assertEqual(calls[2], source)

    def test_progress_prints_on_message_change_even_if_token_unchanged(self):
        # Regression: a multi-step RUNNING-pattern scenario's message advances every step
        # (step=1 -> step=7) while the token itself stays "RUNNING" throughout. Printing only
        # on a token change would show nothing at all during a long-running step, making a
        # slow-but-healthy scenario indistinguishable from a hung one.
        with tempfile.TemporaryDirectory() as tmp:
            source = "-- @tier: auto-check\n_SCN_TFC_RESULT = 'x'\nreturn _SCN_TFC_RESULT"
            scenario = self._write_scenario(tmp, source)
            responses = iter([
                ("[TFC] RUNNING: step=1 SUCCESS", None),  # injection
                ("[TFC] RUNNING: step=7 MONITORING", None),  # re-injection -- same token, new message
                ("[TFC] PASS", None),                      # re-injection -- terminal
            ])

            def http_post(code):
                return next(responses)

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                code = rms.run_interactive(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(code, 0)
            output = buf.getvalue()
            self.assertIn("step=1 SUCCESS", output)
            self.assertIn("step=7 MONITORING", output)

    def test_heartbeat_prints_when_nothing_changes(self):
        # A long STARTED scenario can go minutes with the same message. The heartbeat must emit
        # a "still running" line (with elapsed stamp) every heartbeat_interval so it doesn't
        # look hung. Drive a controllable clock so elapsed time advances deterministically.
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: auto-check\n_SCN_X_RESULT = 'x'\nreturn _SCN_X_RESULT")
            responses = iter([
                ("[X] STARTED", None),  # injection
                ("[X] STARTED", None),  # poll 1 -- unchanged
                ("[X] STARTED", None),  # poll 2 -- unchanged
                ("[X] PASS", None),     # poll 3 -- terminal
            ])
            # now() advances 20s per call; heartbeat_interval=30 -> fires by poll 2.
            ticks = iter([0, 20, 40, 60, 80, 100, 120, 140, 160])

            def http_post(code):
                return next(responses)

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                code = rms.run_interactive(
                    scenario, http_post, poll_interval=0, heartbeat_interval=30,
                    sleep=lambda s: None, now=lambda: next(ticks))
            self.assertEqual(code, 0)
            self.assertIn("still running", buf.getvalue())

    def test_heartbeat_echoes_last_instruction_not_static_result(self):
        # For a STARTED-pattern scenario the RESULT message stays "STARTED" the whole run; real
        # progress arrives via the instruction mirror. The heartbeat's "last:" must reflect the
        # latest instruction line, not the frozen RESULT message.
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp,
                "-- @tier: auto-check\n_SCN_X_INSTR = ''\n_SCN_X_RESULT = 'x'\n"
                "return _SCN_X_RESULT",
            )
            state = {"n": 0}

            def http_post(code):
                # First call is the injection (full source).
                if "_SCN_X_INSTR" in code and "return" in code and len(code) < 40:
                    return "[X] [PASS] DRONE.V2: lasing 'Sol_g-2-1'  (3 ok / 0 fail)", None
                if "return _SCN_X_RESULT" == code.strip():
                    state["n"] += 1
                    return ("[X] PASS", None) if state["n"] >= 3 else ("[X] STARTED", None)
                return "[X] STARTED", None  # injection

            ticks = iter([0, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220])
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                code = rms.run_interactive(
                    scenario, http_post, poll_interval=0, heartbeat_interval=30,
                    sleep=lambda s: None, now=lambda: next(ticks))
            self.assertEqual(code, 0)
            out = buf.getvalue()
            # The heartbeat line must carry the instruction progress, not "STARTED".
            hb = [ln for ln in out.splitlines() if "still running" in ln]
            self.assertTrue(hb, "expected at least one heartbeat line")
            self.assertIn("DRONE.V2", hb[-1])

    def test_transient_poll_error_is_tolerated_then_recovers(self):
        # A single HTTP 504 mid-poll must not abort a long run: keep polling, and a subsequent
        # good poll resolves normally.
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: auto-check\n_SCN_X_RESULT = 'x'\nreturn _SCN_X_RESULT")
            responses = iter([
                ("[X] STARTED", None),          # injection
                (None, "HTTP 504: timeout"),    # poll 1 -- transient error
                ("[X] STARTED", None),          # poll 2 -- recovered, still running
                ("[X] PASS", None),             # poll 3 -- terminal
            ])

            def http_post(code):
                return next(responses)

            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                code = rms.run_interactive(scenario, http_post, poll_interval=0,
                                            sleep=lambda s: None)
            self.assertEqual(code, 0)

    def test_sustained_poll_errors_give_up(self):
        # Past max_errors consecutive failures (dcs-serve down, mission unloaded), give up.
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: auto-check\n_SCN_X_RESULT = 'x'\nreturn _SCN_X_RESULT")

            def http_post(code):
                if code.strip() == "return _SCN_X_RESULT":
                    return None, "HTTP 504: timeout"
                return "[X] STARTED", None  # injection succeeds

            code = rms.run_interactive(scenario, http_post, poll_interval=0, max_errors=3,
                                        sleep=lambda s: None)
            self.assertEqual(code, 1)

    def test_http_error_on_injection_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: human\nreturn 1")

            def http_post(code):
                return None, "connection error: refused"

            code = rms.run_interactive(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(code, 1)

    def test_missing_result_var_after_started_returns_nonzero(self):
        with tempfile.TemporaryDirectory() as tmp:
            # STARTED but no _SCN_<ID>_RESULT global anywhere in source -- can't poll.
            scenario = self._write_scenario(tmp, "-- @tier: human\nreturn 'STARTED'")

            def http_post(code):
                return "[X] STARTED", None

            code = rms.run_interactive(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
