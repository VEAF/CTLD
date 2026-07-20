# Configuring CTLD with `ctld-tools`

`ctld-tools` is a small command-line tool that lets you configure CTLD **without writing Lua**. You
describe your changes in a short **`user-config.yaml`** — referring to crates and troop groups **by
name** — and the tool validates it and generates the `CTLD_userConfig.lua` your mission loads.

You never look up crate weights, and mistakes are caught at your desk (with suggestions) instead of
in DCS.

## Get the tool

Download **`ctld-tools.exe`** from the [GitHub Releases](https://github.com/VEAF/CTLD/releases) page
— it is attached to each release. No Python needed. (Developers can also run it from source with
`poetry`; see the developer docs.)

Put it anywhere; run it from a terminal in your mission folder.

## The workflow

```
ctld-tools gen-user --scaffold --out user-config.yaml          # 1. commented starter
#   ... edit user-config.yaml ...                              # 2. describe your changes
ctld-tools validate  --yaml user-config.yaml --src path/to/src # 3. check it
ctld-tools gen-user  --yaml user-config.yaml --src path/to/src --out CTLD_userConfig.lua  # 4. generate
#   ... load CTLD_userConfig.lua before CTLD.lua in the Mission Editor ...   # 5. use it
```

`--src` points at the CTLD `src/` folder (the reference catalogue): the tool reads it to resolve
names, and to know which crates, troop groups and DCS unit types exist.

## The `user-config.yaml` format

Four optional top-level sections. **Only include what you change.** Crates and troop groups are
targeted **by name**.

### `settings` — simple values

```yaml
settings:
  numberOfTroops: 8
  slingLoad: true
```

### `crates` — add / remove / patch

```yaml
crates:
  add:
    - section: Support        # F10 sub-menu
      name: Ural Ammo         # label shown in the menu
      unit: Ural-375          # DCS type name (validated)
      side: 1                 # 1=RED, 2=BLUE, omit=both
      cratesRequired: 2
      weight_kg: 2000         # crate mass in kg (also its unique key)
  remove:
    - Heavy Tank - Abrams     # by name — no weight to look up
  patch:
    - name: Humvee - TOW      # change one field, keep the rest
      cratesRequired: 3
```

### `troops` — add / remove

```yaml
troops:
  add:
    - name: Recon Team
      inf: 3
      jtac: 1
  remove:
    - 5x - Mortar Squad
```

### `arrays` — append to list settings

```yaml
arrays:
  transportPilotNames: [helicargo_custom_1]
  troopZones:
    - [pickzone_north, green, -1, yes, 0]
```

!!! tip "Block or flow — your choice"
    Everything above is *block* style (indented, readable). You can also write the compact *flow*
    style; it's the same YAML:
    ```yaml
    crates:
      add:
        - { section: Support, name: Ural Ammo, unit: Ural-375, side: 1, weight_kg: 2000 }
    ```

## Commands

| Command | What it does |
|---|---|
| `gen-user --scaffold --out user-config.yaml` | Write a commented starter file. |
| `validate --yaml user-config.yaml --src src` | Check the file; prints findings, exits non-zero on error. |
| `gen-user --yaml user-config.yaml --src src --out CTLD_userConfig.lua` | Compile to Lua (runs `validate` first, refuses on error). |
| `inject --miz mission.miz --userconfig CTLD_userConfig.lua [--out out.miz]` | Inject the generated Lua into a `.miz` as a MISSION START trigger (optional — see below). |

**What validation checks:** every `unit` is a real DCS type; a crate you `remove`/`patch` exists
(and is unambiguous); a crate you `add` has a unique `weight_kg`; troop groups and array settings
exist. Unknown names get a *"did you mean …?"* suggestion.

## Loading in the Mission Editor

The generated `CTLD_userConfig.lua` loads exactly like the hand-written template:

1. **MISSION START → DO SCRIPT FILE** → `CTLD_userConfig.lua`
2. **MISSION START → DO SCRIPT FILE** → `CTLD.lua`

The user-config trigger must come **before** the CTLD trigger.

### Automatic injection (optional)

Instead of adding the trigger by hand, `ctld-tools inject` inserts it for you — a MISSION START
trigger placed **first**, so it runs before your CTLD trigger. It is **idempotent** (re-injecting
updates the same trigger instead of duplicating it):

```
ctld-tools inject --miz MyMission.miz --userconfig CTLD_userConfig.lua --out MyMission.injected.miz
```

!!! warning "Back up your mission and test it in DCS"
    Injection edits the mission triggers directly. **Keep a backup** (use `--out` to write a copy),
    and open the result in DCS once to confirm it loads and that CTLD picks up your config. The tool
    validates the file structure, but only DCS confirms the mission runs.

!!! note "Prefer to hand-write Lua?"
    You still can — see [Configuration](configuration.md). `ctld-tools` is the recommended path for
    most missions, but the Lua template stays fully supported for power users.
