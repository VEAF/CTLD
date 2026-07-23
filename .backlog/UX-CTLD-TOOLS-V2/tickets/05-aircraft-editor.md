# 05 — Aircraft editor (capabilitiesByType)

Status: ready

## What to build

Add the Aircraft section to the catalogue tree — the first entirely new table in v2
(absent from v1). The MM can browse all aircraft in the default catalogue, modify any
capability attribute, add a new aircraft type (e.g. a mod), or remove one.

End-to-end behaviour:
- Tree node "Aircraft" expands to list all `capabilitiesByType` entries by DCS type name.
- 4 visual states per entry.
- Clicking an aircraft entry opens the form with all ~12 attributes:
  - Bool fields (checkboxes or dropdowns): `cratesEnabled`, `troopsEnabled`,
    `canSlingload`, `canParachuteDrop`, `useNativeDcsCargoSystem`,
    `canTransportWholeVehicle`, `convertNativeLoadToCTLD`.
  - Numeric fields: `maxCratesOnboard`, `maxTroopsOnboard`, `maxWholeVehiclesOnboard`,
    `maxVehicleWeight`.
  - List-of-strings fields rendered as inline mini-lists with +/× controls:
    `loadableVehiclesBLUE`, `loadableVehiclesRED`.
- Apply / Delete / Cancel. Restore for deleted entries.
- Add from "Aircraft" node: blank form with a filterable DCS type picker for the
  aircraft type name; Apply creates the entry (green in tree).
- `Reference` extended with accessors: `aircraft_types()` (list of DCS type names) and
  `aircraft_capabilities(name)` (dict of attribute defaults for a given type).

## Acceptance criteria

- [ ] Tree renders all `capabilitiesByType` entries from `Reference`; 4 visual states.
- [ ] Form exposes all ~12 capability attributes with appropriate widget per type
  (bool → dropdown, numeric → entry, list-of-strings → inline mini-list).
- [ ] `loadableVehiclesBLUE` and `loadableVehiclesRED` rendered as inline lists: each
  item has a `×` remove button; a text input + `+` button appends a new entry.
- [ ] Apply commits modify or add to `EditModel`; tree state updates.
- [ ] Delete marks a default aircraft for removal; Restore un-marks.
- [ ] Add via DCS type picker: filterable list drawn from the datamine; Apply creates
  the new entry (green) with all attributes at their default values.
- [ ] `Reference.aircraft_types()` and `Reference.aircraft_capabilities(name)` added
  and covered by `test_reference.py`.
- [ ] `test_catalogue_tree.py` extended for aircraft states.

## Blocked by

- Ticket 02 (scalars editor)
