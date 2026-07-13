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


def _fmt_elapsed(seconds: float) -> str:
    """Compact mm:ss (or h:mm:ss past an hour) elapsed-time stamp for log lines."""
    total = int(seconds)
    h, rem = divmod(total, 3600)
    m, s = divmod(rem, 60)
    if h:
        return "%d:%02d:%02d" % (h, m, s)
    return "%d:%02d" % (m, s)


def run_interactive(scenario: rs.ScenarioInfo, http_post, poll_interval: float = 2.0,
                     heartbeat_interval: float = 30.0, max_errors: int = 5,
                     sleep=time.sleep, now=time.monotonic, reset_source=None) -> int:
    """Inject `scenario`, mirror instructions to the terminal, poll to a terminal verdict.

    Long scenarios (e.g. the JTAC drone's ~13 min of internal timers) can go minutes between
    verdict-message changes; without feedback the terminal looks hung. Two things keep the user
    informed: every printed line carries an elapsed [mm:ss] stamp, and a heartbeat line prints
    every `heartbeat_interval` seconds even when nothing changed, echoing the last known state.

    A transient poll error (HTTP 504 while DCS's Lua thread is briefly busy, a dropped
    connection) is tolerated: up to `max_errors` consecutive failures are retried rather than
    aborting the whole run, since these tend to hit exactly during a long scenario. Only a
    sustained run of errors (dcs-serve down, mission unloaded) gives up.
    """
    source = scenario.path.read_text(encoding="utf-8")
    cleanup_var = derive_cleanup_var(source)
    instr_var = derive_instr_var(source)
    result_var = rs.derive_result_var(source)

    start = now()

    def stamp():
        return "[%s]" % _fmt_elapsed(now() - start)

    print("Resetting any stuck state from a previous run...")
    reset_stuck_state(http_post, cleanup_var)
    # Also clear cross-scenario player/menu contamination (phantom players, wiped menus) left by
    # any prior scenario -- same snippet the headless sweep uses. Best-effort: errors logged, not
    # fatal. (reset_source is read + passed by main(); None in unit tests.)
    if reset_source:
        _, rerr = http_post(reset_source)
        if rerr:
            print("  (state reset skipped: %s)" % rerr, file=sys.stderr)

    print("Injecting %s ..." % scenario.path.name)
    raw, err = http_post(source)
    if err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 1
    token, message = rs.parse_verdict(raw)
    print("%s [%s] %s" % (stamp(), token, message))
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
    last_output = now()   # last time anything was printed, for the heartbeat
    # The heartbeat echoes the most recent *meaningful* line. For STARTED-pattern scenarios the
    # RESULT message never changes ("STARTED" the whole run) -- the real progress arrives via the
    # instruction mirror (each VERIFY publishes into _SCN_<ID>_INSTR). So track the last thing
    # actually printed, preferring the latest instruction line over the static RESULT message.
    last_progress = "[%s] %s" % (token, message)
    consecutive_errors = 0
    print("Polling every %.0fs (heartbeat every %.0fs) -- fly/answer F10 prompts in DCS as "
          "instructed below." % (poll_interval, heartbeat_interval))
    print("Ctrl+C to stop. Re-run this same command any time to reset and restart the test.\n")
    try:
        while True:
            sleep(poll_interval)
            if instr_var:
                raw_instr, err_instr = http_post("return %s" % instr_var)
                if not err_instr and raw_instr and raw_instr != last_instr:
                    last_instr = raw_instr
                    print("%s in-mission instructions:" % stamp())
                    print("-" * 60)
                    print(raw_instr)
                    print("-" * 60 + "\n")
                    last_output = now()
                    # Collapse to the last non-empty line for a compact heartbeat echo.
                    lines = [ln.strip() for ln in raw_instr.splitlines() if ln.strip()]
                    if lines:
                        last_progress = lines[-1]
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
                # A transient blip (HTTP 504 while DCS's Lua thread is briefly busy, a dropped
                # connection) must not kill a 13-min run near the end. Tolerate a bounded run
                # of consecutive errors -- keep polling, warn, and only give up if they persist
                # (dcs-serve down, mission unloaded). A single good poll resets the counter.
                consecutive_errors += 1
                if consecutive_errors > max_errors:
                    print("ERROR: %s (%d consecutive -- giving up)" % (err, consecutive_errors),
                          file=sys.stderr)
                    return 1
                print("%s transient poll error (%d/%d): %s -- retrying" % (
                    stamp(), consecutive_errors, max_errors, err), file=sys.stderr)
                last_output = now()
                continue
            consecutive_errors = 0
            token, message = rs.parse_verdict(raw)
            # Print on ANY progress, not just a token change -- multi-step scenarios (e.g. the
            # RUNNING: step=N pattern) update the message every step while the token itself
            # stays "RUNNING" the whole time; without this, a long-running step (a real timer
            # the scenario itself is waiting out) looks like nothing is happening.
            if message != last_message:
                print("%s [%s] %s" % (stamp(), token, message))
                last_message = message
                last_output = now()
                last_progress = "[%s] %s" % (token, message)
            if token in rs.TERMINAL_VERDICTS:
                return 0 if token == "PASS" else 1
            # Heartbeat: nothing changed for heartbeat_interval -- prove we're alive and show
            # the elapsed clock so a slow-but-healthy step is distinguishable from a hang.
            if now() - last_output >= heartbeat_interval:
                print("%s still running -- last: %s" % (stamp(), last_progress))
                last_output = now()
            # still STARTED/RUNNING -- keep polling/re-injecting
    except KeyboardInterrupt:
        print("\n%s Stopped. Re-run this same command to reset and restart the test." % stamp())
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
    p.add_argument("--heartbeat", type=float, default=30.0,
                    help="Seconds between 'still running' heartbeat lines when nothing changes "
                         "(default: 30)")
    p.add_argument("--max-errors", type=int, default=5,
                    help="Consecutive transient poll errors (e.g. HTTP 504) tolerated before "
                         "giving up (default: 5)")
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

    reset_path = REPO_ROOT / "tests" / "dcs" / "_reset_state.lua"
    reset_source = reset_path.read_text(encoding="utf-8") if reset_path.exists() else None

    return run_interactive(scenario, http_post, poll_interval=args.poll_interval,
                           heartbeat_interval=args.heartbeat, max_errors=args.max_errors,
                           reset_source=reset_source)


if __name__ == "__main__":
    sys.exit(main())
