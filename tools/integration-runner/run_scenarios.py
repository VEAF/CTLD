#!/usr/bin/env python3
"""Headless runner for tests/dcs/ scenarios over VEAF-dcs-bridge.

Discovers scenarios under tests/dcs/{noPlayer,pilotActive,pilotPassive}/, filters them by
their `-- @tier:` header, injects each one via dcs-serve's POST /api/exec, parses the return
contract's verdict (see the integration-testing skill), polls async (STARTED) scenarios to
resolution, and writes a JUnit XML report.

Zero external dependencies (stdlib only) -- see tools/dcs-data/gen_dcs_types.py for the same
convention. Talks to dcs-serve directly over REST; no MCP client involved.

Usage (from repo root):
    python tools/integration-runner/run_scenarios.py --no-ai --junit-out test-results.xml
    python tools/integration-runner/run_scenarios.py --list
    python tools/integration-runner/run_scenarios.py --dir noPlayer --tier auto

See tools/integration-runner/README.md for the full flag reference and prerequisites.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
# xml.etree.ElementTree is used to WRITE the JUnit report only -- this module never parses
# XML from an external/untrusted source (no XXE exposure). Stdlib only, per the project's
# dependency-free tooling convention (see tools/dcs-data/gen_dcs_types.py). If a future change
# adds parsing of externally-sourced XML, switch that path to defusedxml.
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SCENARIO_DIRS = ("noPlayer", "pilotActive", "pilotPassive")
TIERS = ("auto", "auto-check", "ia")
NO_AI_TIERS = ("auto", "auto-check")

TIER_RE = re.compile(r"^\s*--\s*@tier:\s*(\S+)", re.MULTILINE)
VERDICT_RE = re.compile(r"\[[^\]]*\]\s*(PASS|FAIL|ABORT|RUNNING|STARTED)\b(.*)", re.DOTALL)
RESULT_VAR_RE = re.compile(r"_SCN_[A-Za-z0-9]+_RESULT")

TERMINAL_VERDICTS = ("PASS", "FAIL", "ABORT")


class TierError(ValueError):
    """A scenario file has no (or more than one) `-- @tier:` header."""


@dataclass
class ScenarioInfo:
    path: Path
    rel_dir: str
    tier: str


@dataclass
class ScenarioResult:
    scenario: ScenarioInfo
    verdict: str  # PASS | FAIL | ABORT | ERROR
    message: str
    elapsed: float = 0.0


# ---------------------------------------------------------------------------
# Pure logic (unit-tested in test_run_scenarios.py without any network access)
# ---------------------------------------------------------------------------


def extract_tier(source: str) -> str:
    """Return the scenario's `-- @tier:` value. Raises TierError if absent/duplicated."""
    matches = TIER_RE.findall(source)
    if len(matches) == 0:
        raise TierError("no '-- @tier:' header found")
    if len(matches) > 1:
        raise TierError("multiple '-- @tier:' headers found: %r" % matches)
    return matches[0]


def discover_scenarios(root: Path = REPO_ROOT, dirs=SCENARIO_DIRS, on_skip=None) -> list[ScenarioInfo]:
    """Walk tests/dcs/{dirs}/*.lua (skipping _template_*.lua) and read each @tier header.

    Files with no (or a malformed) `-- @tier:` header are skipped, not fatal -- as of this
    writing tests/dcs/noPlayer/ still holds ~194 untagged dead FullGas relics (tracked
    separately as CLEANUP-LEGACY-DCS-TESTS) that must not break discovery for everything else.
    `on_skip(path, reason)`, if given, is called once per skipped file.
    """
    scenarios = []
    for d in dirs:
        folder = root / "tests" / "dcs" / d
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.lua")):
            if path.name.startswith("_"):
                continue
            try:
                tier = extract_tier(path.read_text(encoding="utf-8"))
            except TierError as e:
                if on_skip:
                    on_skip(path, str(e))
                continue
            scenarios.append(ScenarioInfo(path=path, rel_dir=d, tier=tier))
    return scenarios


def filter_scenarios(scenarios, tiers=None, dirs=None, scenario_glob=None):
    """Filter a scenario list by tier(s), folder(s), and/or a filename glob/substring."""
    out = scenarios
    if dirs:
        wanted = set(dirs)
        out = [s for s in out if s.rel_dir in wanted]
    if tiers:
        wanted = set(tiers)
        out = [s for s in out if s.tier in wanted]
    if scenario_glob:
        out = [s for s in out if scenario_glob in s.path.name]
    return out


def parse_verdict(raw) -> tuple[str, str]:
    """Parse a dcs-serve exec result into (token, message). token is one of
    PASS/FAIL/ABORT/RUNNING/STARTED/ERROR ("ERROR" = unparsable / no response)."""
    if raw is None:
        return ("ERROR", "no response")
    match = VERDICT_RE.search(raw)
    if not match:
        return ("ERROR", "unparsable response: %r" % raw)
    return (match.group(1), raw.strip())


def derive_result_var(source: str) -> str | None:
    """Find the `_SCN_<ID>_RESULT` global a scenario uses, or None if not found."""
    match = RESULT_VAR_RE.search(source)
    return match.group(0) if match else None


def build_junit(results: list[ScenarioResult], suite_name="dcs-integration-tests") -> ET.ElementTree:
    failures = sum(1 for r in results if r.verdict != "PASS")
    root = ET.Element(
        "testsuite",
        name=suite_name,
        tests=str(len(results)),
        failures=str(failures),
    )
    for r in results:
        testcase = ET.SubElement(
            root,
            "testcase",
            classname=r.scenario.rel_dir,
            name=r.scenario.path.name,
            time="%.2f" % r.elapsed,
        )
        if r.verdict != "PASS":
            failure = ET.SubElement(testcase, "failure", message=r.message[:500])
            failure.text = r.message
    return ET.ElementTree(root)


def read_simple_config(path: Path) -> dict:
    """Minimal flat `key: value` reader for dcs-client.yaml (host/port/api_key only --
    not general YAML; the file's actual shape is a handful of scalar lines)."""
    cfg = {"host": "127.0.0.1", "port": 8080, "api_key": ""}
    if not path.exists():
        return cfg
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line or ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key not in cfg:
            continue
        if key == "port":
            try:
                value = int(value)
            except ValueError:
                continue
        cfg[key] = value
    return cfg


# ---------------------------------------------------------------------------
# Orchestration (http_post/sleep/now injected so this is unit-testable too)
# ---------------------------------------------------------------------------


def run_scenario(scenario: ScenarioInfo, http_post, poll_interval=2.0, poll_timeout=60.0,
                  sleep=time.sleep, now=time.monotonic) -> ScenarioResult:
    """Run one scenario to a terminal verdict, polling if it starts async."""
    start = now()
    source = scenario.path.read_text(encoding="utf-8")
    raw, err = http_post(source)
    if err:
        return ScenarioResult(scenario, "ERROR", err, now() - start)
    token, message = parse_verdict(raw)

    if token in TERMINAL_VERDICTS:
        return ScenarioResult(scenario, token, message, now() - start)

    if token == "RUNNING":
        return ScenarioResult(
            scenario, "FAIL",
            "RUNNING-pattern scenario requires re-injection after a physical DCS-side action "
            "-- not runnable headlessly: " + message,
            now() - start,
        )

    if token != "STARTED":
        return ScenarioResult(scenario, "ERROR", message, now() - start)

    result_var = derive_result_var(source)
    if not result_var:
        return ScenarioResult(
            scenario, "ERROR",
            "STARTED but no _SCN_<ID>_RESULT variable found in source", now() - start,
        )

    deadline = start + poll_timeout
    while now() < deadline:
        sleep(poll_interval)
        raw, err = http_post("return %s" % result_var)
        if err:
            return ScenarioResult(scenario, "ERROR", err, now() - start)
        token, message = parse_verdict(raw)
        if token in TERMINAL_VERDICTS:
            return ScenarioResult(scenario, token, message, now() - start)
        if token == "RUNNING":
            return ScenarioResult(
                scenario, "FAIL",
                "RUNNING-pattern scenario requires re-injection after a physical DCS-side "
                "action -- not runnable headlessly: " + message,
                now() - start,
            )
        # still STARTED -- keep polling

    return ScenarioResult(
        scenario, "FAIL",
        "poll timeout after %.0fs, still: %s" % (poll_timeout, message), now() - start,
    )


# ---------------------------------------------------------------------------
# Network I/O
# ---------------------------------------------------------------------------


def make_http_post(host, port, api_key, exec_timeout=None, http_timeout=30):
    base_url = "http://%s:%s" % (host, port)

    def http_post(code):
        body = {"code": code}
        if exec_timeout is not None:
            body["timeout"] = exec_timeout
        req = urllib.request.Request(
            base_url + "/api/exec",
            data=json.dumps(body).encode("utf-8"),
            headers={"Content-Type": "application/json", "X-API-Key": api_key},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=http_timeout) as resp:
                data = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            return None, "HTTP %d: %s" % (e.code, e.read().decode("utf-8", "replace"))
        except urllib.error.URLError as e:
            return None, "connection error: %s" % e.reason
        if data.get("error"):
            return None, data["error"]
        return data.get("result", ""), None

    return http_post


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def build_arg_parser():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--config", type=Path, default=REPO_ROOT / "dcs-client.yaml",
                    help="Path to dcs-client.yaml (default: repo root)")
    p.add_argument("--host", help="Override dcs-serve host")
    p.add_argument("--port", type=int, help="Override dcs-serve port")
    p.add_argument("--api-key", help="Override dcs-serve API key")
    p.add_argument("--tier", help="Comma-separated tiers to include (default: all)")
    p.add_argument("--no-ai", action="store_true", help="Shorthand for --tier auto,auto-check")
    p.add_argument("--dir", help="Comma-separated scenario folders (noPlayer,pilotActive,pilotPassive)")
    p.add_argument("--scenario", help="Only run scenarios whose filename contains this substring")
    p.add_argument("--inject-ctld", action="store_true",
                    help="Inject CTLD.lua from repo root before running scenarios")
    p.add_argument("--init-wait", type=float, default=4.0,
                    help="Seconds to wait after injecting CTLD.lua (default: 4)")
    p.add_argument("--poll-interval", type=float, default=2.0,
                    help="Seconds between polls of an async scenario's result (default: 2)")
    p.add_argument("--poll-timeout", type=float, default=60.0,
                    help="Max seconds to poll before giving up (default: 60)")
    p.add_argument("--exec-timeout", type=float, default=None,
                    help="Per-request timeout passed to dcs-serve (default: server default)")
    p.add_argument("--junit-out", type=Path, default=REPO_ROOT / "test-results.xml",
                    help="Where to write the JUnit XML report (default: ./test-results.xml)")
    p.add_argument("--list", action="store_true",
                    help="List selected scenarios and exit -- no network calls")
    p.add_argument("--show-skipped", action="store_true",
                    help="List files skipped for having no valid '-- @tier:' header")
    return p


def main(argv=None) -> int:
    # Scenario messages may contain non-ASCII characters (e.g. arrows, accented text from
    # French comments echoed back). The default console codepage on Windows (cp1252) can't
    # encode all of them and would crash a plain print() -- force UTF-8 with a safe fallback.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    args = build_arg_parser().parse_args(argv)

    tiers = args.tier.split(",") if args.tier else (list(NO_AI_TIERS) if args.no_ai else None)
    dirs = args.dir.split(",") if args.dir else None

    skipped = []
    scenarios = discover_scenarios(on_skip=lambda path, reason: skipped.append((path, reason)))
    scenarios = filter_scenarios(scenarios, tiers=tiers, dirs=dirs, scenario_glob=args.scenario)

    if skipped:
        print(
            "Skipped %d untagged file(s) with no valid '-- @tier:' header (run with "
            "--show-skipped to list them)." % len(skipped),
            file=sys.stderr,
        )
        if args.show_skipped:
            for path, reason in skipped:
                print("  %s: %s" % (path, reason), file=sys.stderr)

    if not scenarios:
        print("No scenarios matched the given filters.", file=sys.stderr)
        return 1

    if args.list:
        for s in scenarios:
            print("%-7s %s/%s" % (s.tier, s.rel_dir, s.path.name))
        print("%d scenario(s) selected" % len(scenarios))
        return 0

    cfg = read_simple_config(args.config)
    host = args.host or cfg["host"]
    port = args.port or cfg["port"]
    api_key = args.api_key or cfg["api_key"]
    http_post = make_http_post(host, port, api_key, exec_timeout=args.exec_timeout)

    if args.inject_ctld:
        ctld_path = REPO_ROOT / "CTLD.lua"
        print("Injecting %s ..." % ctld_path)
        _, err = http_post(ctld_path.read_text(encoding="utf-8"))
        if err:
            print("Failed to inject CTLD.lua: %s" % err, file=sys.stderr)
            return 1
        time.sleep(args.init_wait)

    results = []
    for scenario in scenarios:
        result = run_scenario(
            scenario, http_post,
            poll_interval=args.poll_interval, poll_timeout=args.poll_timeout,
        )
        results.append(result)
        status = "PASS" if result.verdict == "PASS" else result.verdict
        print("[%s] %s/%s -- %.1fs -- %s" % (
            status, scenario.rel_dir, scenario.path.name, result.elapsed, result.message))

    build_junit(results).write(args.junit_out, encoding="utf-8", xml_declaration=True)

    passed = sum(1 for r in results if r.verdict == "PASS")
    failed = len(results) - passed
    print("%d passed, %d failed (report: %s)" % (passed, failed, args.junit_out))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
