# 06 — Live check in DCS

**Status:** 🧑 waiting-human · **Type:** HITL (live DCS, Zip)

## Parent

[PRD — FEAT-FAT-COW](../PRD.md).

## What to check

- Piloted: a CH-47F loads cow crates, lands, deploys; an Apache landed next to it is served up to the stock; pack; the hold mass went down.
- AI: an Apache requests a cow in a logistic zone, takes off, the cow follows, both land, the FARP deploys after 60 s, the Apache is served, takes off, the cow packs and follows; release sends it home.
- The range: how far from the cow an Apache can land and still be served (ticket 01 used 0 m).
- The 30 mm crate: whether `weapons.shells.M230_HEDP M789` is the warehouse item the Apache's gun reload draws from.
- The AI cow's DCS behaviour, which the unit tests only mock: the `Follow` task on a player flight, the `Land` task next to the leader on open ground, the take-off when re-tasked, the despawn at home.
- If a second player is available: the client side of ticket 01 (b).
