# CTLD 2.0.0-rc10 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click
**More info** → **Run anyway**. If the file came through a browser you may also need right-click →
**Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/2.0.0-rc10/mission-maker/).

---

Two live-reported F10 menu bugs, both fixed in this release.

## A transport could ask for one thing on F10 and get another

Reported live: a transport parked on a pickup zone requested "Load Standard Group" from
**Troop Commands → Embark / Extract Troops**, and instead a smoke grenade went off at the
aircraft's own position.

**Cause**: CTLD's F10 menu rebuilds itself as a whole every time something changes — a design
choice that keeps the menu always consistent. A background check (for example, noticing your
transport has parked at a supply point) could rebuild the menu at the exact moment you were
navigating it, so your next click landed on whatever now occupied that spot instead of the item
you were looking at. This is a DCS-side limitation — nothing in a mission can currently tell a
script whether a player's radio menu is open — so it could not be detected directly.

**Fix**: any menu rebuild that isn't the direct result of your own click now clears the menu first,
then rebuilds it a few seconds later. A click landing in that short gap now does **nothing**
instead of firing the wrong command — clicks tied to your own actions (loading, unloading, taking
off, landing) are unaffected and stay instant. In the rare case where this applies, you may see the
CTLD F10 menu briefly disappear before reappearing — expected, and far preferable to the old
behaviour.

## A HAWK or Patriot crate could get stuck in "Unpack Crate" forever

After successfully assembling a HAWK or Patriot air-defence system, the F10 **Unpack Crate** menu
could keep listing one of its crates (HAWK PCP/CWAR, or the Patriot AMG) as still available — even
though the system was already fully built. Selecting it did nothing but repeat a "Cannot build"
message.

**Cause**: those specific crates are optional — the system assembles without them — but if one was
picked up and dropped nearby anyway, it was never cleared away once the system used it.

**Fix**: any such crate found near a successful assembly is now consumed along with the rest, so it
no longer lingers in the menu afterward.

## Nothing to change in your configuration

No setting was renamed, removed, or given a new default in this release.
