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

- Written to `tests/dcs/CTLD.log` (gitignored).
- Enable with **`cfg.settings["debug"] = true`** — never `ctld.debug = true`, which does **not**
  enable file logging.
- Requires a `ctldLogPath` set in the test `.miz` (MISSION START trigger; local path, never committed).
- `cfg.settings["debugScreenLog"] = true` mirrors every `ctld.utils.log()` on screen;
  `cfg.settings["debugScreenLogDuration"]` sets the duration (default 10 s).

## Rebuild reminder

If `src/` was modified, rebuild before injecting:
`powershell -ExecutionPolicy Bypass -File tools\build\merge_CTLD.ps1`.
