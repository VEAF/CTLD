# Configuring CTLD with `ctld-tools`

`ctld-tools` lets you configure CTLD **without writing Lua**. It is a small **local web app**: you
double-click it, it opens in your browser, and you edit CTLD's complete configuration through forms —
every setting and every catalogue entry (crates, troop groups, aircraft, zones). Your changes are
validated at your desk, with clear errors, and injected straight into your mission.

You never look up crate weights or edit Lua by hand, and mistakes are caught before DCS.

## Get the tool

Download **`ctld-tools.exe`** from the [GitHub Releases](https://github.com/VEAF/CTLD/releases) page
— it is attached to each release. **No Python, no Node, no CTLD `src/` folder needed**: everything
(the default configuration, the DCS unit-type list, the web interface) is embedded in the single
file.

!!! warning "Unblock the .exe first (Windows)"
    Windows may block `.exe` files downloaded from the internet. If the tool doesn't start,
    right-click `ctld-tools.exe` → **Properties** → **General** tab → check **Unblock** at the bottom
    → **OK**.

## Open it

**Double-click `ctld-tools.exe`.** A small console window opens — that is the local server; leave it
open, closing it quits the tool — and your **browser** opens on the app. No command to type.

The app **starts on CTLD's default configuration**, so there is nothing to load before you begin.

(From a terminal you can also run `ctld-tools serve` to open it. The same file is a command-line tool
too — used by the CTLD build — but as a Mission Maker you won't need that.)

## Finding your way around

A strip across the top shows the three steps: **Load → Adjust → Inject into your mission**, with the
current one highlighted. The header always tells you which configuration is open, how many settings
you have changed, and whether your work is saved.

!!! tip "English or French"
    The interface follows your Windows language, and a **Language** picker in the header switches
    between English and French at any time — including the settings' own help texts. Your choice is
    remembered.

The left column lists CTLD's **functional families** — General, Aircraft, Crates, Troops, Zones,
Boarding, FOB / FARP, JTAC, Recon, AA system, Beacons, Smoke, Mines, Parachute, Soldier weights. Pick
a family and you get **everything** about that part of CTLD in one place: its settings *and* its
catalogue entries, with a line under the title telling you what the family covers. Crates, for
instance, holds the crate settings *and* the list of crates you can spawn.

Within a family, settings are split into **Common settings** and an **Advanced settings** section
that stays folded until you need it (it opens by itself if it contains something you have changed).

**Don't know where a setting lives?** Use the **search box** — it looks through every family at once,
by name or by description, and tells you which family each result belongs to.

## Editing your configuration

Each setting shows a **plain-language name**, its unit where CTLD documents one (metres, kilograms,
seconds), a short description, and the right editor for its type — a switch for on/off, a dropdown
for fixed choices, a number or text box otherwise. The **raw config name** (the one used in the CTLD
documentation and on the forums) is shown next to it in small type.

Catalogue entries — **crates**, **troop groups**, **aircraft capabilities** (pick an aircraft type
from the DCS list), **zones**, transport pilot names, vehicle weights — are edited as tables, at the
bottom of the family they belong to.

### Undoing a change

Any setting you change is marked **changed**, and the family gets a counter in the left column, so
you can always see what you have touched. A **reset arrow** appears next to a changed setting and
puts CTLD's default value back.

Prefer to start over? **Start from CTLD defaults**. To pick up an earlier config, use
**Open a config file…** (a native file dialog). Either one warns you first if you have unsaved
changes.

### Validation

**Live validation** runs as you edit. A lamp in the header reads **VALID** or **CHECK**, and a panel
above the settings lists any problem in plain words — unknown DCS unit types, duplicate crate
weights, and so on. Click a problem and the app jumps straight to the setting it concerns.

## Saving and using it

- **Save as…** writes your configuration to a file (a native save dialog) so you can reopen it later.
- **Inject into mission…** picks a mission and inserts your configuration into it as a MISSION START
  trigger, ready to play. The button stays **disabled while any validation error remains**.

Injection is **idempotent** — re-injecting updates the same trigger instead of duplicating it — and
places the trigger **first**, so it runs before CTLD.

!!! warning "Back up your mission and test it in DCS"
    Injection edits the mission directly. Keep a backup, and open the result in DCS once to confirm
    it loads and CTLD picks up your config. The tool validates the structure, but only DCS confirms
    the mission runs.

## The complete-snapshot model

Your configuration is a **complete snapshot**, not a list of changes: it **fully replaces** CTLD's
defaults. Anything you remove is absent at runtime — not silently defaulted. That is why you always
**start from the defaults** (or an existing config): so nothing is lost by accident.

### When CTLD is updated

CTLD stamps a **version** on its configuration. When you open a config authored for an older CTLD,
the tool tells you so and summarises how the current defaults differ — settings added, settings no
longer used, default values that changed — each expandable if you want the detail. **Nothing is
merged**: your settings are left exactly as they were, and you decide what to update before
re-injecting.

## Loading it by hand (alternative to inject)

If you would rather add the trigger yourself, load the configuration exactly like the hand-written
template:

1. **MISSION START → DO SCRIPT FILE** → your `CTLD_userConfig.lua`
2. **MISSION START → DO SCRIPT FILE** → `CTLD.lua`

The configuration trigger must come **before** the CTLD trigger. See
[Configuration](configuration.md) for the hand-written Lua path — fully supported for power users;
`ctld-tools` is the recommended path for most missions.
