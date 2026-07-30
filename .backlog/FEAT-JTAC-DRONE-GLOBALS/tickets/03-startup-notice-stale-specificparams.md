# 03 — startup NOTICE when a config still carries `specificParams`

**Status:** ready

Depends on: 02.

## Why

After ticket 02 the engine ignores `specificParams` on a crate. An existing mission config still
carrying it would fly its drones differently than its author intended, with no trace — the exact silent
failure mode this program removes elsewhere.

Nothing else catches it. `validate` only checks DCS unit types
([validate.py:71](../../../tools/ctld-tools/ctld_tools/validate.py#L71)); `version-gap` diffs the flat
top-level `Catalog.keys()` namespace, so a field nested inside a `spawnableCrates` entry never appears in
its report. And an MM may hand-write the YAML, so no tool sees it at all.

## What changes

- During crate processing (`_processSpawnableCrates`, [CTLD_crate.lua:438](../../../src/CTLD_crate.lua#L438))
  or at config load, detect any crate descriptor carrying a `specificParams` key.
- Emit **one** `ctld.startupReport` **NOTICE** — not one per crate — listing the affected crate
  descriptions and naming the four settings that now govern orbit behaviour.
- `NOTICE`, not `INFO`: it is displayed on screen. A hand-written config never meets `validate`, so this
  is the only signal its author will get.
- Add the message to the i18n dictionaries (the build syncs them; the `pre-push` hook blocks on missing
  keys).

## Acceptance

- A config with `specificParams` on two crates produces exactly one NOTICE naming both.
- A clean config produces nothing.
- The message tells the MM what to do, not just what happened — it names the replacement settings.

## Tests

- busted: descriptor with `specificParams` → one NOTICE, correct crate names.
- busted: clean catalogue → no NOTICE.
- busted: the message resolves through `ctld.tr()` in EN and FR.
