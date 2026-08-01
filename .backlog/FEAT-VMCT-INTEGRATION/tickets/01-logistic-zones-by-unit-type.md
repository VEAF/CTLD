# 01 — logistic zones discovered by unit type

**Status:** done

## Why

A mission maker who wants every carrier and every FARP ammo dump to be a logistic point has to name
each unit in `logisticUnits`. The names are mission-specific, so the list cannot be shared, cannot
survive a copy-paste between missions, and silently misses any unit added later — `_loadLegacyZones`
logs a WARN for a name that is absent, never for a unit that should have been there.

VMCT solved this in its own code: `autoInitializeAllLogistic()` walks every unit in the mission and
registers the ones whose type is in a hardcoded list — `LHA_Tarawa`, `Stennis`, `CVN_71`,
`KUZNECOW`, `FARP Ammo Storage`, `FARP Ammo Dump Coating`. That is a general want expressed in a
private place.

## What changes

- A new **list** setting, `logisticUnitTypes` (empty by default — no behaviour change for an
  existing config), holding DCS type names.
- At init, after `_discoverLGZ()` and before `_loadLegacyZones()`, register every existing unit
  **and static** whose `getTypeName()` matches, as a `CTLDLogisticZone` anchored to that object
  (`linkedUnit`), exactly as `_loadLegacyZones` does for a `logisticUnits` entry — so a carrier
  under way carries its logistic point with it.
- Radius: `maximumDistanceLogistic`, same as the legacy path.
- Coalition: read from the object, as the legacy path does.
- A name already registered by `LGZ_` or by `logisticUnits` wins; discovery never overwrites.
- One INFO line per registered object, and one summary line with the count.

## Type validation — settled

The type names must be checked against the datamine, in **both** places, because neither alone does
the job:

- **`CTLDTypeCollector.collect()`** does *not* reach a plain string list: it is seven blocks, one per
  config shape (registry, `spawnableCrates`, AA templates, `loadableGroups`, `aiZones.vehicleStock` /
  `.vehicleTypes`, `capabilitiesByType.loadableVehicles*`). Add an eighth:
  `for _, tn in ipairs(ctld.gs("logisticUnitTypes") or {}) do add(tn, "logisticUnitTypes") end`.
  Note this only makes a typo **visible**: `config_types_lint_spec.lua` is lenient by design — it
  reports unknown types for a human to eyeball and does not fail.
- **`ctld-tools validate`** is the blocking gate, and today it checks types on crates only
  (`_validate_crates`). Extend it to the new list, at `ERROR`.

The vendored dataset does cover ships and statics (`CVN_71`, `Stennis`,
`FARP Ammo Dump Coating` are all in `tests/data/dcs_types.lua`), so the check is meaningful here.

**One finding, resolved:** `FARP Ammo Storage` — one of the six types VMCT has used in production for
years — is **absent** from the dataset, and it always will be: it is the *display* name of the object
whose spawn type id is `FARP Ammo Dump Coating`. The datamine file
`_G/db/Units/Fortifications/Fortification/FARP Ammo Dump Coating.lua` (ref `d75d7ac`) carries
`DisplayName = "FARP Ammo Storage"`, `Name = "FARP Ammo Storage"` and `swapped_names = true` — DCS
swapped the two labels for this object. `getTypeName()` returns the type id, never the display name,
so VMCT's `FARP Ammo Storage` entry has never matched anything: its six types are really five. Do not
carry it into the VEAF default config; the `ctld-tools validate` check added by this ticket rejects
it on its own.

## Acceptance

- A config listing `Stennis` registers a mission's carrier with no unit name anywhere in the config.
- The carrier's logistic zone follows it as it steams.
- An empty / absent `logisticUnitTypes` changes nothing.
- A type present in the config but absent from the mission is not an error and not a WARN — it is a
  catalogue of types, not a manifest.

## Tests

- busted: two units of a listed type → two logistic zones; a third of an unlisted type → none.
- busted: a unit also named in `logisticUnits` → one zone, not two.
- busted: absent setting → zero zones from this path.
