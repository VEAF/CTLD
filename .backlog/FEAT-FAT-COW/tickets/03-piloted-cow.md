# 03 — Piloted cow: cow crates in a CH-47F and the F10 commands

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FEAT-FAT-COW](../PRD.md). Decision 1, piloted mode.

## What to build

- Cow crates in the CTLD crate catalogue, requestable in a logistic zone by a cow-capable type (`CH-47Fbl1` by default):
  - **fuel tank**: one 800 gal ERFS tank, 2 400 kg of fuel, that mass in the hold;
  - **Hellfire**: a crate of Hellfires (count and mass configurable);
  - **30 mm**: a crate of 30 mm rounds (count and mass configurable).
- F10, once landed with cow crates on board: **Deploy Fat Cow FARP** — the stock is the sum of the cow crates on board, which stay on board (the fuel stays in the cow, as in reality).
- F10, deployed: **Pack Fat Cow FARP** — reads the remaining stock back; the cow crates on board are reduced to what is left (fuel mass in the hold goes down; an emptied crate disappears).
- Taking off while deployed packs automatically.

## Acceptance criteria

- [ ] Busted: stock = sum of the cow crates on board; pack reduces the crates and the hold mass to what is left; the deploy command needs the cow on the ground and at least one cow crate; take-off packs.
