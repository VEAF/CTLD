# 02 — Tag the 79 scenarios + 4 templates with `-- @tier:`

Status: ✅ done
Type: AFK

## What to build

Add a `-- @tier: auto | auto-check | ia` header line to every scenario in
`tests/dcs/{noPlayer,pilotActive,pilotPassive}/` (79 files) and the four
`_template_*.lua` templates, per the classification frozen in the PRD:

- `auto` (43): all `noPlayer/` scenarios except the 2 listed below.
- `auto-check` (2): `noPlayer/scenario_ai_transport.lua`, `noPlayer/scenario_scheduler.lua`.
- `ia` (34): all `pilotActive/` (3) + all `pilotPassive/` (29) + `noPlayer/F-046...` and
  `noPlayer/F-047...` (2).
- Templates: `_template_noPlayer.lua` → `auto`; `_template_pilotPassive.lua` and
  `_template_pilotActive.lua` → `ia`; `_template_scenario.lua` → `auto` with a comment noting
  it must be re-tagged per the concrete scenario's shape (it demonstrates all four step types).

Placement: header comment block, near the top (alongside `@scenario`/`@coverage` where those
exist), one line: `-- @tier: <value>`. For the 2 `ia`-tagged `noPlayer` outliers (F-046, F-047),
add a one-line rationale comment since the tier isn't inferable from the folder
(`-- @tier: ia  (never resolves programmatically — requires F10 visual confirmation)`).

## Acceptance criteria

- [ ] All 79 scenarios + 4 templates carry exactly one `-- @tier:` line with a valid value.
- [ ] Counts match: 43 `auto` / 2 `auto-check` / 34 `ia` (scenarios) + 4 templates tagged per
      the PRD table.
- [ ] `luac5.1 -p` clean on every touched file (comment-only change, should be trivially safe).
- [ ] `grep -rc '@tier:' tests/dcs/{noPlayer,pilotActive,pilotPassive}/*.lua` returns exactly 1
      per file, no duplicates.

## Blocked by

Ticket 01 (fix F-122 first so its header edit lands on the corrected file).
