# CTLD 2.0.0-rc7 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click
**More info** → **Run anyway**. If the file came through a browser you may also need right-click →
**Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/2.0.0-rc7/mission-maker/).

---

**Already installed a mission with rc6?** Re-install it with this version. The repaired translations
and the in-mission fixes travel inside the engine the tool writes into your `.miz` — a mission
installed with rc6 keeps the old one until you install again.

The biggest release candidate since rc1: the translated menus are whole again, and seven in-mission
bugs are fixed — two of which silently destroyed things you had deployed.

## What's fixed in the mission

- **Troops extracted from the field are counted for real.** Drop ten, lose three, and you now
  re-embark seven — not the ten you originally dropped. The F10 menu also shows each group's current
  headcount (`Extract: Bravo (7 troops)`), so you can pick which group to pull out knowing what it
  will cost you in capacity. A group whose last real trooper is dead is no longer offered at all.

- **Two troop groups from the same template no longer delete each other.** Parachuting a second
  group loaded from the same template destroyed the first one the instant it landed — DCS replaces
  any group spawned under a name already in use, and both were landing under the raw template name.
  Silent, instant, and nothing on screen explained it.

- **AA system parts no longer spawn on top of each other.** Systems with more than two identical
  parts spread their units across the whole circle instead of their own arc segment — the S-300 TEL D
  landed inside the Big Bird SR.

- **The unpack menu disappears once the system is built.** It stayed visible for nearby pilots after
  assembly, offering to unpack crates that no longer existed.

- **The F10 menu no longer doubles on multi-crew aircraft.** A copilot joining a CH-47 after the
  pilot got a second copy of the whole CTLD menu. And when one crew member leaves a shared group, the
  remaining crew keep their menu instead of losing it.

- **Death events actually fire.** `onUnitDead` was registered in a way that never matched a real dead
  unit in a live mission, which also disabled JTAC de-registration on death. Both work now.

## What's fixed in the menus

- **The translated menus are whole again.** 56 labels — every HAWK, BUK, KUB, NASAMS, Patriot and
  S-300 component, several crate, smoke and vehicle entries, and the category headers (Infantry, Air
  Defense, Ground Vehicles, Helicopters, Aircraft, Ships, FARP / FOB) — had been dropped from the
  dictionaries by a tooling bug and were falling back to English. If you fly in French, Spanish or
  Korean, those menus read in your language again. English was unaffected throughout.

- **Korean and Spanish are complete.** The entries those two languages had never received — 70 per
  language, plus 29 more surfaced by the fix above — have been translated. Reported by **FullGas**,
  who also built the fix and the CI guard that stops it happening again: from now on a pull request
  adding a menu entry cannot merge while any of the four dictionaries is missing it.

## What's new for Mission Makers

- **Your own beacon sound.** The two sound settings are no longer free-text boxes naming a file the
  tool never installed: each gets a **Default / Custom** picker, and the `.ogg` you choose is written
  into the `.miz` with its resource key and preload trigger, exactly like the bundled ones. The file
  is checked for a real OGG signature when you pick it — a renamed `.mp3` plays nothing in DCS. A
  custom sound travels inside the mission, so reopening the `.miz` on another machine recovers it
  even if the original file is gone.

- **"All crates" for the FOB, and crate counts everywhere.** Request Equipment was missing the
  one-click "FOB Crate (x3) - All crates" entry every other multi-crate item had. Every entry now
  also shows how many crates it needs — `(x3)`, `(x1)` — so you can plan a sortie without opening the
  documentation.

## Nothing to change in your configuration

No setting was added, renamed or removed. A beacon sound picked through the tool is recorded
alongside the existing sound settings, so configurations written with earlier release candidates load
unchanged.
