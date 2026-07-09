# 01 — Fix F-122's unresolved verdict (incidental)

Status: ✅ done
Type: fix

## What to build

`tests/dcs/noPlayer/F-122_gap1JTACLifecycleOnLoadVehicleUnloadVehicleMenuCtl.lua` set
`_SCN_F122_RESULT = "[F-122] STARTED"` but never resolved it — no final `return`, verdict stuck
at `STARTED` forever. Leftover from a `DCS-BRIDGE-MCP` migration agent cut off mid-file by a
session limit. Add the missing final block (same pattern as sibling `assert_eq`-style
scenarios): compute `PASS <p>/<t>` or `FAIL <f>/<t>: <reasons>` from the existing `pass`/`fail`
counters and `return` it.

## Acceptance criteria

- [x] File ends with a `return` statement carrying a resolved `PASS`/`FAIL` verdict.
- [x] `luac5.1 -p` clean.
- [x] No other file among the 79 has the same defect (audited: every file's last non-empty line
      is a `return` statement).

## Blocked by

None.
