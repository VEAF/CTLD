# JTAC

A JTAC (Joint Terminal Attack Controller) is a ground or airborne unit that finds enemy
targets and lases them for you and your flight — putting a laser spot and an IR pointer on
whatever it sees. Once deployed, a CTLD JTAC works on its own: it scans for the nearest enemy
in line of sight, fires the laser, and re-acquires when a target dies. Your job as a pilot is
to get one on the ground (or in the air) where it can see the fight, then use its F10 menu to
manage the lase and call for smoke or a 9-line.

Everything below lives under **F10 → CTLD → JTAC**. Which entries you see depends on your
aircraft (it must be a transport), your position (landed in a logistics zone), and which JTACs
are currently active for your coalition.

## Request JTAC Equipment

**Utility:** Spawns a JTAC vehicle or drone directly at the logistics zone you are parked in,
ready for you to load and carry. Use this when you want to ferry a JTAC to the front line
yourself.

**How it works:** Land inside an active logistics zone, then open the submenu and pick a JTAC
type. CTLD spawns that unit next to the zone; from there you load and transport it like any
other cargo. It starts lasing automatically once it is unloaded and settled at its position.

**Activation:** F10 → CTLD → JTAC → Request JTAC Equipment → [type]

The **Request JTAC Equipment** submenu is dynamic. It only lists types while you are landed
inside an active logistics zone; if you are airborne it shows *Land near logistics to request
equipment*, and if you are on the ground but out of range it shows *No logistics in range*. The
list refreshes on its own when you land, take off, or deploy a FOB.

The submenu appears only when JTAC drops are enabled (`JTAC_dropEnabled`), your aircraft is a
transport, and at least one JTAC type is offered to your coalition. The available types come
straight from the mission's crate catalogue — see
[JTAC crates](../mission-maker/crates-catalogue.md) for how a mission maker configures them.

## Deploy a JTAC from a crate

**Utility:** Delivers a JTAC by carrying its crate to where you want it, then unpacking. Use
this when you would rather sling or carry a crate than load the finished unit.

**How it works:** Request the JTAC crate from a logistics zone the same way you request any
crate, fly it to the drop point, set it down, and unpack it. The JTAC unit appears at the
unpack location and begins scanning for targets immediately.

**Activation:**

1. F10 → CTLD → Request Equipment → [logistics zone] → [category] → [JTAC crate]
2. Fly the crate to the target area and drop it (F10 → CTLD → Crate Commands → Drop Crate(s)).
3. F10 → CTLD → Crate Commands → Unpack Crate

JTAC crates are offered here only when `JTAC_dropEnabled` is set. See
[Crates](crates.md) for the full crate workflow and
[JTAC crates](../mission-maker/crates-catalogue.md) for the crate and type definitions.

## Operate a deployed JTAC

**Utility:** Manage each active JTAC — check its status, toggle its laser, refine the spot, ask
for smoke on the target, or request a 9-line brief.

**How it works:** Every active JTAC of your coalition gets its own submenu named after its
group, plus a shared **JTAC Status** command that lists each JTAC, its state, its current
target, and its laser code. The per-JTAC entries are context-sensitive and only appear when the
matching feature is enabled in the mission config.

**Activation:**

- F10 → CTLD → JTAC → JTAC Status — list all active JTACs, targets and laser codes.
- F10 → CTLD → JTAC → [group name] → Lasing [deactivate] / Lasing [activate] — turn the laser
  off (standby) or back on. Shown when `JTAC_allowStandbyMode` is enabled.
- F10 → CTLD → JTAC → [group name] → Spot Corrections [activate] / Spot Corrections
  [deactivate] — toggle laser-spot corrections. Shown when `JTAC_laseSpotCorrections` is set.
- F10 → CTLD → JTAC → [group name] → Request Smoke on Target — mark the lased target with smoke
  for visual pickup. Shown when `JTAC_allowSmokeRequest` is enabled.
- F10 → CTLD → JTAC → [group name] → Request 9-Line — request the 9-line CAS brief. Shown when
  `JTAC_allow9Line` is enabled.

A deployed JTAC auto-lases without any action from you: it locks the nearest enemy within its
line of sight and scan range, fires the laser, and re-acquires the next target when the current
one is destroyed. The label on the *Lasing* entry flips to reflect the current state, so you can
see at a glance whether a JTAC is actively lasing or in standby.
