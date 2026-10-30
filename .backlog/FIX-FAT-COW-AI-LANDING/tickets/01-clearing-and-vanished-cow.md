# 01 — land in a clearing, forget a vanished cow

Status: in progress

See the [PRD](../PRD.md).

## Acceptance

- The Land task point is the nearest `Disposition.getSimpleZones` candidate within 300 m of the point 120 m left of the leader, on land and at least 60 m from the leader; the asked point when there is none or the call fails.
- An AI cow whose unit no longer exists is forgotten within 10 s, as if it had died: its flight can request another cow.
