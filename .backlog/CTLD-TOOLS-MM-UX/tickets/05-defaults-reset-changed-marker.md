# 05 — Defaults endpoint, reset-to-default, changed marker

**Status:** done

## Goal

Make editing reversible (finding 5) and make the standard/advanced split actually reduce load
(finding 7).

## Backend

- `GET /api/defaults` → `{ values: { key: value } }`, the flat scalar values of
  `session.default_catalog()`. Additive, no state change. Reuses `_plain()`.
- pytest coverage: the endpoint returns the same keys as a freshly loaded default catalogue.

## Frontend

- `api.ts`: `getDefaults()`, called once on boot alongside the schema.
- Each setting row compares its value to the default:
  - equal → nothing extra;
  - different → a `changed` marker on the row and a `Reset` control that PUTs the default back.
- A per-family count of changed settings in the rail, and a total in the header — a MM can see at a
  glance what they have touched, which is also the answer to "what will this change in my mission?".
- `Advanced` settings move into a disclosure, closed by default, labelled with its count. It opens
  automatically when it contains a changed setting (never hide a modification) or when a search is
  active.

## Done when

- `isChanged(value, default)` is unit-tested including the number/string coercion edge (`"10"` vs
  `10`) and structured values.
- A component test asserts the reset control restores the default and disappears afterwards.
- The advanced disclosure is open when a contained setting differs from its default.
