# INTEGRATION-TEST-TAGS

**Status:** `-- @tier: auto\. Compacted from `INTEGRATION-TEST-TAGS/` on 2026-08-01; the ticket files live on in git history.

auto-check\

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-fix-f122-unresolved-verdict` | ✅ done | 01 — Fix F-122's unresolved verdict (incidental) |
| `02-tag-scenarios` | ✅ done | 02 — Tag the 79 scenarios + 4 templates with `-- @tier:` |
| `03-document-taxonomy` | ✅ done | 03 — Document the `@tier` taxonomy |

## PRD

## Lot INTEGRATION-TEST-TAGS — tier tagging for tests/dcs/ scenarios

Status: ✅ done (pending commit/PR)
Branch: feature/integration-test-tags → PR (pending) → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`); second lot of the
DCS-bridge triptych (after `DCS-BRIDGE-MCP`, before `INTEGRATION-TEST-RUNNER`).

### Problem Statement

The 79 scenarios migrated to the dcs-bridge return contract in `DCS-BRIDGE-MCP` have no
machine-readable automation-level marker. `INTEGRATION-TEST-RUNNER` needs a way to select
"run without AI" scenarios (fully automatable, no human/AI judgment required) versus scenarios
that need an AI agent or human in the loop — without re-deriving that classification by hand
every time.

### Solution

Add a `-- @tier: auto | auto-check | ia` header line to every one of the 79 scenarios and the
four `_template_*.lua` templates.

#### Taxonomy (grounded in the actual return-contract behaviour, not folder location alone)

- **`auto`** — a single `exec_lua` call returns the definitive `PASS`/`FAIL`/`ABORT` verdict.
  No player unit, no polling, no human/AI judgment.
- **`auto-check`** — resolves automatically (no human/AI judgment) but not in one call: the
  scenario returns `STARTED` and a real, unmocked timer/`waitFor` resolves
  `_SCN_<ID>_RESULT` to the final verdict later. The runner must poll or re-inject.
  *(Refines the program's original "verdict via log/get_units" phrasing — moot now that every
  scenario self-reports its verdict via the return contract; the operative distinction is
  single-call vs. requires-polling.)*
- **`ia`** — requires an AI agent or human in the loop: either a live player-controlled unit
  (dcs-bridge exposes no flight-control API — someone/something has to fly the aircraft into
  position) or an explicit visual/F10 confirmation the code never resolves programmatically.

#### Classification (79 scenarios + 4 templates)

| Tier | Count | Scope |
|---|---|---|
| `auto` | 43 | `noPlayer/` scenarios resolving PASS/FAIL/ABORT in a single `exec_lua` call (includes scenarios using a *mocked* timer that fires synchronously, e.g. `scenario_b4_maximum_distances.lua`) |
| `auto-check` | 2 | `noPlayer/scenario_ai_transport.lua`, `noPlayer/scenario_scheduler.lua` — genuine async resolution via real timers, no human involved, but requires polling `_SCN_<ID>_RESULT` |
| `ia` | 34 | All 3 `pilotActive/` + all 29 `pilotPassive/` (player-in-cockpit required) + 2 `noPlayer/` outliers (`F-046`, `F-047`) that return `STARTED` and never resolve programmatically — they explicitly ask for human visual confirmation of an F10 menu and leave the verdict there |

Template tiers: `_template_noPlayer.lua` → `auto`, `_template_pilotPassive.lua` /
`_template_pilotActive.lua` → `ia`, `_template_scenario.lua` (generic, covers all step types)
→ documented as adaptable, tagged `auto` with a note to change per scenario shape.

### Incidental fix (found during classification audit)

`tests/dcs/noPlayer/F-122_gap1JTACLifecycleOnLoadVehicleUnloadVehicleMenuCtl.lua` never resolved
its verdict — a leftover gap from a `DCS-BRIDGE-MCP` migration agent that was cut off mid-file
(session limit). Fixed in this lot (adds the missing final `PASS`/`FAIL` resolution + `return`,
same pattern as sibling files). Not a tagging change; called out separately in the ticket.

### Non-goals

- The Python runner and its `--tier` filtering — `INTEGRATION-TEST-RUNNER`.
- Tagging or fixing the ~194 dead FullGas relics — `CLEANUP-LEGACY-DCS-TESTS`.
- Any change to scenario test logic beyond the header line and the F-122 incidental fix.
