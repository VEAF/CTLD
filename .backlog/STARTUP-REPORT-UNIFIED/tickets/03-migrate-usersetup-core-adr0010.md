Status: 🧑 planned
Type: AFK

# 03 — Migrate UserSetup + CoreManager + ADR 0010

## What to build

Replace log-only paths in two modules with `ctld.startupReport.add()`, and document the
two-family convention as ADR 0010.

**`CTLD_userSetup.lua` — `ctld.addCrate()` duplicate-weight path:**
Replace `trigger.action.outText(msg, 30)` with
`ctld.startupReport.add("ERROR", "UserConfig", msg)`. Keep the existing `ctld.logWarning` call
(Family 2).

**`CTLD_userSetup.lua` — `ctld.runUserSetup()` callback failures:**
Replace the log-only `ctld.logWarning(...)` with
`ctld.startupReport.add("ERROR", "UserSetup", ...)` (translated via `ctld.tr()` at call site).
Keep the log call for the dev trace.

**`CTLD_core.lua` — `_initExtractableGroups()` INIT-E:**
Replace `ctld.utils.log("WARN", "... not found, skipped")` with
`ctld.startupReport.add("NOTICE", "CoreManager", ctld.tr(...))`. Add the necessary i18n key.

**ADR 0010 — Two-family separation:**
Create `dev/adr/0010-startup-report-two-family-separation.md` documenting:
- Family 1 (init/config): `ctld.startupReport.add()` exclusively — MM-facing.
- Family 2 (runtime/dev): `ctld.utils.log()` → `CTLD.log` exclusively — dev/debug.
- Convention: no bare `trigger.action.outText()` in `src/` init code.

Extend `tests/ci/unit/usersetup_spec.lua`: duplicate weight path → `ctld.startupReport`
receives ERROR (not `ctld.logWarning` alone).

## Acceptance criteria

- [ ] `ctld.addCrate()` duplicate-weight path feeds `ctld.startupReport`, no bare outText.
- [ ] `ctld.runUserSetup()` callback failure feeds `ctld.startupReport`.
- [ ] `CTLDCoreManager` INIT-E feeds `ctld.startupReport` as NOTICE.
- [ ] New i18n key for INIT-E message present in `CTLD_i18n_en.lua` (empty stub in FR/ES/KO).
- [ ] ADR 0010 created in `dev/adr/`.
- [ ] `usersetup_spec` extended: ERROR in `ctld.startupReport` for dupe-weight path.
- [ ] `busted tests/ci/` clean, luacheck clean, CTLD.lua rebuilt.

## Blocked by

- 01 — Collector + flush() skeleton
