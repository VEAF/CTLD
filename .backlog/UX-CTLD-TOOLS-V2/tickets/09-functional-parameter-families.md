# 09 — Functional parameter families in the settings tree

Status: ready

## What to build

Replace the flat Standard / Advanced split in the Parameters section of the catalogue
tree with **12 named functional families**. Each family node contains two sub-nodes
(Standard / Advanced) that hold the scalar settings belonging to that family.

Settings are assigned to families via a new `group:` field in `CTLD_config_schema.yaml`.
Settings that have no `group:` entry fall through to an "Other" sub-node under a catch-all
Advanced group so nothing is lost.

### Families and their members

| Family | Key (`group:` value) | Settings |
|--------|----------------------|----------|
| Général | `general` | `debug`, `debugScreenLog`, `ctldLogPath`, `i18n_lang`, `location_DMS`, `radioSound`, `radioSoundFC3`, `addPlayerAircraftByType` |
| Caisses | `crates` | `enableAllCrates`, `enableCrates`, `loadCrateFromMenu`, `enablePackingVehicles`, `enableHoverSlingload`, `slingLoad`, `maximumDistancePackableUnitsSearch` |
| Troupes | `troops` | `numberOfTroops`, `allowRandomAiTeamPickups`, `troopPickupAtFOB`, `maxExtractDistance`, `maximumSearchDistance` |
| Embarquement | `boarding` | `enableFastRopeInsertion`, `fastRopeMaximumHeight` |
| JTAC | `jtac` | all `JTAC_*` (including `JTAC_smoke*` — Smoke JTAC merged here) |
| Smoke général | `smoke` | `disableAllSmoke`, `enableSmokeDrop` |
| Beacon | `beacon` | `deployedBeaconBattery`, `enabledRadioBeaconDrop` |
| FOB / FARP | `fob` | `enabledFOBBuilding`, `fobDestructionThreshold`, `fobLogisticZoneRadius`, `fobMinDistanceFromZones`, `fobTroopPickupRadius`, `enableFARPRepack`, `maximumDistanceLogistic` |
| Reconnaissance | `recon` | `reconEnabled`, `reconF10Menu`, `reconIconScale`, `reconMinAltitude`, `reconRefreshInterval`, `reconSearchRadius` |
| Mines | `mines` | `demineRadius`, `showMinefieldOnF10Map` |
| Système AA | `aa` | `AASystemCrateStacking`, `AASystemLimitBLUE`, `AASystemLimitRED`, `aaLaunchers` |
| Poids soldats | `soldier_weights` | `CIV_WEIGHT`, `KIT_WEIGHT`, `MANPAD_WEIGHT`, `MG_WEIGHT`, `MORTAR_WEIGHT`, `RIFLE_WEIGHT`, `RPG_WEIGHT`, `SOLDIER_WEIGHT` |

### Tree structure

```
▸ Paramètres
    ▸ Général
        ▸ Standard   ← mm_facing settings in this family
        ▸ Avancé     ← other settings in this family
    ▸ Caisses
        ▸ Standard
        ▸ Avancé
    … (one per family)
```

### Schema changes

Each setting entry in `CTLD_config_schema.yaml` gains a `group:` key:

```yaml
JTAC_lock:
  group: jtac
  standard: true        # replaces is_mm_facing logic
  description:
    en: "..."
    fr: "..."
```

`Reference.is_mm_facing(name)` is replaced by two new accessors:
- `Reference.setting_group(name) -> str | None` — returns the `group:` value or `None`
- `Reference.is_standard(name) -> bool` — reads the `standard:` boolean (defaults to `False`)

`_rebuild_tree()` in `app.py` groups scalar iids by `setting_group()`, then splits each
family into Standard / Advanced sub-nodes using `is_standard()`.

## Acceptance criteria

- [ ] `CTLD_config_schema.yaml` has a `group:` entry for every setting listed in the table above.
- [ ] `Reference.setting_group(name)` and `Reference.is_standard(name)` are implemented and tested.
- [ ] The Parameters section of the tree shows 12 family nodes, each with Standard and Advanced sub-nodes.
- [ ] Settings without a `group:` entry appear under a catch-all node (not silently dropped).
- [ ] Visual states (bold `*`, strikethrough, green) are preserved for all scalar nodes.
- [ ] Tree-node tooltips (ticket 08 + tree-motion binding) continue to work.
- [ ] All existing tests pass; new unit tests cover `setting_group` and `is_standard`.

## Blocked by

- Ticket 08 (schema + tooltips — already merged on branch)
