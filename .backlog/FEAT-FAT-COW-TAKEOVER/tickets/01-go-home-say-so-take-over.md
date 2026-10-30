# 01 — despawn only at home, announce the orphan, take it over

Status: done

See the [PRD](../PRD.md).

## Acceptance

- A returning cow landing more than 2 km from home is not despawned; at home it is.
- A cow whose flight is gone tells each helicopter player flight of its coalition without a cow (one message per group), and no one else.
- "Take over a Fat Cow" lists, to those flights, every cow of the coalition flying home (lost flight or RTB, empty or not), nearest first with its distance, refreshed every 30 s; an entry leaves every menu once its cow is taken over, home or dead.
- Taking one over: the cow follows the new flight, which commands it like a cow it requested; a flight with a cow already, or a cow no longer going home, is told why not.
