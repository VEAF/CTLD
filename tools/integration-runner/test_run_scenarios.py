#!/usr/bin/env python3
"""Unit tests for run_scenarios.py's pure logic -- no network access.

Usage: python -m unittest tools/integration-runner/test_run_scenarios.py
"""
import sys
import tempfile
import unittest
# Parses only XML this same test just wrote via build_junit() -- not external/untrusted input,
# so stdlib ET is fine here (see the note in run_scenarios.py).
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import run_scenarios as rs  # noqa: E402


class ExtractTierTests(unittest.TestCase):
    def test_valid_tier(self):
        self.assertEqual(rs.extract_tier("---@diagnostic disable\n-- @tier: auto\n-- rest"), "auto")

    def test_tier_with_rationale_comment(self):
        src = "-- @tier: ia  (never resolves programmatically -- requires F10 visual confirmation)"
        self.assertEqual(rs.extract_tier(src), "ia")

    def test_missing_tier_raises(self):
        with self.assertRaises(rs.TierError):
            rs.extract_tier("-- no tier header here\nlocal x = 1")

    def test_duplicate_tier_raises(self):
        with self.assertRaises(rs.TierError):
            rs.extract_tier("-- @tier: auto\n-- @tier: ia\n")


class ParseVerdictTests(unittest.TestCase):
    def test_pass_bare(self):
        self.assertEqual(rs.parse_verdict("[F-178] PASS")[0], "PASS")

    def test_pass_with_count(self):
        self.assertEqual(rs.parse_verdict("[SCN-42] PASS 5/5")[0], "PASS")

    def test_fail_bare(self):
        self.assertEqual(rs.parse_verdict("[F-178] FAIL: S3 broke")[0], "FAIL")

    def test_fail_with_count(self):
        self.assertEqual(rs.parse_verdict("[SCN-42] FAIL 2/5: S3: x; S4: y")[0], "FAIL")

    def test_abort(self):
        self.assertEqual(rs.parse_verdict("[MT-07] ABORT: CTLD not initialized")[0], "ABORT")

    def test_running_bare(self):
        self.assertEqual(rs.parse_verdict("[FRP] RUNNING: step=2 SUCCESS")[0], "RUNNING")

    def test_started(self):
        self.assertEqual(rs.parse_verdict("[SCN-XXX] STARTED")[0], "STARTED")

    def test_none_response_is_error(self):
        self.assertEqual(rs.parse_verdict(None)[0], "ERROR")

    def test_unparsable_is_error(self):
        self.assertEqual(rs.parse_verdict("garbage, no tag or token")[0], "ERROR")


class DeriveResultVarTests(unittest.TestCase):
    def test_finds_result_var(self):
        src = 'if x then\n    _SCN_F178_RESULT = "[F-178] ABORT"\n    return _SCN_F178_RESULT\nend'
        self.assertEqual(rs.derive_result_var(src), "_SCN_F178_RESULT")

    def test_none_when_absent(self):
        self.assertIsNone(rs.derive_result_var("local x = 1\nreturn x"))


class FilterScenariosTests(unittest.TestCase):
    def _fake(self, rel_dir, name, tier):
        return rs.ScenarioInfo(path=Path(name), rel_dir=rel_dir, tier=tier)

    def setUp(self):
        self.scenarios = [
            self._fake("noPlayer", "F-001.lua", "auto"),
            self._fake("noPlayer", "scenario_scheduler.lua", "auto-check"),
            self._fake("pilotPassive", "scenario_mt07_ai_troops.lua", "ia"),
            self._fake("pilotActive", "scenario_crate_menu_sol_vol_visual.lua", "ia"),
        ]

    def test_filter_by_tier(self):
        out = rs.filter_scenarios(self.scenarios, tiers=["auto"])
        self.assertEqual([s.path.name for s in out], ["F-001.lua"])

    def test_filter_by_multiple_tiers(self):
        out = rs.filter_scenarios(self.scenarios, tiers=["auto", "auto-check"])
        self.assertEqual(len(out), 2)

    def test_filter_by_dir(self):
        out = rs.filter_scenarios(self.scenarios, dirs=["pilotActive"])
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0].rel_dir, "pilotActive")

    def test_filter_by_scenario_substring(self):
        out = rs.filter_scenarios(self.scenarios, scenario_glob="mt07")
        self.assertEqual(len(out), 1)

    def test_no_filters_returns_all(self):
        out = rs.filter_scenarios(self.scenarios)
        self.assertEqual(len(out), 4)


class DiscoverScenariosTests(unittest.TestCase):
    def test_discovers_and_skips_templates(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / "tests" / "dcs" / "noPlayer"
            folder.mkdir(parents=True)
            (folder / "F-001.lua").write_text("-- @tier: auto\n", encoding="utf-8")
            (folder / "_template_noPlayer.lua").write_text("-- @tier: auto\n", encoding="utf-8")
            scenarios = rs.discover_scenarios(root=root, dirs=("noPlayer",))
            self.assertEqual(len(scenarios), 1)
            self.assertEqual(scenarios[0].path.name, "F-001.lua")

    def test_untagged_files_are_skipped_not_fatal(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            folder = root / "tests" / "dcs" / "noPlayer"
            folder.mkdir(parents=True)
            (folder / "F-001.lua").write_text("-- @tier: auto\n", encoding="utf-8")
            (folder / "relic.lua").write_text("-- no tier header, dead legacy file\n", encoding="utf-8")
            skipped = []
            scenarios = rs.discover_scenarios(
                root=root, dirs=("noPlayer",),
                on_skip=lambda path, reason: skipped.append((path.name, reason)),
            )
            self.assertEqual([s.path.name for s in scenarios], ["F-001.lua"])
            self.assertEqual(len(skipped), 1)
            self.assertEqual(skipped[0][0], "relic.lua")


class JunitTests(unittest.TestCase):
    def test_round_trips_and_counts_failures(self):
        scenario = rs.ScenarioInfo(path=Path("F-001.lua"), rel_dir="noPlayer", tier="auto")
        results = [
            rs.ScenarioResult(scenario, "PASS", "[F-001] PASS", 0.5),
            rs.ScenarioResult(scenario, "FAIL", "[F-001] FAIL: boom", 0.3),
        ]
        tree = rs.build_junit(results)
        with tempfile.NamedTemporaryFile(suffix=".xml", delete=False) as f:
            tree.write(f.name, encoding="utf-8", xml_declaration=True)
            parsed = ET.parse(f.name)
        root = parsed.getroot()
        self.assertEqual(root.attrib["tests"], "2")
        self.assertEqual(root.attrib["failures"], "1")
        testcases = root.findall("testcase")
        self.assertEqual(len(testcases), 2)
        self.assertEqual(len(testcases[1].findall("failure")), 1)
        self.assertEqual(len(testcases[0].findall("failure")), 0)


class ReadSimpleConfigTests(unittest.TestCase):
    def test_missing_file_returns_defaults(self):
        cfg = rs.read_simple_config(Path("/nonexistent/dcs-client.yaml"))
        self.assertEqual(cfg["host"], "127.0.0.1")
        self.assertEqual(cfg["port"], 8080)
        self.assertEqual(cfg["api_key"], "")

    def test_reads_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "dcs-client.yaml"
            path.write_text('host: "192.168.1.10"\nport: 9090\napi_key: "secret123"\n', encoding="utf-8")
            cfg = rs.read_simple_config(path)
            self.assertEqual(cfg["host"], "192.168.1.10")
            self.assertEqual(cfg["port"], 9090)
            self.assertEqual(cfg["api_key"], "secret123")

    def test_ignores_unknown_keys_and_comments(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "dcs-client.yaml"
            path.write_text("# a comment\nhost: localhost\nweb_port: 8081\n", encoding="utf-8")
            cfg = rs.read_simple_config(path)
            self.assertEqual(cfg["host"], "localhost")
            self.assertNotIn("web_port", cfg)


class RunScenarioTests(unittest.TestCase):
    def _write_scenario(self, tmp, text):
        path = Path(tmp) / "scenario.lua"
        path.write_text(text, encoding="utf-8")
        return rs.ScenarioInfo(path=path, rel_dir="noPlayer", tier="auto")

    def test_synchronous_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: auto\nreturn 1")
            calls = []

            def http_post(code):
                calls.append(code)
                return "[F-001] PASS 3/3", None

            result = rs.run_scenario(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(result.verdict, "PASS")
            self.assertEqual(len(calls), 1)

    def test_async_resolves_after_polling(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: auto-check\n_SCN_SCHED_RESULT = 'x'\nreturn _SCN_SCHED_RESULT")
            responses = iter([
                ("[SCHED] STARTED", None),
                ("[SCHED] STARTED", None),
                ("[SCHED] PASS 2/2", None),
            ])

            def http_post(code):
                return next(responses)

            times = iter([0.0, 0.1, 0.2, 0.3, 0.4])
            result = rs.run_scenario(
                scenario, http_post, poll_interval=0, poll_timeout=10,
                sleep=lambda s: None, now=lambda: next(times),
            )
            self.assertEqual(result.verdict, "PASS")

    def test_poll_timeout_reports_fail(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(
                tmp, "-- @tier: auto-check\n_SCN_X_RESULT = 'x'\nreturn _SCN_X_RESULT")

            def http_post(code):
                return "[X] STARTED", None

            # now() exceeds the poll_timeout deadline immediately
            times = iter([0.0] + [100.0] * 10)
            result = rs.run_scenario(
                scenario, http_post, poll_interval=0, poll_timeout=5,
                sleep=lambda s: None, now=lambda: next(times),
            )
            self.assertEqual(result.verdict, "FAIL")
            self.assertIn("timeout", result.message)

    def test_running_token_reinjects_full_source_to_advance(self):
        with tempfile.TemporaryDirectory() as tmp:
            # auto-check scenario using the RUNNING/re-injection pattern (no physical DCS-side
            # action needed between steps -- just a timed delay, safe to automate headlessly).
            source = "-- @tier: auto-check\n_SCN_JTAC_RESULT = 'x'\nreturn _SCN_JTAC_RESULT"
            scenario = self._write_scenario(tmp, source)
            calls = []
            responses = iter([
                ("[JTAC] RUNNING: step=1 SUCCESS", None),  # injection
                ("[JTAC] RUNNING: step=2 SUCCESS", None),  # re-injection 1
                ("[JTAC] PASS (120ms)", None),              # re-injection 2 -- terminal
            ])

            def http_post(code):
                calls.append(code)
                return next(responses)

            result = rs.run_scenario(scenario, http_post, poll_interval=0, sleep=lambda s: None)
            self.assertEqual(result.verdict, "PASS")
            self.assertEqual(len(calls), 3)
            self.assertEqual(calls[1], source)
            self.assertEqual(calls[2], source)

    def test_running_token_that_never_resolves_times_out(self):
        with tempfile.TemporaryDirectory() as tmp:
            # A RUNNING-pattern scenario genuinely needing a physical DCS-side action (e.g. an
            # ia-tier scenario reached via an explicit --tier ia) just spins harmlessly until
            # poll_timeout instead of making progress -- reported as FAIL, not a crash.
            scenario = self._write_scenario(
                tmp, "-- @tier: ia\n_SCN_FRP_RESULT = 'x'\nreturn _SCN_FRP_RESULT")

            def http_post(code):
                return "[FRP] RUNNING: step=2 waiting for landing", None

            times = iter([0.0] + [100.0] * 10)
            result = rs.run_scenario(
                scenario, http_post, poll_interval=0, poll_timeout=5,
                sleep=lambda s: None, now=lambda: next(times),
            )
            self.assertEqual(result.verdict, "FAIL")
            self.assertIn("timeout", result.message)

    def test_http_error_is_reported(self):
        with tempfile.TemporaryDirectory() as tmp:
            scenario = self._write_scenario(tmp, "-- @tier: auto\nreturn 1")

            def http_post(code):
                return None, "connection error: refused"

            result = rs.run_scenario(scenario, http_post, sleep=lambda s: None)
            self.assertEqual(result.verdict, "ERROR")
            self.assertIn("refused", result.message)


if __name__ == "__main__":
    unittest.main()
