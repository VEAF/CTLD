Status: ready

# PRD — CTLD-TOOLS-MIZ-INJECT

> Roadmap item delivered: automatic `.miz` injection for `ctld-tools` (see ADR 0009).

## Problem Statement

After `gen-user`, the Mission Maker still has to open the Mission Editor and paste the generated
`CTLD_userConfig.lua` into a MISSION START trigger, before the CTLD trigger. A small manual step, but
error-prone (ordering, forgetting it).

## Solution

`ctld-tools inject --miz <mission> --userconfig <CTLD_userConfig.lua> [--out <copy>]` inserts the
generated Lua as an **inline MISSION START trigger at rank 1** (so it runs before the CTLD trigger),
**idempotently** (re-injection updates the same trigger, matched by a comment marker). The final
validation — DCS loads the mission and runs the trigger — remains a manual test in DCS.

## Implementation Decisions

- **Vendored `luadata`** (from VMCT, `ctld_tools/vendor/`) parses/serializes the Lua `mission` table
  with `keep_as_dict=["trig","trigrules"]` so trigger indices survive as dict keys. Excluded from
  ruff/mypy/coverage. `veaf_libs` dependency stripped.
- **`miz.py`**: `read_mission` / `write_miz` (zip round-trip, temp-then-replace so `--miz == --out`
  is safe), and `inject_userconfig`. DCS triggers are parallel per-category tables (`actions`,
  `conditions`, `funcStartup`, `flag`, …) indexed by the same key, mirrored in `trigrules`.
- **Insertion at rank 1 with shift** (recreated from VMCT's mission builder): existing triggers are
  renumbered up and their in-code `[idx]` self-references rewritten via regex; the new trigger takes
  key 1 (`funcStartup`, `a_do_script` inline, condition `return(true)`), trigrules gets a matching
  `triggerStart` entry with the marker comment.
- Inline (`a_do_script`), per the maintainer's choice — the generated Lua is embedded directly, no
  resource/mapResource management.

## Testing Decisions

- `test_miz.py`: rank-1 MISSION START trigger present + marked; existing triggers shifted with their
  `[idx]` references consistent; the regenerated `mission` is **valid Lua** (executed via lupa);
  re-injection stays single (idempotent).
- Prior art: the VMCT mission-builder tests. Fixture: the repo's martyr `missions/Test_CTLDNEXT_01.miz`.

## Out of Scope

- `a_do_script_file` (embedded resource) variant; TUI (roadmap).
- Verifying in-DCS execution/ordering — a manual DCS load (documented as required).

## Further Notes

- Only remaining ctld-tools roadmap item: the interactive TUI.
