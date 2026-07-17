# 03 — Remove the scene runtime audit (_auditAfterModValidator)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Remove `CTLDSceneManager:_auditAfterModValidator()` and its call site in `CTLD_core.lua`, together
with the `requiresMod` runtime WARN `outText` — it is the "error at every mission start" the lot
exists to kill (ADR 0007). Scene asset validation is now design-time (ticket 02).

Sweep the now-dead scene-audit machinery:

- `model._disabled` is no longer set → the `_disabled` guard in `playScene` becomes dead; remove it.
- `CTLDCrateManager:_purgeDisabledScenes()` becomes unused → remove it and its caller.
- Keep `getScene` and `isSceneEnabled` (used by AI vehicle pickup) but simplify `isSceneEnabled`
  (no `_disabled` state → returns whether the model is registered).

`ModValidator` itself is **untouched** (crates/troops still use it — that is Lot B).

## Acceptance criteria

- [ ] `_auditAfterModValidator` + call site removed; no `requiresMod` WARN at mission start.
- [ ] Dead `_disabled` / `_purgeDisabledScenes` paths removed; no dangling references (grep clean).
- [ ] `getScene` / `isSceneEnabled` still work for AI vehicle pickup; tests updated.
- [ ] `ModValidator` runtime behaviour for crates/troops unchanged.
- [ ] Rebuild `CTLD.lua`; busted + luacheck clean.

## Blocked by

02 (design-time gate must replace the runtime audit before it is removed).
