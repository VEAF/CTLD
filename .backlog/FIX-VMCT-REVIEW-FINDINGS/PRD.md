# FIX-VMCT-REVIEW-FINDINGS — five defects found by the VMCT review of `develop` (issues #322 to #326)

**Status:** 🟡 ready — decisions taken by the control session on 2026-11-23 (below, each with its reason). They are defaults, not questions: apply them unless the code proves one wrong, and then say why in the PR.

GitHub issues #322 to #326, opened by VMCT on 2026-11-19 from a read of `develop` at `1dfea2c`. Every finding was re-read in the code on 2026-11-23 and holds; the line numbers of the issues are right. The sibling lot [`FEAT-VMCT-V1-PARITY`](../FEAT-VMCT-V1-PARITY/PRD.md) (#327, #328) runs in parallel.

## Problem Statement

| # | Ticket | What a player or a mission maker meets |
|---|---|---|
| #322 | [01](tickets/01-parachuted-troops-keep-their-template.md) | Every parachuted troop group lands as "Soldier AK": `parachuteTroops` reads `template.units[1].type`, a field that does not exist (templates carry `unitType`, a function of the coalition). Blue infantry with AKs; a Mortar Squad lands as riflemen. |
| #323 | [02](tickets/02-inactive-zones-stay-inactive.md) | `(data.active ~= nil) and data.active or true` never lets `false` through: a `troopZones` / `wpZones` entry marked `"no"` is active from load. Same expression, latent, in `CTLDLogisticZone:init`. |
| #324 | [03](tickets/03-repair-crates-from-the-menu.md) | The six "… Repair" crates have a `weight` and no `unit`; the single-crate menu path looks them up by `unit` (nil) and answers "Request failed". SAM repair by crate is unreachable from the menu. |
| #325 | [04](tickets/04-unique-aa-group-name.md) | AA group name is `<type>_CTLD_AA_<second>`: two systems of the same type spawned in the same second share it, and `coalition.addGroup` replaces the first. |
| #326 | [05](tickets/05-player-name-in-coalition-messages.md) | "%1 started building a FOB" and the three SAM "deployed / rearmed / repaired" messages show the unit name; v1 showed the player name (`ctld.getPlayerNameOrType`). |

Plus [06 live check](tickets/06-live-check.md) and [07 backlog housekeeping](tickets/07-backlog-housekeeping.md).

## Implementation Decisions

- **#322** — Build one unit definition per unit from the template's own units, resolving `unitType` for the group's coalition, the way `CTLDObjectRegistry.spawnObject` does for a landed unload (`src/CTLD_troop.lua:942`). Keep `"Soldier AK"` only as the last fallback when a unit's type cannot be resolved, and log it. Reason: the landed unload is the proven path; the parachute must land the same soldiers.
- **#323** — `self.active = data.active ~= false` in both `CTLDTroopZone:init` and `CTLDLogisticZone:init`. Reason: exact fix; the logistic one is latent but the same bug.
- **#324** — The single-crate menu path passes the entry's `weight` and the request looks it up with `findDescriptorByWeight`, as the `multiple` branch does. Check that no single crate relied on the `unit` lookup in a way the weight lookup would change. No new catalogue field (no `configVersion` bump). Reason: one lookup for every menu crate.
- **#325** — Put the `groupUid` already computed for the unit names into the group name. Reason: the issue's fix, aligned with FIX-PARACHUTE-GROUP-NAME-COLLISION.
- **#326** — Display the player's name, else the unit's **type name**, exactly as v1's `ctld.getPlayerNameOrType` (`migration/source/CTLD.lua:8218`), not the unit name the issue suggests as fallback. Add the helper once in `ctld.utils` (none exists in `src/`), use it in the four messages, and fix the `player` doc line of `unpackFOBCrates` to "unit name". Event payloads unchanged. Reason: legacy parity is the project's reference.
- **No ADR**, no new `CONTEXT.md` term, no new i18n key (the message texts do not change, only their argument).

## Testing Decisions

- TDD per ticket: a failing busted test first, in the existing spec of the module. Each test observes what DCS receives (the group table passed to `coalition.addGroup` / `dynAdd`, the text sent, the zone's `active`) rather than internal calls.
- #322: a template with several roles, both coalitions. #325: two spawns at the same `timer.getAbsTime()`. #326: a unit with a player and an AI unit.
- Coverage ratchet only goes up. `busted tests/ci/`, luacheck, Lua 5.1 lint and the build green.
