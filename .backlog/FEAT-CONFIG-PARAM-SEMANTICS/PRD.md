# FEAT-CONFIG-PARAM-SEMANTICS — parameters are always complete, lists are removable

**Status:** done — all four tickets delivered, pending PR to `develop`.

Lot **A** of the post-review program (2026-07-30). Independent of lots B / C / D — can ship in
parallel. Closes `dev/roadmap.md` items 2 and 3, which turn out to be one subject.

> **Delivered.** ADR 0011 Addendum 1 (and the stale "Accepted" status on ADRs 0008/0009, found by
> ticket 01's acceptance check). Engine: `CTLDConfig.flatten()` extracted, an eager default-resolution
> map built only when a `configUser` is present, `getSetting()` falling back for scalars only, and a
> single on-screen startup NOTICE. **114 duplicate fallbacks deleted**, five of which had drifted —
> including three parachute-altitude divergences the roadmap never listed. Tool: a `validate`
> completeness rule at `ERROR`, keyed off the default catalogue.
>
> **Verification.** **164 pytest tests** + ruff check/format clean, `test_web_app.py` included (its
> `fastapi` / `httpx` were missing locally and were installed at their lock versions). The frontend and
> `ctld-tools.exe` built with the CI recipe, and `GET /api/validate` on the default catalogue **served
> by the exe** returns `{"hasErrors":false,"findings":[]}` — the completeness rule does not
> false-positive on the real shipped catalogue.
>
> Lua remains the gap: `busted` and `luac5.1` are not installed on this machine, so the specs were
> mirrored through standalone Lua harnesses (13 tier assertions, plus a post-sweep invariant proving
> every unguarded `ctld.gs()` resolves under the default catalogue). `luacheck` reports 66 warnings
> before and after, none introduced. **CI is still the first confirmation for the busted suite and the
> Lua 5.1 syntax gate.**

## Why

[ADR 0011](../../dev/adr/0011-complete-yaml-config-and-webapp-tooling.md) states two things that are
right for collections and wrong for scalars:

> **A missing element means intentional removal.** (point 1)
> Loading is a straight `or`, never a merge. (point 2)

The config holds two different kinds of thing, and the ADR treats them as one:

- **Lists** (`spawnableCrates`, `loadableGroups`, `aiZones`, `troopZones`, …) — omitting an element
  *is* a meaningful removal. This is the semantic the ADR was written for, and it stays.
- **Parameters** (`slingCutDestroyHeight`, `JTAC_laseIntervalSeconds`, …) — "removed" has no meaning.
  The engine needs a number to compute with. A missing parameter is not a decision, it is an
  incomplete document.

Three call sites prove it by crashing. They read a parameter with no fallback and feed it straight
into arithmetic or a comparison:

| Site | Code | Failure |
|---|---|---|
| [CTLD_jtac.lua:905-906](../../src/CTLD_jtac.lua#L905) | `searchInterval` / `laseInterval`, then `t + searchInterval` | error on every JTAC tick |
| [CTLD_crate.lua:1503](../../src/CTLD_crate.lua#L1503) | `agl > ctld.gs("slingCutDestroyHeight")` | error on every crate release |

This is reachable through a path the project already tools for: a config authored against an older
catalogue, to which the engine has since added keys — exactly what `version-gap` detects. **And a
Mission Maker may hand-write the YAML, so it never passes through `validate` at all.**

The same root cause produces roadmap item 2. Because parameters carry per-site `or <literal>`
fallbacks, the same default lives in two places and they have already drifted:

| Parameter | `src/CTLD_config.yaml` | Lua fallback |
|---|---|---|
| `maximumSearchDistance` | 3000 | 10000 — [CTLD_troop.lua:1521](../../src/CTLD_troop.lua#L1521) and [:1546](../../src/CTLD_troop.lua#L1546) |
| `maximumDistanceLogistic` | 200 | 500 — [CTLD_zone.lua:897](../../src/CTLD_zone.lua#L897) |

Resolve the semantic and both problems close: the embedded default YAML becomes the single source of
truth, and the literals are deleted rather than reconciled.

## Decisions

1. **Two-tier semantic, recorded as an ADR addendum.** A missing **parameter** resolves to the
   default; a missing **list element** is an intentional removal. Both tiers stated explicitly.
2. **Engine — lazy fallback.** `ctld.gs()` resolves a missing parameter from the parsed
   `configDefault`, parsed on first miss only (zero cost when the config is complete, which is the
   normal case). A startup **NOTICE** lists every parameter that was defaulted — on screen, not
   log-only, because for a hand-written config it is the only signal the MM will ever get.
3. **Engine — delete the redundant literals.** The ~100 `or <scalar literal>` fallbacks become dead
   weight. The 46 `or {…}` fallbacks on collections **stay**: a missing collection legitimately means
   empty.
4. **Tool — completeness rule.** `validate` reports a missing parameter as `ERROR`, which blocks
   export (`has_errors()` is already the gate — [validate.py:10](../../tools/ctld-tools/ctld_tools/validate.py#L10)).
5. **Classifier derived, not declared.** Parameter vs list is read from the *shape of the default
   value* — scalar means parameter, list or map means collection. No new data to maintain and no
   drift surface. Verified safe: the only two fixed-arity tuples that land on the "collection" side,
   `nbLimitSpawnedTroops` and `beaconIconColor`, already carry their own guards
   ([CTLD_troop.lua:689](../../src/CTLD_troop.lua#L689), [CTLD_beacon.lua:635](../../src/CTLD_beacon.lua#L635)).

## Out of scope

- Re-litigating the complete-YAML model itself. Lists keep "missing = removal"; only the scalar tier
  is specified.
- Deep-merging list *elements*. Explicitly rejected by ADR 0011 and not revisited.

## Definition of done

- A config missing any parameter runs, uses the default, and says so once on screen.
- No parameter has two defaults: the YAML is the only place a default value is written.
- `maximumSearchDistance` and `maximumDistanceLogistic` resolve to their catalogue values (3000 / 200).
- `validate` fails a config that omits a parameter, and names the omissions.
- ADR 0011 carries the addendum, so the next reader does not re-derive this.
