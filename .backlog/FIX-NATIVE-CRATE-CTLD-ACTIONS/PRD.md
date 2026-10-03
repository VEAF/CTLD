# FIX-NATIVE-CRATE-CTLD-ACTIONS — CTLD's unload, parachute and weight apply to virtual-carry crates only

**Status:** ⬜ ready

Formalizes two `dev/roadmap.md` entries raised by the automated code review of `develop` (issue #236): "Cargo natif
— menus F10 des caisses natives" and "Caisses — `isLoaded()` et `isLoadedByCTLD()` ont des corps identiques".
Decisions come from a `grill-with-docs` session held 2026-10-03, in which the maintainer stated the intended rules
(below) and the code was checked against them.

## The intended rules (maintainer, 2026-10-03)

1. A crate loaded **natively** (DCS cargo UI) can only be unloaded through the DCS cargo UI, without respawn.
2. A natively loaded crate on an aircraft that can parachute (`canParachuteDrop`) can only be parachuted through
   the DCS cargo UI.
3. In every other case (**virtual carry**: loaded through the CTLD F10 menu, or converted to CTLD management)
   CTLD's unload and parachute functions are available.
4. DCS already handles weights and limits for what is loaded through its cargo UI. CTLD adds a weight only for
   what it virtualised through its own menu — this is already how whole vehicles behave.

## Problem Statement

The code does not follow rules 1, 2 and 4 for crates (whole vehicles already follow them: `F-061b`, "dcs_native is
physical").

- **Rule 1.** The F10 "Drop Crate(s)" action collects every crate on board, native ones included. A native crate is
  treated as dropped and a second DCS object is created on the ground while the original stays in the aircraft's
  cargo bay, listed by DCS: a duplicate, and a crate CTLD no longer tracks.
- **Rule 2.** "Parachute Crates" is enabled by native crates and acts on them: it destroys the DCS object of the
  crate that is in the bay and simulates a virtual descent, without freeing the DCS cargo slot. The pilot
  documentation already says native cargo cannot be parachuted from the CTLD menu, and the comment on the crate's
  `loadedByDCSNative` field says it is excluded from parachute.
- **Rule 4.** The transport's internal-cargo weight sent to DCS includes the weight of native crates, although
  DCS accounts for them itself, so a natively loaded crate may be counted twice. (Not yet measured in DCS.)
- **Root cause.** Two predicates, `isLoaded()` and `isLoadedByCTLD()`, have the same body. The docstring of the
  second promises "managed by CTLD" but it is true for native crates too, and the comments at its call sites
  contradict each other and the code.
- **A latent trap.** Loading a crate does not clear `loadedByDCSNative`: only unloading does. A crate released
  from native carry and later loaded through the CTLD menu would keep a stale native flag.

## Solution

`isLoadedByCTLD()` means what its docstring says: loaded **and** in virtual carry (not native). The unload,
parachute (menu entry and action) and weight code use it, so native crates are left to DCS, as the rules state.
Loading a crate clears the native flag. The code that destroyed a native crate's object before a CTLD parachute
descent is removed (it can no longer run). Comments and documentation say the same thing everywhere.

## User Stories

1. As a pilot, I want "Drop Crate(s)" to leave natively loaded crates alone, so that no duplicate crate appears
   on the ground.
2. As a pilot, I want a natively loaded crate to be unloaded only through the DCS cargo UI, so that there is one
   clear way to unload it.
3. As a pilot, I want "Parachute Crates" to be unavailable when only natively loaded crates are on board, so that
   I am not offered an action that cannot work.
4. As a pilot, I want "Parachute Crates" not to touch a natively loaded crate, so that its DCS object is never
   destroyed while in the bay.
5. As a pilot, I want the DCS parachute release of a native crate to keep working as before, so that nothing
   regresses there.
6. As a pilot, I want crates loaded through the CTLD menu to keep being dropped and parachuted by CTLD, so that
   the virtual path is unchanged.
7. As a pilot, I want crates converted to CTLD management (`convertNativeLoadToCTLD`) to behave as virtual, so that
   they remain droppable and parachutable by CTLD.
8. As a pilot, I want a crate that was released natively and later loaded through the menu to behave as virtual,
   so that a stale flag never hides it.
9. As a pilot, I want CTLD not to add the weight of a crate I loaded through the DCS cargo UI, so that the
   aircraft is not heavier than DCS says.
10. As a pilot, I want CTLD to keep adding the weight of crates loaded through its menu, so that virtual loads
    still weigh on the aircraft.
11. As a pilot, I want crates loaded in both ways at once to be weighed correctly, so that mixed loads are right.
12. As a mission maker, I want one consistent rule for crates and whole vehicles, so that native cargo behaves
    the same whatever it is.
13. As a CTLD developer, I want `isLoadedByCTLD()` to mean what its docstring says, so that the call sites are
    self-explanatory.
14. As a CTLD developer, I want the call-site comments to agree with the code, so that nobody reintroduces the
    contradiction.
15. As a CTLD developer, I want the parachute branch that handled native crates removed, so that no dead code
    contradicts the rule.
16. As a CTLD developer, I want busted tests for each action with a native crate and with a virtual crate, so
    that both halves of the rule are covered.
17. As a maintainer, I want the developer and pilot documentation to state the rules, so that behaviour is
    documented once and correctly.
18. As a maintainer, I want the weight claim checked in a live DCS mission, so that the weight change does not
    rest on an assumption.
19. As a maintainer, I want the two roadmap entries removed once the work lands, and a CHANGELOG entry added, so
    that the roadmap lists only open work.

## Implementation Decisions

- **Predicate:** `isLoadedByCTLD()` is true when the crate is `loaded` and its native flag is false. `isLoaded()`
  stays "in a transport, any mode" and is used where every crate on board counts (cargo status, the
  crates-on-board list used for capacity, native release detection).
- **Four call sites follow with no change of their own:** the transport's loaded-crate weight, the parachute
  selection, the "Parachute Crates" menu count, and the "Drop Crate(s)" collection. Menu messages are unchanged
  ("No crates loaded.", "No crates on board to drop.").
- **`load()` clears the native flag.** The native entry path sets the flag after `load()`, so it is unaffected.
- **Dead branch removed:** in the parachute action, the code that destroyed a native crate's DCS object before
  the virtual descent.
- **Weight:** the transport's internal-cargo weight counts virtual-carry crates only, like whole vehicles.
  No other weight source changes.
- **No behaviour change for virtual carry, vehicles, troops, slingload or the native release detection.**
- No config, i18n, schema or catalogue change.
- Comments (the native flag, the weight function, the Drop collection, the parachute menu) and the developer
  crate documentation (EN + FR) are corrected; the pilot parachute page already states the rule and is only
  re-read.

## Testing Decisions

- A good test observes external behaviour: which crates an action collects or acts on, what weight is reported,
  whether a menu entry is enabled. It does not inspect how the predicate is written.
- Seam: a new functional spec on the crate manager. Cases written first and seen failing: a natively loaded
  crate is not collected by the Drop action and is not parachuted (it stays loaded, its DCS object is not
  destroyed); the Parachute Crates entry stays disabled with only native crates on board; the loaded-crate weight
  excludes native crates and includes virtual ones, alone and mixed; a crate released natively then loaded
  through the menu counts as virtual; the predicate's truth table.
- Existing tests (native detection spec, parachute and slingload specs, menu gating specs) pass unchanged.
- **Live DCS, with the maintainer in a native-cargo aircraft:** a diagnostic scenario reads, with one crate
  loaded through the DCS cargo UI, the weight CTLD contributes for it, before the change (expected: counted) and
  after (expected: zero), and the maintainer reads the total weight DCS shows. Recorded in the PR.

## Out of Scope

- Other weight sources (troops, vehicles) and any change to DCS-side limits.
- Letting CTLD free a DCS cargo slot (not possible, per the pilot documentation).
- The unverified native-cargo aircraft types listed in the roadmap.

## Further Notes

Source: `dev/roadmap.md` entries "Cargo natif — menus F10 des caisses natives" and "Caisses — `isLoaded()` et
`isLoadedByCTLD()` ont des corps identiques" (from issue #236's review). No GitHub issue to close.
