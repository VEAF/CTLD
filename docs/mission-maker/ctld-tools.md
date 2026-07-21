# Configuring CTLD with `ctld-tools`

`ctld-tools` lets you configure CTLD **without writing Lua**. You describe your changes — referring
to crates and troop groups **by name** — and the tool validates them and generates the
`CTLD_userConfig.lua` your mission loads. There are two ways to use it: an **interactive editor**
(the `tui` command, recommended) or a **command-line workflow** over a `user-config.yaml`.

You never look up crate weights, and mistakes are caught at your desk (with suggestions) instead of
in DCS.

## Get the tool

Download **`ctld-tools.exe`** from the [GitHub Releases](https://github.com/VEAF/CTLD/releases) page
— it is attached to each release. **No Python and no CTLD `src/` folder needed**: the reference
catalogue (crates, troop groups, DCS unit types) is **embedded in the tool**. (Developers can also
run it from source with `poetry`; see the developer docs.)

Put it in your mission folder. **Double-click it** to open the interactive editor directly, or run it
from a terminal.

!!! warning "Unblock the .exe first (Windows)"
    Windows may block `.exe` files downloaded from the internet. If the tool doesn't start,
    right-click `ctld-tools.exe` → **Properties** → **General** tab → check **Unblock** at the bottom
    → **OK**.

## The interactive editor (`ctld-tools tui`) — recommended

**Double-clicking `ctld-tools.exe`** opens this editor directly (no arguments needed). From a
terminal:

```
ctld-tools tui                           # opens user-config.yaml here if it exists, else starts empty
ctld-tools tui --yaml path/to/other.yaml # or point at another file
```

A full-screen console — no YAML to write, no commands to chain:

- **Structured editor**: your config is laid out by section (**settings**, **crates**, **troops**,
  **arrays**), with live validation on the right.
- **Add / Remove / Patch**: three buttons drive everything. Pick the action, then the kind of thing
  (crate, troop group, setting, array), then fill a guided form. **Patch** works on both crates and
  troop groups (change one field, keep the rest).
- **Filter-as-you-type pickers**: choose a crate's `unit` from the ~1100 DCS types, or a crate /
  troop group / **setting** by name, by typing a few letters instead of scrolling. When you pick a
  setting, its **default value is shown and pre-filled**, so you edit from the real default. For a
  **true/false** setting, or one with a **fixed set of values** (e.g. `JTAC_lock`: all / vehicle /
  troop), you **pick the value from a list** rather than typing it. Each setting shows a short
  **description** (in your language), and you can **search by it** — type a word from the description,
  not just the setting name.
- **Unsaved changes**: quitting with unsaved edits asks for confirmation and reminds you when you
  last saved.
- **Live validation**: every edit is checked instantly against the embedded catalogue, with inline
  errors and *"did you mean …?"* suggestions.
- **Edit a line**: select an entry in the tree and press **e** to reopen its form pre-filled — fix a
  mistake (e.g. a crate added without a name) instead of deleting and re-entering everything.
- **Delete a line**: select an entry in the tree and press **Delete** to remove it (with a
  confirmation) — handy to drop something you just added.
- **Undo / redo**: **Ctrl+Z** / **Ctrl+Y** step through your edits.
- **All in one place**: **Save** (always the same `user-config.yaml`, no prompt), **Generate** the
  `CTLD_userConfig.lua` next to it (its name is fixed — CTLD requires it), or **Inject** it straight
  into a `.miz` (pick the mission in a **file browser** that lists only `.miz` files) — from the same
  screen. Generation is refused while any error remains, so you never ship a broken config.
- **Language**: the interface follows your **system language** (English or French). Force it with
  `ctld-tools tui --lang en` / `--lang fr` (or the `CTLD_LANG` environment variable).

## The command-line workflow

If you prefer scripts or a headless pipeline, the same operations are available as commands:

```
ctld-tools gen-user --scaffold --out user-config.yaml   # 1. commented starter
#   ... edit user-config.yaml ...                        # 2. describe your changes
ctld-tools validate  --yaml user-config.yaml             # 3. check it
ctld-tools gen-user  --yaml user-config.yaml --out CTLD_userConfig.lua  # 4. generate
#   ... load CTLD_userConfig.lua before CTLD.lua in the Mission Editor ...   # 5. use it
```

The embedded catalogue is used by default. Developers working in the repo can add `--src path/to/src`
to resolve names against a live CTLD `src/` folder instead.

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

### `troops` — add / remove / patch

```yaml
troops:
  add:
    - name: Recon Team
      inf: 3
      jtac: 1
  remove:
    - 5x - Mortar Squad
  patch:
    - name: Standard Group   # change one field, keep the rest
      inf: 8
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
| `tui [--yaml user-config.yaml]` | Launch the interactive editor (recommended). |
| `gen-user --scaffold --out user-config.yaml` | Write a commented starter file. |
| `validate --yaml user-config.yaml` | Check the file; prints findings, exits non-zero on error. |
| `gen-user --yaml user-config.yaml --out CTLD_userConfig.lua` | Compile to Lua (runs `validate` first, refuses on error). |
| `inject --miz mission.miz --userconfig CTLD_userConfig.lua [--out out.miz]` | Inject the generated Lua into a `.miz` as a MISSION START trigger (optional — see below). |

All commands use the embedded reference by default; add `--src path/to/src` (dev only) to resolve
against a live CTLD `src/` folder.

**What validation checks:** every `unit` is a real DCS type; a crate you `remove`/`patch` exists
(and is unambiguous); a crate you `add` — or re-weight via `patch` — has a unique `weight_kg`; troop groups and array settings
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
