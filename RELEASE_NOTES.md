# CTLD 2.0.0-rc8 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click
**More info** → **Run anyway**. If the file came through a browser you may also need right-click →
**Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/2.0.0-rc8/mission-maker/).

---

**Already installed a mission with rc7?** Re-install it with this version. The fixes below travel
inside the engine the tool writes into your `.miz` — a mission installed with rc7 keeps the old one
until you install again.

This release candidate closes two troop-pickup gaps reported by the community and a beacon frequency
gap, and hardens the engine against a bad setup — a missing initialization step now tells you exactly
what to fix instead of failing on an unrelated error.

## What's fixed in the mission

- **Troops can now actually be picked up at a built FOB.** The "Allow troop pickup at built FOBs"
  setting has existed since the rewrite, on by default — but nothing in the F10 "Load Troops" menu
  ever consulted it, so a FOB never offered troop pickup no matter what it was set to. It now works:
  a deployed FOB registers a real pickup zone, using the FOB's own radius, exactly as it does for
  logistics.

- **Troops can now be picked up at a built FARP.** FARPs had no troop-pickup capability at all —
  only FOBs did. Any of the three built-in FARP scenes (default, Alpha, Countryside) now registers a
  pickup zone the moment it finishes building, and removes it the moment DCS destroys the FARP (or
  when a Countryside FARP is packed back into crates).

- **A quarter of the FM beacon band was unreachable.** The FM pool skipped four ranges —
  36.0–39.9, 46.0–49.9, 56.0–59.9 and 66.0–69.9 MHz — including ordinary frequencies like 38.00 MHz.
  Any beacon or briefing asking for one of those quietly failed or landed elsewhere. All 460 steps
  from 30.0 to 75.9 MHz are reachable now.

## Under the hood: a clearer failure when CTLD isn't started correctly

If a mission's script setup skips `ctld.initialize()` — an integration mistake, not something a
Mission Maker using the tool can trigger — CTLD used to crash on an unrelated arithmetic error deep
inside the engine, giving no hint that initialization was the actual problem. It now fails
immediately with a message that says exactly what's missing. Reported by **Zip**, who also reported
the FM beacon gap above — thank you for both.

## New scripted capabilities (for mission scripters)

- A beacon placed through script (`createAtPoint`) can now be **requested on a specific frequency**
  instead of always drawing at random — useful when a frequency is already briefed to pilots on a
  kneeboard.
- A troop pickup zone can now be added through script on **any named object** — a unit, a static, a
  group, or an airbase — not only through a Mission Editor trigger zone.

## Nothing to change in your configuration

No existing setting was renamed or removed, and every default keeps today's behavior. FARP troop
pickup ships **on by default** (`troopPickupAtFARP`, 150 m radius) — turn it off in the tool if you
don't want it.

---

Thanks to **Tripack** (VEAF) for testing and feedback on this release candidate.
