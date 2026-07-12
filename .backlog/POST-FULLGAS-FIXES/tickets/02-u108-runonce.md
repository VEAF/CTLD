# 02 — U-108 ProbeOffMap + ProbeLifeCheck run-once guard

Status: ◑ partial
Type: AFK

Run-once guard (FullGas option A) applied to both scenarios.
- ProbeLifeCheck: ✅ PASS 4/4 live.
- ProbeOffMap: ❌ still FAIL — option A insufficient: CTLD init pre-creates ghost
  airbases, so the test's name collides on the FIRST run (not just re-runs).
  Flagged to FullGas (dev/fullgas-report.md, Round 2) to choose option B (unique
  idx) or C (verify by name, not count-diff). Left as-is pending his decision.
