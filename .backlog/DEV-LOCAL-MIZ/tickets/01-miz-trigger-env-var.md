# 01 — Replace the hardcoded miz path with the CTLD_DEV_ROOT trigger

Status: ✅ done
Type: hybrid (AFK authoring + live DCS validation)
Repo: CTLD
GitHub: —

## What to build

Make the martyr (`missions/Test_CTLDNEXT_01.miz`) load `CTLD.lua` from the `CTLD_DEV_ROOT`
environment variable instead of a hardcoded absolute path, and drop the dead `ctldLogPath` line.

**Authoring (AFK) — provide the final snippet:**

```lua
-- Load the developer's local CTLD.lua via CTLD_DEV_ROOT (DCS must be de-sanitized).
local root = os and os.getenv("CTLD_DEV_ROOT")   -- os absent = sanitized DCS
if not root then
  local msg = "[CTLD dev] os/CTLD_DEV_ROOT unavailable -- de-sanitize MissionScripting.lua and "
           .. "run 'setx CTLD_DEV_ROOT <repo>' then restart DCS. CTLD.lua NOT loaded."
  env.error(msg); trigger.action.outText(msg, 30)
  return
end
local path = root .. "/CTLD.lua"
local ok, err = pcall(dofile, path)
if not ok then
  local msg = "[CTLD dev] dofile(" .. path .. ") failed: " .. tostring(err)
  env.error(msg); trigger.action.outText(msg, 30)
end
```

**Miz edit (live DCS, by the developer) — in the DCS mission editor:**

1. Open `Test_CTLDNEXT_01.miz` → Triggers → the MISSION START trigger.
2. DO SCRIPT action **(1)**: replace its entire content with the snippet above.
3. DO SCRIPT action **(2)** (`CTLDConfig.get().settings["ctldLogPath"] = "C:/CTLD.lua"`): **delete** it.
4. Leave action (3) (`dcsBridge = {...}`) and action (4) (`DO SCRIPT FILE` → `dcs-bridge.lua`) untouched.
5. Save the mission.

**Environment (once, by each developer):**

- `setx CTLD_DEV_ROOT "<path to repo root>"`, then **restart DCS** (a running DCS does not inherit the
  new variable).
- DCS must be de-sanitized (`MissionScripting.lua`), else `os.getenv` is absent and the trigger fails
  with its explicit message.

No `src/` change, no rebuild.

## Acceptance criteria

- [ ] Martyr MISSION START trigger loads `CTLD.lua` via `os.getenv("CTLD_DEV_ROOT") .. "/CTLD.lua"`.
- [ ] No absolute machine path remains anywhere in the miz (verify: unzip → grep the `mission` file for
      `C:/`, `D:/`, `dofile("`).
- [ ] Dead `ctldLogPath = "C:/CTLD.lua"` line removed.
- [ ] Hardened behaviour verified in-game: with var set + DCS restarted → CTLD loads (F10 menu appears);
      with var unset (or sanitized DCS) → the on-screen `[CTLD dev]` message shows and CTLD does not load.
- [ ] Committed miz contains the generic trigger (this is the last intended large binary diff).

## Blocked by

None. The doc/skill updates (ticket 02) can land in parallel.
