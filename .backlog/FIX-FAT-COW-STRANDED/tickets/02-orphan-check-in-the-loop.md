# 02 — The orphan check also runs in the 10 s loop

**Status:** 🟡 ready · **Type:** AFK

## Parent
[PRD](../PRD.md), decision 2.

## What to build
`_sendHomeOrphans` is also called by the 10 s loop that calls `_forgetVanishedCows`, so a cow whose flight disappears is sent home even when the one-shot check 2 s after the event ran too early.

## Acceptance criteria
- [ ] A flight still present at the 2 s check and gone at the next loop tick: its cow goes home and is offered for take-over, once.
- [ ] A cow already returning is not sent home again.
