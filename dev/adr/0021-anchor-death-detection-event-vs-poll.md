# Anchor-death detection: DCS event for unit/group, poll for static

**Status:** Proposed (`dev/roadmap.md`, "Zones dynamiques" / "TRZ_ automatique" — not yet
implemented).

**Context:** An anchored CTLD zone (troop or logistic) should be removed outright — not merely
frozen at its last position — when its anchor DCS object is destroyed, freeing the zone's name for
reuse. DCS gives no single reliable destruction signal across object kinds: `S_EVENT_DEAD` is
already proven reliable for a unit/group anchor in this codebase (`CTLDZoneManager:onDead`
already removes a `linkedUnit`-keyed logistic zone this way), but is documented **unreliable for
static objects** at several existing call sites (`CTLD_core.lua`: "Compensates for unreliable
S_EVENT_DEAD on static/base objects"; `CTLD_crate.lua`: "S_EVENT_DEAD not reliable for statics").
`CTLDStaticWatcher` (poll `isExist()`) already exists and is already proven for a static anchor
(the FARP troop-pickup path).

**Decision:** Detect anchor death with `S_EVENT_DEAD` (extending `CTLDZoneManager:onDead` to also
match a troop zone by its `_linkedUnit`/`_anchorUnitName`, not just a logistic zone by its direct
unit-name key) when the anchor is a unit or group. Detect it with `CTLDStaticWatcher` polling when
the anchor is a static. Both converge on the same outcome — real removal, name freed — but through
whichever mechanism DCS actually makes reliable for that object kind, not a single uniform
mechanism forced onto both.

**Consequences:** A future anchor kind must be checked against DCS's own `S_EVENT_DEAD` reliability
before picking a detection path, rather than assuming one mechanism fits every kind. This also
changes existing behavior for a `linkedUnit`-anchored troop zone (ship, ground vehicle via
`createTroopZoneAtObject`): today it freezes forever at the wreck; once implemented, it is removed
instead, matching what a logistic zone already does.
