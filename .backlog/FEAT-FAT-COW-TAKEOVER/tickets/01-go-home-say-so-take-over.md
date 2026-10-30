# 01 — despawn only at home, announce the orphan, take it over

Status: in progress

See the [PRD](../PRD.md).

## Acceptance

- A returning cow landing more than 2 km from home is not despawned; at home it is.
- A cow whose flight is gone, with stock, tells each eligible player flight of its coalition (one message per group), and no one else.
- "Take over a Fat Cow" is in the AI Fat Cow menu of a flight without a cow while such a cow exists, and leaves every menu once it is taken over, despawned or dead.
- Taking it over: the cow follows the new flight, which commands it like a cow it requested; a flight with a cow already, or with no orphan around, is told why not.
