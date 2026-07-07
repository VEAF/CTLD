# Lot DCS-DATAMINE-VENDOR — offline config type linter

Status: ✅ done
Branch: feature/dcs-datamine-vendor → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`)

## Problem Statement

A typo in a DCS type name in mission-maker config (`spawnableCrates`, AA templates,
`loadableGroups`, static registry) is only caught at runtime by `CTLD_modValidator` (which spawns
probe objects at mission start). There is no cheap dev/CI check to surface such typos before a
mission is ever launched.

## Solution

Vendor the set of known stock DCS type names (from Quaggles/dcs-lua-datamine, pinned) into the repo
— **not** into the shipped `CTLD.lua` — and add an offline busted linter that cross-checks the
configured type names against that set, reporting any that are unknown.

Decision (see investigation): NOT shipped in the deliverable. `CTLD_modValidator` runtime probing
is unchanged — it remains the mission-time safety net and already covers mod types (which the stock
set cannot know). The datamine set adds value only offline.

## Scope

- `tools/dcs-data/gen_dcs_types.py` — extractor (sparse+partial clone at `DATAMINE_REF`, collect
  `_G/db/Units/**` basenames, emit a Lua set). Manual/maintenance tool; CI does not run it (network).
- `tests/data/dcs_types.lua` — the generated set (1143 types @ ref dc7d15e8). Not in `listToMerge`.
- `tests/ci/unit/config_types_lint_spec.lua` — busted linter: collects configured type names and
  reports those not in the stock set.
- `tools/dcs-data/README.md`.

## Testing Decisions

- The linter itself is a busted spec. It asserts the machinery (the vendored set loads and is
  substantial; the collector finds configured types) and **reports** unknowns without failing —
  unknowns may be legitimate mod types, so failing on them would be wrong.

## Out of Scope

- Shipping the type set into `CTLD.lua` (rejected: ~13k-line bloat for marginal runtime value).
- Changing `CTLD_modValidator` runtime behavior.
- Full unit attribute data (only type-name strings are needed here).

## Further Notes

Follow-up (optional): turn the linter into a hard gate by adding an allow-list of intentional
non-stock types (mods, scene sentinels), so a genuinely unknown type fails CI while known mods pass.
Deferred until the current config's non-stock types are characterized.
