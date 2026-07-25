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

(From a terminal you can also run `ctld-tools serve` to open it. The same file is a command-line tool
too — used by the CTLD build — but as a Mission Maker you won't need that.)

## Editing your configuration

The app shows CTLD's **complete configuration**, split into two screens:

- **Parameters** — *how CTLD behaves*: the settings, grouped into functional **families** (General,
  Crates, Troops, JTAC, FOB / FARP, AA system, Parachute, …), each split into **Standard** (the
  common ones) and **Advanced**. Every field has the right editor — a checkbox for on/off, a dropdown
  for fixed choices, a number or text box otherwise — with a short description as help.
- **Data** — *what CTLD operates on*: the catalogue — **crates**, **troop groups**, **aircraft
  capabilities** (pick an aircraft type from the DCS list), **zones**, transport pilot names, vehicle
  weights. Add, edit and remove entries through forms.

Start from **Load defaults** (CTLD's factory configuration) or **Open…** an existing config you saved
earlier (a native file dialog).

**Live validation** runs as you edit: unknown DCS unit types, duplicate crate weights and other
problems appear immediately, so you never ship a broken config.

## Saving and using it

- **Save…** writes your configuration to a file (a native save dialog) so you can reopen it later.
- **Inject to .miz…** picks a mission and inserts your configuration into it as a MISSION START
  trigger, ready to play. Injection is **refused while any validation error remains**.

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
the tool shows a **popup** listing how the current defaults differ (settings added, settings removed,
values that changed) so you can review before re-injecting — never a silent merge.

## Loading it by hand (alternative to inject)

If you would rather add the trigger yourself, load the configuration exactly like the hand-written
template:

1. **MISSION START → DO SCRIPT FILE** → your `CTLD_userConfig.lua`
2. **MISSION START → DO SCRIPT FILE** → `CTLD.lua`

The configuration trigger must come **before** the CTLD trigger. See
[Configuration](configuration.md) for the hand-written Lua path — fully supported for power users;
`ctld-tools` is the recommended path for most missions.
