# 02 — correct what "no entry" means, and record the Ka-50 decision

**Status:** todo

Depends on: 01 (ships with it; same PR).

## Why

`docs/mission-maker/configuration.{md,fr.md}` states:

> **Only aircraft listed here receive CTLD F10 menus.**

That is not what the code does. `buildMenu` runs for every player and each section gates itself on
`isTransport`, so an aircraft with no entry keeps the `CTLD` root, **Check Cargo**, the whole **RECON**
submenu and the **JTAC** submenu with its status — it loses crates, troops, beacons and smoke. A
mission maker reading the current sentence concludes their Gazelle pilot sees nothing at all, which is
both wrong and the reason the Ka-50 question looked harder than it is.

## What changes

- **`docs/mission-maker/configuration.{md,fr.md}`**: replace the claim with what actually happens.
  A short table beats a sentence — what stays, what goes.
- **The Ka-50 decision, somewhere a reader will meet it.** The catalogue lists no `Ka-50`, and the
  next person to compare CTLD 2 against v1 will read that as an oversight. State it: v1's Ka-50
  transport was a side effect of two missing table entries, CTLD 2 does not carry it over, and adding
  an entry with both transport modes off would only add the beacon action. The migration guide
  (`docs/developer/migration-v1-v2.{md,fr.md}`) is the natural home — it is where v1-vs-v2 differences
  are explained — with a one-line pointer from the configuration page.
- If ticket 01 concludes `canParachuteDrop` differently for the Gazelle and the Yak-52, the docs say
  which and why.

## Acceptance

- No page claims an aircraft without an entry has no CTLD menu.
- A reader who wonders why the Ka-50 is absent finds the answer without opening `.backlog/`.
- EN and FR say the same thing.
- `mkdocs build --strict` passes.

## Tests

None beyond the docs build.
