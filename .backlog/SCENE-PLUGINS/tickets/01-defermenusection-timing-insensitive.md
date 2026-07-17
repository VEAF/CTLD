# 01 — Make deferMenuSection load-position-independent

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

`CTLDPlayerManager._deferredSections` is flushed **once** in `CTLDPlayerManager:_init()` then
cleared. A scene loaded *after* CTLD init (a plugin loaded by a mission-start trigger) that calls
`deferMenuSection` lands in the now-orphan table and its radio submenu **never appears**.

Make `deferMenuSection` timing-insensitive: if called after `_init` has run, route directly to
`registerMenuSection` instead of appending to the drained queue. Result: a scene's source is
identical whether merged into `CTLD.lua` or loaded as a plugin.

## Acceptance criteria

- [ ] `deferMenuSection` called **before** init still queues and flushes as today (no regression).
- [ ] `deferMenuSection` called **after** init registers the section immediately; the next
      `buildMenu` (player slot-in) renders it.
- [ ] busted test covers both timings (pre-init queue-and-flush, post-init direct register).
- [ ] Rebuild `CTLD.lua`; luacheck clean.

## Blocked by

None.
