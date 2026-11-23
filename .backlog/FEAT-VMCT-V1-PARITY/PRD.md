# FEAT-VMCT-V1-PARITY — v1 behaviours VMCT needs back: drivable spawned units, crate ↔ group link in events (issues #327, #328)

**Status:** ✅ done (PR #329, live check 15/15 on 2026-11-23) — decisions taken by the control session on 2026-11-23 (below, each with its reason). They are defaults, not questions: apply them unless the code proves one wrong, and then say why in the PR.

GitHub issues #327 and #328, opened by VMCT on 2026-11-19 from a read of `develop` at `1dfea2c`, re-read in the code on 2026-11-23. VMCT works around both today (a wrapper on `ctld.utils.spawnAs`, a proximity heuristic) and will drop the workarounds once this ships. The sibling lot [`FIX-VMCT-REVIEW-FINDINGS`](../FIX-VMCT-REVIEW-FINDINGS/PRD.md) (#322-#326) runs in parallel and also touches `src/CTLD_aasystem.lua` and `src/CTLD_crate.lua` (other functions), `CHANGELOG.md` and `.backlog/README.md`: rebase on `develop` if it merges first.

## Problem Statement

| # | Ticket | What a player or a layer meets |
|---|---|---|
| #327 | [01](tickets/01-spawned-units-player-can-drive.md) | v1 created gesture-spawned units with `playerCanDrive = true` (`migration/source/CTLD.lua:4685`, `:3692`); CTLD 2 hard-codes `false` (`src/core/CTLD_objectRegistry.lua:445`, `src/CTLD_aasystem.lua:863`, `src/CTLD_vehicle.lua:277`, `:575`; the unpacked crate does not set it). Combined Arms players and game masters cannot drive what was delivered, and no setting brings it back. |
| #328 | [02](tickets/02-link-crates-and-groups-in-events.md) | `OnCrateUnpacked` gives the crate without the group; `OnAASystemDeployed/Rearmed/Repaired` give the group without the crates. v1 callbacks gave both; a layer rebuilds the link by proximity and can cross two simultaneous unpacks. |

Plus [03 live check](tickets/03-live-check.md).

## Implementation Decisions

- **#327** — New setting `spawnedUnitsPlayerCanDrive`, **default `true`** (v1 behaviour), read at every gesture spawn site: `spawnObject`, the AA system, the transported vehicle (two sites), the unpacked crate. The beacon stays `true`. The hard-coded `false` of the registry templates (`src/core/CTLD_objectRegistry.lua:203-278`): read them and decide whether they are template intentions or copies of the default, and say which in the PR; a template that explicitly wants `false` keeps priority over the setting. Catalogue: `configVersion` 2.4.0 → 2.5.0 with `tests/ci/data/catalogue_shapes/2.5.0.json` (`ctld-tools shape`, see `CLAUDE.md`), ctld-tools schema label EN+FR, mission maker settings table EN+FR. CHANGELOG under **Changed**: it moves the 2.0.0 default back to v1's. Reason: legacy parity is the project's reference; VMCT asked for the setting and left the default to us.
- **#328** — Add `groupName` to `OnCrateUnpacked` (only when the unpack created a group), and `crateNames` (a list: an assembly consumes several crates, a rearm or a repair one or more) to `OnAASystemDeployed` (crate assembly only; the AI delivery has no crate and gives no field), `OnAASystemRearmed` and `OnAASystemRepaired`. Additive only, no field renamed. Update `docs/developer/events.md` EN+FR. Reason: a list is the only shape true on every path; additive keeps every listener working.
- **No ADR**, no new `CONTEXT.md` term.

## Testing Decisions

- TDD per ticket, in the existing spec of each module, observing what DCS receives (the group table's `playerCanDrive`) and the published payloads.
- #327: setting `true`, `false`, and absent from a 2.4.0 configuration (the catalogue fills the default). The catalogue-shape CI test must pass.
- Coverage ratchet only goes up. `busted tests/ci/`, luacheck, Lua 5.1 lint, the build green.
