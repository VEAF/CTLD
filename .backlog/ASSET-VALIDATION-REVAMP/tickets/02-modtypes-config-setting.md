# 02 — modTypes config setting (mission-maker mod whitelist)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

A config setting through which a mission-maker declares the **extra (non-stock) DCS type names** their
own crate/troop/AA config uses (mod types), so the companion validator (ticket 03) treats them as
known instead of WARNing. Consistent with the `modTypes` concept on scene models (SCENE-PLUGINS
ticket 02) — same idea, config level.

- New setting `modTypes` (list of type-name strings), accessed via `ctld.gs("modTypes")`, declared
  like other settings (`_cfg.settings["modTypes"] = { ... }`).
- Empty/absent by default.

## Acceptance criteria

- [ ] `ctld.gs("modTypes")` returns the configured list (or empty).
- [ ] Documented in the mission-maker config reference (EN/FR) with an example.
- [ ] The shared collector (ticket 01) folds it into the declared-extras union.
- [ ] Lua 5.1; luacheck clean.

## Blocked by

None.
