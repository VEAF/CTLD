Status: ready

# 04 — Polygon Moving Zone: relative-offset vertex reconstruction

## What

For a polygon Moving Zone, `env.mission.triggers.zones` stores vertices as offsets relative to
the anchor unit (confirmed by live test: small-valued coordinates, not world coordinates). At
runtime, `trigger.misc.getZone()` returns only the center + enclosing radius — no vertices.

This ticket makes `CTLDTroopZone:isInZone()` reconstruct absolute vertex positions from the
live center + stored relative offsets, so a polygon Moving Zone preserves its shape as it moves.

Detection: at init, if `zd.linkUnit` is present AND `zd.type == 2` (polygon), the vertices in
`zd.verticies` are relative offsets. If `zd.linkUnit` is nil (static zone), the vertices are
already absolute world coordinates (existing behavior).

Store a `_vertexOffsets` field alongside `verticies` for anchored polygon zones.

`_raycast` is unchanged — it always receives absolute vertex positions. The dispatch in
`isInZone()` is updated to compute `abs_verts` before calling `_raycast` when `_vertexOffsets`
is set.

## Scope

- `CTLDTroopZone:init`: accept `vertexOffsets` (relative) in addition to `verticies` (absolute).
  Store as `self._vertexOffsets`.
- `_discoverTRZ()`: if anchored polygon (`zd.linkUnit` and `zd.type == 2`), pass
  `vertexOffsets = zd.verticies` (offsets) instead of `verticies`.
- `CTLDTroopZone:isInZone()`: if `self._vertexOffsets`, compute absolute verts from
  `getCenter()` + offsets before calling `_raycast`.
- Busted tests: verify `isInZone()` with moving center returns correct inside/outside
  classification using relative offsets.

## Definition of done

- Polygon anchored zones correctly classify points at any center position.
- Static polygon zones unchanged (still use `self.verticies` as absolute coords).
- luacheck clean.
