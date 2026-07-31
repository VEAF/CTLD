# 02 — startup NOTICE when a config carries `dropOffZones`

**Status:** todo

Depends on: 01.

## Why

A mission migrating from v1 keeps its `dropOffZones` table, CTLD 2 reads nothing, and its AI transports
stop unloading. There is no error, no warning, no log line — the mission simply behaves differently.
This is the same silent-failure class the recent program removed for `specificParams`
(`FEAT-JTAC-DRONE-GLOBALS` ticket 03) and for incomplete parameters (`FEAT-CONFIG-PARAM-SEMANTICS`), and
it gets the same treatment.

Nothing else catches it. `validate` checks DCS unit types, crate weights, mixedSet consistency and
schema `choices` — an unknown top-level key is not among them. `version-gap` diffs the authored
catalogue against the current default over the flat `Catalog` namespace, so it *would* list
`dropOffZones` under `removed` — but only for someone who opens the config in `ctld-tools`, and a v1
mission's Lua config never passes through the tool at all.

## What changes

- At config load, detect a top-level `dropOffZones` key in the resolved snapshot.
- Emit **one** `ctld.startupReport` **NOTICE** stating that the key is not read, and naming the
  replacement: an `aiZones` entry with `isDropoff: true`.
- `NOTICE`, not `INFO` — it must reach the screen, because the affected mission is precisely the one
  that never meets the tool.
- One message for the key, not one per zone. Do **not** enumerate the zone names: the point is the key,
  and the list would be ten entries long on a stock v1 config.
- Add the message to the i18n dictionaries. **The `ctld.tr()` argument must be a single string
  literal** — a concatenation is harvested wrong by `generate_i18n_dicts.ps1`, as ticket 03 of
  `FEAT-JTAC-DRONE-GLOBALS` found the hard way.

## Open point for the implementer

Whether the detection also covers other v1-only keys worth reporting the same way, rather than
special-casing this one. Resist scope creep: if a general "unknown top-level key" report is the right
answer, it is its own lot, and it needs a rule for keys a mission may legitimately add. Report
`dropOffZones` by name here.

## Acceptance

- A snapshot carrying `dropOffZones` produces exactly one NOTICE, on screen and in
  `CTLD_STARTUP_REPORT`.
- A snapshot without it produces nothing.
- The message says what to do, not only what happened.

## Tests

- busted: snapshot with `dropOffZones` → exactly one NOTICE.
- busted: clean snapshot → none.
- busted: the message resolves through `ctld.tr()` in EN and FR.
