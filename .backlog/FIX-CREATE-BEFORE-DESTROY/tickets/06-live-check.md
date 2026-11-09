# 06 — Live check in DCS

**Status:** ⬜ ready (01-05 done in PR #300; to run before it is merged) · **Type:** HITL

## Parent

[PRD — FIX-CREATE-BEFORE-DESTROY](../PRD.md).

## What to build

Verify in a running mission what the unit tests cannot: DCS cannot be made to refuse a creation without tampering, so the check is that the
**success path of each site is unchanged**, and that the AA respawn on top of the old group works.

Through the DCS bridge's Python scenario runner (never the MCP tool), on `Test_CTLDNEXT_01.miz`, with a scenario per site under `tests/dcs/`
(from the template, tier header set), keeping clear of any live player unit when spawning:

1. Pack a vehicle (a JTAC one too: it must stop being a JTAC only once packed), then unpack its crates again.
2. Pack a deployed FARP scene and redeploy it: the warehouse stock comes back from the crates.
3. Deploy a piloted Fat Cow FARP, pack it, deploy again: the stock matches.
4. Unpack an equipment crate and a parachuted crate (auto-unpack).
5. Repair and rearm an AA system: the new group appears over the old one, which then goes; no ghost unit, no double system.

The maintainer plays one pack by hand in the cockpit (a CH-47F pack of a vehicle) to confirm what the pilot reads.

## Acceptance criteria

- [ ] Each of the five checks recorded PASS or FAIL with the DCS log lines that prove it.
- [ ] AA respawn overlap: no error in the DCS log, one system left, the repair crate consumed.
- [ ] The maintainer confirms the hand test; the lot's index line and PRD status are set to done.

## Blocked by

- [01](01-helper-adr-and-vehicle-pack.md), [02](02-farp-scene-pack.md), [03](03-fat-cow-farp-pack.md), [04](04-unpack-to-a-unit.md), [05](05-aa-system-rearm-repair.md)
