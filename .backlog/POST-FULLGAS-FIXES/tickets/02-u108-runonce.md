# 02 — U-108 ProbeOffMap + ProbeLifeCheck

Status: ✅ done
Type: AFK

- ProbeLifeCheck: run-once guard (FullGas option A). PASS 4/4 live.
- ProbeOffMap: run-once guard + C3 rewritten as option C — verify the valid
  probe's own ghost (CTLD_MVP_H<idx>) exists by name instead of a before/after
  count-diff (which collided with the ghosts CTLD init pre-creates). PASS 4/4 live.
  Resolved ourselves (David's call), no FullGas decision needed.
