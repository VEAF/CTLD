# CTLD 2.0.0-rc12 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click
**More info** → **Run anyway**. If the file came through a browser you may also need right-click →
**Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/2.0.0-rc12/mission-maker/).

---

A fix-and-polish release: two real gameplay bugs closed, extraction zones gain a naming-convention
shortcut, `ctld-tools` now reads your mission's zones back instead of asking you to retype them,
and its numeric fields are hardened against invalid input.

## A reoccupied slot no longer inherits the previous pilot's flight state

Reported from a live session. DCS reuses unit names across a mission — if a slot's previous
occupant had taken off before leaving, the next pilot to take that same slot on the ground got an
unsolicited F10 menu rebuild about a second into his seat, for a state transition that never
happened to him.

**Cause**: CTLD's flight-state poller (it detects takeoff/landing faster than DCS's own events,
which lag 3–5 seconds for helicopters) keeps a small per-unit record of the last confirmed state.
Nothing cleared it when a pilot left, so a new occupant of the same unit name started from the
previous pilot's history instead of his own.

**Fix**: that record is now cleared in the same place CTLD already forgets a departed pilot. A
pilot with the F10 menu open in his first second in a reused slot no longer risks clicking an
entry that gets rebuilt out from under him.

## Extraction zones can now be created by naming a trigger zone

`EXZ_<name>_<flag>_<smoke>` in the Mission Editor now works exactly like `TRZ_`/`LGZ_`/`WPZ_`
already do — no scripted trigger needed to set one up. `<flag>` (a DCS flag to increment on
extraction) and `<smoke>` (a smoke colour) each accept `nil` to mean "none".

The existing scripted `ctld.createExtractZone(...)` call still works unchanged — a
naming-convention zone and a scripted one behave identically once created, so you can mix both in
the same mission.

## `ctld-tools` now reads your mission's AI-zone names for you

Every `dcsZoneName` field in the tool now offers an autocomplete list of your mission's real
trigger-zone names — a typo there used to surface only when DCS refused to start the mission.

For AI transport zones specifically: if you already name yours something like
`AIZ_depot_B_P_V`, `ctld-tools` recognises the pattern
(`AIZ_<name>_<coalition>_<P|D>_<cargoType-or-aiDropMode>`) when you scan your mission, and
pre-fills a new entry with those four fields already set — no retyping facts your zone name
already states. Keep the pattern complete if you want the pre-fill; CTLD itself never reads
meaning from the name, so an incomplete or non-matching one still works identically in DCS, it
just falls back to a blank entry from the manual **+ AI zone** button instead. Renaming a zone (or
removing it from the mission) is picked up the same way — a removal is always flagged for your
confirmation, never applied silently.

A pickup zone missing its stock table is now flagged directly in the editor instead of only
surfacing once the mission is running: a real warning (⚠) when troop pickup is disabled for want
of a `troopStock`, a calmer note (ⓘ) when a vehicle zone has no `vehicleStock` and is quietly
falling back to whatever is physically parked there.

## UH-1H no longer transports a whole vehicle — Mi-8MT does it properly instead

Requested for realism, not a bug fix: a Huey has no internal cargo bay for a ground vehicle, and
the documentation already said so — the config just disagreed with it. UH-1H's troop capacity is
raised from 8 to 10 to match the airframe's real capacity instead.

Mi-8MT's own whole-vehicle transport, on the other hand, was declared but never actually worked —
it had no weight rating or vehicle list, so it could never load one. It now carries a realistic
external sling-load rating (3000 kg) and the same loadable-vehicle list as the UH-1H.

### What this means for your mission

**If you relied on the UH-1H to sling-load or carry a whole vehicle, that no longer works — use
the Mi-8MT instead.** Crate-based cargo on the UH-1H (ammo, supplies, anything that isn't a whole
ground vehicle) is unaffected.

## `ctld-tools` no longer accepts a decimal where CTLD needs a whole number

Reported by a Mission Maker: typing `6.01` into a troop template's infantry count was silently
accepted by the editor. Every whole-number-only field — troop and launcher counts, quotas, laser
codes, onboard-capacity limits, crate requirements, AI-zone stock — now enforces a whole-number
step and rounds a typed decimal on the spot. Every genuinely continuous field (weights, distances,
durations) is untouched and still accepts a decimal exactly as before. A hand-edited config that
still carries a fractional value on one of these fields now gets a validation warning explaining
which one.

---

Thanks to **Tripack** (VEAF) for testing and feedback on this release candidate.
