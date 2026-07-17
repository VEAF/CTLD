# 04 — requiresCtld version-check convention

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

A convention for a plugin scene to declare a minimum CTLD version and get a clear WARN when loaded
against an incompatible CTLD (ADR 0006). The decoupled `CTLD_plugins` repo can drift from the CTLD
API (e.g. a plugin assuming the `deferMenuSection` timing fix, loaded against an old CTLD that lacks
it → silent menu loss). The version check surfaces that.

At scene registration, if `model.requiresCtld` is set, compare it against `ctld.VERSION`; if CTLD is
below the required version, emit a **WARN** (not a hard-fail — the scene still registers). Provide a
small semver-ish comparison helper (Lua 5.1). `requiresCtld` also becomes catalogue metadata.

## Acceptance criteria

- [ ] `registerSceneModel` (or a helper it calls) honours `model.requiresCtld`.
- [ ] CTLD below required → WARN with a clear message (scene name, required vs actual); scene still
      registers.
- [ ] CTLD at/above required → silent.
- [ ] Version comparison helper handles the project's version format (incl. `-rc` suffixes);
      busted-tested.
- [ ] Lua 5.1 compliant; luacheck clean.

## Blocked by

None.
