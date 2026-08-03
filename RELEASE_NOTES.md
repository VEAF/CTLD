# CTLD 2.0.0-rc5 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/).

---

**If you installed CTLD with rc4, re-install with this version.** The engine is unchanged; the
installer was not. rc4 wrote the beacon sound files into your mission without registering them, and
the Mission Editor deletes files it sees as unreferenced the next time it saves — so a mission
installed with rc4 can lose its beacon sounds, and the beacons then go quiet with nothing to explain
it. Re-installing over rc4's work fixes it in place.

## What's fixed

- **The beacon sounds stay in the mission.** They now get a registration entry and a mission-start
  trigger that references them, which is what tells the Mission Editor they belong to the mission.
  That trigger plays both sounds at mission start; it runs before anyone is in a cockpit, so nobody
  hears it.

- **You can open a mission from the tool.** Reading your configuration back out of a `.miz` shipped
  in rc4, but the file picker only listed `.yaml` files and the button read "Open a config file…", so
  there was no way in unless you knew to switch the picker to "All files". The button is now
  **Open config or mission…** and missions are listed by default.

## Nothing to change in your configuration

No setting added, renamed or removed, and the engine is rc4's apart from its version stamp. If you
install by hand nothing changes for you either — but the same Mission Editor behaviour applies: a
sound no trigger references can be dropped when the mission is saved.

## Contributors

**FullGas** (lead developer), **Zip** (technical support) — VEAF.

Both fixes in this release come from Zip using rc4 on a real mission, and the diagnosis of the sound
problem is his.
