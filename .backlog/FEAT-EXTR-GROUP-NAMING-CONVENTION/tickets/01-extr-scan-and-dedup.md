# 01 — `EXTR_<name>` scan in `_initExtractableGroups`, deduplicated against the explicit list

**Status:** ✅ done

**Blocked by:** none — can start immediately.

## What to build

Extend `CTLDCoreManager:_initExtractableGroups` (`CTLD_core.lua:378`) with a second pass, run
after the existing explicit-list loop (which stays untouched):

- Scan `coalition.getGroups(side)` for `side` in `{RED, BLUE, NEUTRAL}`.
- For each group whose name matches the anchored prefix `^EXTR` (not a free substring — same
  anchoring style as `_isServantUnitName`'s `^SVNT`, not `_isJTACGroup`'s free "jtac" substring),
  resolve its coalition via `group:getCoalition()`.
- Skip a name already present in `tm._droppedGroups[coalition]` (registered by the explicit-list
  pass) — this is the deduplication the PRD requires, not cosmetic: `CTLDTroopManager:
  _findAllNearbyDropped` would otherwise list the same group twice in the "Extract from field" F10
  submenu.
- Otherwise insert the group name into `tm._droppedGroups[coalition]`, exactly the same
  registration the explicit-list path already performs — no new table, no new downstream
  consumer-side change.
- Update the per-group `INFO` log line and the final `INIT-E complete` summary log to distinguish
  how many groups came from the explicit list vs. the `EXTR_` scan (see PRD Implementation
  Decisions).

## Watch out

- `EXTR_<name>` carries **no positional metadata** — unlike `TRZ_`'s 5 fields. Don't parse
  anything after the prefix; the name after `EXTR_` is free-form and used only for
  logging/identification.
- Init-only, by design — do not add any live re-scan or event subscription for a group that
  appears/activates after `_initExtractableGroups` runs. A late-activated `EXTR_`-named group is
  not picked up, matching the explicit list's own already-documented `-- No late-activation
  support (iso-legacy)` limitation. This is deliberate, not a bug to fix here.
- The anchored-prefix test must reject a name that merely *contains* "EXTR" without starting with
  it (e.g. `MyEXTR_Group`) — anchored, not substring, unlike the JTAC check.
- Don't touch `CTLDTroopManager:_findAllNearbyDropped` or any other consumer of `_droppedGroups` —
  they already iterate whatever the table contains; the dedup guarantee belongs entirely here.
- No architectural change to how zones (`TRZ_`/`EXZ_`/etc.) are discovered — this ticket touches
  only group discovery (`coalition.getGroups`), a separate mechanism for a separate DCS object kind.

## Acceptance

- A group named `EXTR_<name>` on RED, BLUE, or NEUTRAL, not otherwise listed in
  `extractableGroups`, is registered into `CTLDTroopManager._droppedGroups[coalition]`.
- A group both listed in `extractableGroups` **and** named `EXTR_<name>` is registered exactly
  once — not twice.
- A group whose name contains "EXTR" but doesn't start with it (`MyEXTR_Group`) is **not**
  registered by the `EXTR_` scan.
- An `EXTR_`-named group that doesn't exist at init is silently skipped (mirrors the explicit
  list's not-found handling — no crash, no false registration).
- The final `INIT-E complete` log line reports the explicit-list count, the `EXTR_`-scan count, and
  the deduplicated total.

## Tests

`tests/ci/unit/core_manager_spec.lua` (new file — no prior art exists: `core_spec.lua` only covers
`CTLDDCSEventBridge`, nothing in `tests/ci/` exercises `CTLDCoreManager:_initExtractableGroups` or
any other `INIT-*` function today). Cover: an `EXTR_`-named group registers; a group listed **and**
`EXTR_`-named registers once; a `NEUTRAL`-coalition `EXTR_`-named group registers (coalition scope
includes civilians); `MyEXTR_Group` (substring, not prefix) does not register; an `EXTR_`-named
group absent at init is silently skipped. These tests are also the first coverage of the
pre-existing explicit-list behavior, exercised as a natural side effect of testing dedup against
it.
