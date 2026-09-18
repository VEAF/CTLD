# CTLD 2.0.0-rc11 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click
**More info** → **Run anyway**. If the file came through a browser you may also need right-click →
**Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/2.0.0-rc11/mission-maker/).

---

Changing slot no longer breaks CTLD, and a fighter pilot finally has a place in it.

## Changing slot or coalition raised an error and left a ghost F10 menu

Reported from a live multiplayer session. Leaving a slot — switching aircraft, changing side,
going back to spectators — threw a script error, and the CTLD menu of the pilot who had just
left stayed on the group. Multi-crew aircraft were the worst hit: the "is anyone still in this
group?" count kept counting pilots who had long since gone, so the menu was never removed.

**Cause**: DCS releases the aircraft about a millisecond before telling the script the player
left, so the object CTLD received still existed but answered nothing. CTLD aborted three lines
into the handler and never got to the cleanup.

**Fix**: the seven places that read a name straight off a departing object are now protected, and
the 30-second player scan — which until now could only ever *add* players — now also forgets those
whose slot no longer exists, has died, or went back to AI. The event stays the fast path; the scan
catches whatever it misses.

## A fighter pilot now gets the CTLD functions that concern him

Recon works from any aircraft — but if your mission sets `addPlayerAircraftByType = false`, a pilot
who was not in `transportPilotNames` had **no CTLD menu at all**, and therefore no recon either. A
setting meant to reserve the *transport* menus for a named list was cutting off every function that
has nothing to do with transport.

From this release, such a pilot gets a CTLD menu with the functions that apply to him:

- **Recon** — mark and report what you see.
- **Smoke** — drops at your own position; marking a spot from a fighter is exactly what it is for.
- **List Beacons** — a beacon's frequency is navigation information. *Drop Beacon* and *Remove
  Closest Beacon* stay transport-only.
- **JTAC Status**, **List active FOBs** and mine clearing were already open to everyone and are
  unchanged.
- **Check Cargo** is hidden from him — it could only ever report an empty hold.

The transport menus themselves are untouched: a pilot off the list does not get them back through
his aircraft type, whatever he flies.

## A cancelled menu rebuild could land on the next pilot in the slot

DCS reuses the same internal group id for the next occupant of a slot. A menu rebuild that had been
scheduled for a departing pilot and then cancelled could still fire a fraction of a second later —
on a **different** player, whose menu was wiped and rebuilt for no reason. Fixed; the cancellation
now covers both kinds of pending rebuild.

Worth noting: this only became reachable *because* of the fix above — before it, the handler never
got that far.

## What this means for your configuration

No setting was renamed, removed, or given a new default. One behaviour changed, though:

**With `addPlayerAircraftByType = false`, a pilot absent from `transportPilotNames` used to be
invisible to CTLD entirely.** He is now tracked and gets a menu — with the non-transport functions
only. If your mission relied on that list to keep CTLD off certain pilots' F10 menu altogether,
that is no longer what it does: it decides who gets the *transport* functions.
