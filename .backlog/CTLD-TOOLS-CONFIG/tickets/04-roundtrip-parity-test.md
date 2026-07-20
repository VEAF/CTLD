# 04 — Migration parity test (Lua 5.1 deep-equal)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

The switch-over guard. A test that:

1. executes **both** the current hand-written `CTLD_config.lua` and the regenerated Lua (from ticket
   03) under **`lua5.1`** (subprocess),
2. calls `CTLDConfig:load()` on each,
3. **deep-equals** the resulting `settings` tables.

Keep the pre-switch-over defaults as a **frozen reference fixture** so the assertion survives the
removal of the inline block in ticket 05. The test **skips cleanly** when `lua5.1` is absent locally
(present in CI: `lua-lint` + `busted` jobs install it).

This is the gate that authorises ticket 05 (removing the inline defaults). Legacy parity is
immutable — this proves the regenerated defaults are behaviourally identical.

## Acceptance criteria

- [ ] Loads old + regenerated config under `lua5.1`, deep-equals `settings` → identical.
- [ ] Any value/type/ordering divergence fails the test with a readable diff.
- [ ] Skips cleanly without `lua5.1`; runs in CI.
- [ ] Frozen reference fixture committed so the test outlives ticket 05.
- [ ] Green before ticket 05 proceeds.

## Blocked by

Tickets 02, 03.
