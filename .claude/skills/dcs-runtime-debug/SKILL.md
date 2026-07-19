---
name: dcs-runtime-debug
description: Diagnose a CTLD runtime / in-game issue in DCS World by reading the DCS and CTLD logs. Use when a script fails to load, an F10 menu is missing, or a feature misbehaves in a running mission.
---

# DCS runtime debugging

When a **runtime / in-game** problem occurs (script not loading, missing F10 menu, feature
misbehaving inside DCS), read the logs to see what actually happened at runtime — load order,
module init, Lua errors.

## DCS log

- Location: `%USERPROFILE%\Saved Games\DCS\Logs\dcs.log` (or `DCS.openbeta`).
- Useful greps: `CTLD`, `SCRIPTING`, `initialize`, `ERROR`.

## CTLD log

- Optional CTLD-only file mirror of the log (everything is *also* in `dcs.log` via `env.info`, so
  this is a convenience filter, not a separate source).
- Written under `ctld.path` (gitignored), e.g. `tests/dcs/CTLD.log`.
- Enable it **on demand** by injecting `tests/dcs/dev/diag/diag_enable_ctld_log.lua`: it sets
  `ctldLogPath` and turns on debug file logging at runtime — no rebuild, no `.miz` edit. (The martyr
  does **not** set `ctldLogPath` itself; the DEV-LOCAL-MIZ trigger only loads `CTLD.lua`.)
- File logging is gated on **`cfg.settings["debug"] = true`** — `ctld.debug = true` does **not**
  enable it.
- `cfg.settings["debugScreenLog"] = true` mirrors every `ctld.utils.log()` on screen;
  `cfg.settings["debugScreenLogDuration"]` sets the duration (default 10 s).

## Rebuild reminder

If `src/` was modified, rebuild before injecting:
`powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`.
