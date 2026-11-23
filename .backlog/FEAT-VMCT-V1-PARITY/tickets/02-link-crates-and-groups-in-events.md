# 02 — Events link crates and groups (#328)

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), issue #328.

## What to build
`groupName` on `OnCrateUnpacked` (`src/CTLD_crate.lua` ~2398) when a group was created; `crateNames` on `OnAASystemDeployed` (crate assembly, `src/CTLD_aasystem.lua` ~534), `OnAASystemRearmed` (~612), `OnAASystemRepaired` (~681). `docs/developer/events.md` EN+FR; CHANGELOG *Added*.

## Acceptance criteria
- [ ] Each payload carries the new field with the names of the real group / consumed crates.
- [ ] The AI-delivered `OnAASystemDeployed` (~347) is unchanged.
- [ ] No existing field renamed or removed.
