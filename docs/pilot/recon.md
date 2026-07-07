# Recon

Recon turns your aircraft into a sensor: fly over hostile ground, run a scan, and every
enemy unit your line-of-sight can reach is drawn on the F10 map — shaped by category,
coloured by side. It is a **reveal-and-mark** tool for enemy contacts only. Friendly assets
(FOBs you own, logistic zones, radio [beacons](beacons.md)) are never shown here; they live
in their own menus.

## What Recon lets you do

You pick which categories of contact you care about (infantry, vehicles, air defense,
aircraft, helicopters, ships, enemy FARP/FOB), start a scan, and CTLD paints icons on the
F10 map for everything currently in your line of sight. While the scan is running it
auto-refreshes on a timer, so contacts appear, move and drop off the map as the picture
changes. The marks are yours alone — they are drawn for your coalition only.

## How it works

- **Line of sight.** A scan only reveals enemy units your aircraft can actually see. Terrain,
  the horizon and the scan radius all limit what comes back — fly higher or closer to see
  more.
- **Minimum altitude.** You must be above the configured minimum AGL altitude to scan. Too
  low and CTLD refuses with a message.
- **Auto-refresh.** Starting a scan also arms an auto-refresh timer. On each tick CTLD
  re-scans and updates the map: new contacts get an icon, contacts that moved are re-drawn at
  their new position, contacts that died or dropped out of sight are removed.
- **Layers drive the picture.** Only categories whose layer is active produce marks. You can
  toggle layers before or during a scan; toggling while a scan is live re-scans immediately,
  so switching a layer off wipes its marks at once.

## Activation

The Recon menu lives at **F10 → CTLD → RECON**. If you do not see it, recon is not enabled
for the mission — that is a mission-maker setting (see the
[Mission Maker guide](../mission-maker/index.md)).

### RECON [Start] / RECON [Stop]

**Utility:** A single toggle. **RECON [Start]** runs an immediate line-of-sight scan around
your aircraft, marks every detected enemy in your active layers, and arms auto-refresh. Once
running, the same entry becomes **RECON [Stop]**, which halts the refresh and clears all your
recon marks from the map.

**Requirements:** you must be at or above the minimum AGL altitude. You can start a scan with
no layers active — CTLD tells you to activate layers to see targets — then switch layers on
without restarting.

**Activation:** F10 → CTLD → RECON → **RECON [Start]** (then **RECON [Stop]** to end).

### Layer toggles

**Utility:** Show or hide one category of contact. Each layer has its own entry whose label
tells you what a click will do — `[activate]` when the layer is off, `[deactivate]` when it
is on. A trailing **(X)** means recon is currently idle (no active scan), so the toggle only
records your choice for the next start. Turning a layer off during a live scan removes its
marks immediately.

**Activation:** F10 → CTLD → RECON → *[layer name]* `[activate]` / `[deactivate]`

Available layers, in menu order:

- Infantry
- Air Defense (AA)
- Ground Vehicles
- Helicopters
- Aircraft
- Ships
- FARP / FOB

## Layers and icons

Each layer draws a distinct shape so you can read the category at a glance, while the icon
**colour follows the detected unit's side** — red for RED, blue for BLUE, grey for neutral.

| Layer | Icon |
|---|---|
| Infantry | Circle with a cross |
| Air Defense (AA) | Filled circle with an apex (^) |
| Ground Vehicles | Rectangle with a diagonal |
| Helicopters | Circle with two vertical bars (H) |
| Aircraft | Cross with a centre dot |
| Ships | Elongated rectangle with a bow arrow |
| FARP / FOB | T inside a square |

!!! note "Icons scale with map zoom"
    Recon icons are drawn in world space (metres on the ground), so they grow and shrink as
    you zoom the F10 map — this is a DCS limitation, there is no screen-fixed alternative. The
    mission-maker can set an overall icon size multiplier.

## Notes

- Recon marks are per-player and visible to your coalition only.
- Scan radius, minimum altitude, refresh interval and icon size are all mission-maker
  configuration — see the [Mission Maker guide](../mission-maker/index.md).
