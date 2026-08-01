# FIX-VALIDATE-MODTYPES — `validate` rejects the modded types `modTypes` exists to declare

**Status:** open.

Opened 2026-08-01, found while adding the type-list rule for `FEAT-VMCT-INTEGRATION` ticket 01.

## The defect

The `modTypes` setting has exactly one job, and the schema states it plainly:

> A list of DCS unit type names that come from mods rather than the base game. **Listing a type here is
> what stops validation rejecting it as unknown to DCS**, so add every modded unit your mission spawns.

`ctld-tools validate` does not honour it. `_validate_crates` compares every crate `unit` against
`known_dcs_types()` — the vendored datamine set, nothing else — so a modded crate is an **`ERROR` that
blocks export**, exactly what declaring it in `modTypes` was supposed to prevent. Reproduced against
the current code:

```python
c = Catalog.loads("""mm_facing:
  spawnableCrates:
    Support:
    - unit: AH-64D_BLK_II_MOD
      desc: Modded crate
      weight: 1001.01
advanced:
  modTypes:
  - AH-64D_BLK_II_MOD
""")
validate(c, Schema({}), frozenset({"Ural-375"}))
# → [error] spawnableCrates.Support[Modded crate]: unknown DCS unit type 'AH-64D_BLK_II_MOD'
# → has_errors: True
```

The Lua side has it right: the offline type lint reads `CTLDTypeCollector.collect().extras`, which is
`modTypes` ∪ every scene's `modTypes`, and excuses those types. So the two layers **disagree**, and the
blocking one is the wrong one.

## Scope of the disagreement

`validate()` currently runs three type-aware rules:

| Rule | Honours `modTypes`? |
|---|---|
| `_validate_crates` (crate `unit`) | **no** |
| `_validate_type_lists` (`logisticUnitTypes`, `troopZoneShipTypes`) | yes — added by `FEAT-VMCT-INTEGRATION`, which could not have shipped otherwise |
| `_validate_choices` / `_validate_completeness` | not type-aware |

So the codebase now holds two behaviours in one file. That is the immediate reason to fix it: the
inconsistency was introduced knowingly, flagged in the delivering PR, and left for this lot rather than
widened.

## Definition of done

- A crate whose `unit` is declared in `modTypes` validates clean and exports.
- A crate whose `unit` is in neither the datamine nor `modTypes` still fails, unchanged.
- One resolution of the known-type set, used by every type-aware rule — not a second copy of the union.
- The scene-provided `modTypes` question is answered in writing (see ticket 01): the Lua lint unions
  them in, `validate` has no access to scene models, so either the tool is knowingly narrower or the
  gap is recorded.

## Out of scope

- Any change to what `modTypes` means, or to the schema text — the text is right, the code is wrong.
- Validating that a modded type actually exists in the user's DCS install. Impossible offline and not
  the point.
