# Validating your config during development

CTLD does **not** check DCS type names at mission start any more — it no longer spawns hidden probe
objects (that wasted resources and fired spurious birth/death events your mission logic could see).
Instead, a typo or a missing mod surfaces at **development time** via an optional companion script.

## The asset-check companion

`CTLD_asset_check.lua` is an optional dev-time tool (download it from the release assets). Loaded
after CTLD, it looks at everything your mission configures — `spawnableCrates`, AA system parts,
`loadableGroups`, and scene objects — and prints a message:

- **OK** — every configured DCS type is a known stock type or a declared mod type; or
- **WARN** — a list of unknown types (a likely typo, or a mod you have not declared).

It is a pure lookup: **no objects are spawned, no events are fired.**

### How to use it

1. Download `CTLD_asset_check.lua` from the [CTLD release](https://github.com/VEAF/CTLD/releases).
2. In the Mission Editor, add a `DO SCRIPT FILE` trigger at **MISSION START**, **after** the trigger
   that loads `CTLD.lua`.
3. Run the mission once and read the on-screen message (and `CTLD.log`). Fix any reported typo.
4. **Remove the companion trigger for production** — it is a development aid only.

### Declaring mod types

If your config legitimately uses a mod's DCS type, tell CTLD so the companion does not flag it —
list the exact type name(s) in the `modTypes` setting (in `ctld-tools`, it is an editable list of DCS
type names):

```yaml
advanced:
  modTypes:
  - Your_Mod_Type
  - Another_Mod_Type
```

Every *other* type is still checked, so a real typo is still caught. (Scenes declare their own mod
types in `modTypes` on the scene model — see [Scenes & FOB](scenes-fob.md).)

!!! note "Your responsibility"
    The companion confirms a type *name* is known; it cannot confirm that every client actually has
    the mod installed. Ensuring required mods are present on all clients remains up to you.
