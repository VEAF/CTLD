# FIX-LGZ-POLL-FIRST-OBSERVATION

**Status:** merged (PR #252). Compacted from `FIX-LGZ-POLL-FIRST-OBSERVATION/` on 2026-10-09; the ticket files live on in git history.

The logistics poller no longer rebuilds a just-built Request Equipment menu on its first pass (a 4 s ambient blank that lost the first click).

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-record-zone-key-at-section-build` | ✅ done (PR #252) - live check by the maintainer pending | 01 — Record the zone key when the Request Equipment section is built |

## PRD

## FIX-LGZ-POLL-FIRST-OBSERVATION — the logistics poller must not rebuild a menu that already shows the right zones

**Status:** ✅ done (PR #252) - live check by the maintainer pending

Raised during the live checks of 2026-10-03 (UH-1H): the first F10 click after loading the mission, or after entering an aircraft, was often
lost. Analysed with the maintainer against ADR 0015 (safe-by-default ambient refresh); scope limited to the logistics-zone poller.

### Problem Statement

The ground poller of the crate manager (every 10 s) rebuilds a player's *Request Equipment* section when the key of the logistics zones at
the aircraft's position differs from the last one it recorded. That record (`_lgzKey`) is `nil` when the player enters the aircraft and only
the poller writes it. On its first pass, `nil` is different from "no zone" (empty key), so the poller reports a change that did not happen
and rebuilds the menu. A poller rebuild is ambient (ADR 0015): the CTLD menu is wiped and comes back 4 s later, and a click in that window
does nothing. So every player loses the menu for 4 s, 0 to 10 s after entering the aircraft, without any zone having changed.

### Solution

The key of the zones a player's *Request Equipment* section was last built for is recorded when the section is built. The poller compares
the position's zones with that record: a real entry into or exit from a logistics zone still rebuilds (ambient, unchanged); the first pass
no longer does.

### User Stories

1. As a pilot, I want my first F10 click after entering the aircraft to work, so that I do not have to click twice.
2. As a pilot, I want the menu to be rebuilt in the background only when a logistics zone is really entered or left.
3. As a pilot, I want entering or leaving a logistics zone to still update *Request Equipment*.
4. As a CTLD developer, I want the ambient delay of ADR 0015 untouched, so that the wrong-command protection stays.
5. As a CTLD developer, I want the recorded key to describe what the player's menu shows, not what the poller last saw.

### Implementation Decisions

- The zone-key function moves out of the poller closure to the crate module so the section build and the poller share it.
- `refreshRequestEquipmentSection` records the key (`_lgzKey`) when it builds the section on the ground. The poller keeps recording it on a
  change, so a player whose section is not built (no menu) behaves as before.
- No change to the menu manager, to ADR 0015, to the 4 s delay, or to the other ambient triggers (crate spawned / cleared fan-out).

### Testing Decisions

- A good test observes whether a rebuild happens, not how it is organised.
- Existing poller spec (`crate_lgzpoll_spec`) kept; new cases: the section build records the key (no zone, one zone), the first poll pass
  after the build does not rebuild, a zone entry after the build still does.
- Live: 0.1 s probe on the menu rebuilds (`refreshMenuForGroup` / wipe) after entering an aircraft outside any zone: none expected.

### Out of Scope

- The `OnCrateSpawned` / `OnCrateCleared` fan-out, left ambient by ADR 0015.
- Any change to ADR 0015's delay or detection mechanism.

### Further Notes

The cause is a hypothesis from reading the code; the live check confirms it on the maintainer's mission.
