#!/usr/bin/env python3
"""Interactive runner for a single `ia`-tier scenario (pilotActive/pilotPassive).

Most `ia`-tier scenarios don't actually need an AI/human to *judge* anything -- they
self-verify via the same checkMenuExpected()-style logic as auto-tier scenarios. The only
reason they're `ia` is that dcs-bridge has no flight-control API: someone has to fly. This
script removes the Claude middleman for that case: it injects the scenario, mirrors its
in-game instruction text to the terminal (no need to alt-tab), and polls `_SCN_<ID>_RESULT`
until PASS/FAIL/ABORT -- same REST calls tools/integration-runner/run_scenarios.py already
uses for `auto`/`auto-check` scenarios, just without the `--no-ai` tier filter.

Handles both async patterns: `STARTED` scenarios resolve on their own (this just polls the
result var); `RUNNING: step=N ...` scenarios need the full source re-posted to advance their
internal step machine between a physical DCS-side action and the next step (see
tools/integration-runner/README.md) -- this script re-injects automatically on that token
instead of failing the way the headless `run_scenarios.py --no-ai` has to.

Restart after a crash: just re-run the same command. Every run first calls the scenario's
`_SCN_<ID>_CLEANUP` global (if the scenario exposes one -- both `_template_pilotActive.lua`
and `_template_pilotPassive.lua` do) to cancel any stuck timer and reset its running-guard
before re-injecting, so there's no "already active, restart DCS" dead end.

Scenarios that need genuine visual/subjective judgment (e.g. F-046 "menu looks identical")
still prompt a human -- but the prompt is a plain y/n in this terminal, not a trip through
the DCS F10 menu tree.

Usage (from repo root):
    python tools/integration-runner/run_ia_scenario.py --scenario scenario_troop_menu_sol_vol_visual
    python tools/integration-runner/run_ia_scenario.py --scenario crate_menu_sol_vol_visual
"""
from __future__ import annotations

import argparse
import re
import sys
import time
from pathlib import Path

import run_scenarios as rs

REPO_ROOT = rs.REPO_ROOT
IA_DIRS = ("pilotActive", "pilotPassive")

INSTR_VAR_RE = re.compile(r"_SCN_[A-Za-z0-9]+_INSTR")
CLEANUP_VAR_RE = re.compile(r"_SCN_[A-Za-z0-9]+_CLEANUP")


def derive_instr_var(source: str) -> str | None:
    """Find the `_SCN_<ID>_INSTR` global a scenario mirrors its instructions into, if any."""
    match = INSTR_VAR_RE.search(source)
    return match.group(0) if match else None


def derive_cleanup_var(source: str) -> str | None:
    """Find the `_SCN_<ID>_CLEANUP` global a scenario exposes for external reset, if any."""
    match = CLEANUP_VAR_RE.search(source)
    return match.group(0) if match else None


def reset_stuck_state(http_post, cleanup_var: str | None) -> None:
    """Call the scenario's own cleanup function if a previous run left it stuck running."""
    if not cleanup_var:
        return
    _, err = http_post("if %s then %s() end return 'reset'" % (cleanup_var, cleanup_var))
    if err:
        print("  (reset skipped: %s)" % err, file=sys.stderr)


def run_interactive(scenario: rs.ScenarioInfo, http_post, poll_interval: float = 2.0,
                     sleep=time.sleep) -> int:
    """Inject `scenario`, mirror instructions to the terminal, poll to a terminal verdict."""
    source = scenario.path.read_text(encoding="utf-8")
    cleanup_var = derive_cleanup_var(source)
    instr_var = derive_instr_var(source)
    result_var = rs.derive_result_var(source)

    print("Resetting any stuck state from a previous run...")
    reset_stuck_state(http_post, cleanup_var)

    print("Injecting %s ..." % scenario.path.name)
    raw, err = http_post(source)
    if err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 1
    token, message = rs.parse_verdict(raw)
    print("[%s] %s" % (token, message))
    if token in rs.TERMINAL_VERDICTS:
        return 0 if token == "PASS" else 1
    if token not in ("STARTED", "RUNNING"):
        print("Unexpected verdict, stopping.", file=sys.stderr)
        return 1
    if not result_var:
        print("No _SCN_<ID>_RESULT variable found -- can't poll.", file=sys.stderr)
        return 1

    last_instr = None
    last_message = message
    print("Polling every %.0fs -- fly/answer F10 prompts in DCS as instructed below." % poll_interval)
    print("Ctrl+C to stop. Re-run this same command any time to reset and restart the test.\n")
    try:
        while True:
            sleep(poll_interval)
            if instr_var:
                raw_instr, err_instr = http_post("return %s" % instr_var)
                if not err_instr and raw_instr and raw_instr != last_instr:
                    last_instr = raw_instr
                    print("-" * 60)
                    print(raw_instr)
                    print("-" * 60 + "\n")
            # RUNNING-pattern scenarios (see integration-runner/README.md) need the full
            # source re-posted to advance their internal step machine -- polling the result
            # var alone would just see the same "RUNNING: step=N" forever. STARTED-pattern
            # scenarios resolve on their own; re-posting them is a safe no-op (they guard
            # against double injection and just echo the current result back).
            if token == "RUNNING":
                raw, err = http_post(source)
            else:
                raw, err = http_post("return %s" % result_var)
            if err:
                print("ERROR: %s" % err, file=sys.stderr)
                return 1
            token, message = rs.parse_verdict(raw)
            # Print on ANY progress, not just a token change -- multi-step scenarios (e.g. the
            # RUNNING: step=N pattern) update the message every step while the token itself
            # stays "RUNNING" the whole time; without this, a long-running step (a real timer
            # the scenario itself is waiting out) looks like nothing is happening.
            if message != last_message:
                print("[%s] %s" % (token, message))
                last_message = message
            if token in rs.TERMINAL_VERDICTS:
                return 0 if token == "PASS" else 1
            # still STARTED/RUNNING -- keep polling/re-injecting
    except KeyboardInterrupt:
        print("\nStopped. Re-run this same command to reset and restart the test.")
        return 130


def build_arg_parser():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--config", type=Path, default=REPO_ROOT / "dcs-client.yaml",
                    help="Path to dcs-client.yaml (default: repo root)")
    p.add_argument("--host", help="Override dcs-serve host")
    p.add_argument("--port", type=int, help="Override dcs-serve port")
    p.add_argument("--api-key", help="Override dcs-serve API key")
    p.add_argument("--scenario", required=True,
                    help="Filename substring, e.g. troop_menu_sol_vol_visual")
    p.add_argument("--poll-interval", type=float, default=2.0,
                    help="Seconds between polls (default: 2)")
    return p


def main(argv=None) -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    args = build_arg_parser().parse_args(argv)

    scenarios = rs.discover_scenarios(dirs=IA_DIRS)
    matches = rs.filter_scenarios(scenarios, scenario_glob=args.scenario)
    if not matches:
        print("No scenario in pilotActive/pilotPassive matches %r" % args.scenario, file=sys.stderr)
        return 1
    if len(matches) > 1:
        print("Ambiguous -- matches: %s" % ", ".join(m.path.name for m in matches), file=sys.stderr)
        return 1
    scenario = matches[0]

    cfg = rs.read_simple_config(args.config)
    host = args.host or cfg["host"]
    port = args.port or cfg["port"]
    api_key = args.api_key or cfg["api_key"]
    http_post = rs.make_http_post(host, port, api_key)

    return run_interactive(scenario, http_post, poll_interval=args.poll_interval)


if __name__ == "__main__":
    sys.exit(main())
