# FEAT-AIRCRAFT-CAPABILITIES — five stock aircraft have no capability entry

**Status:** open.

Opened 2026-08-01, from the CTLD 2 ↔ VMCT integration audit — the fourth gap it found, and the last
one still open. The other three shipped in PR #79 (`FIX-SHIP-ZONE-ANCHOR-PARITY`) and PR #80
(`FEAT-VMCT-INTEGRATION`). Independent of VMCT on its own merits: these are **stock DCS modules**, so
any mission maker flying a Gazelle hits the same wall.

## The gap

`capabilitiesByType` holds nine entries: `C-130J-30`, `Mi-8MT`, `UH-1H`, `76MD`, `SK-60`, `Mi-24P`,
`UH-60L`, `CH-47Fbl1`, `Hercules`. Absent from the catalogue **and** from `src/` (zero occurrences):

`SA342L` · `SA342M` · `SA342Mistral` · `SA342Minigun` · `Yak-52`

VMCT has carried them in production for years, in the `ctld_initialize_replacement` block its CTLD 2
migration deletes. Their v1 declaration, and what CTLD 2 needs on top:

| type | v1 troop limit | v1 crates | v1 troops | source |
|---|---|---|---|---|
| `SA342L` / `SA342M` / `SA342Mistral` / `SA342Minigun` | 1 | ✗ | ✓ | explicit `unitActions` |
| `Yak-52` | 1 | ✗ | ✓ | explicit `unitActions` |

Everything else in a v2 record has no v1 answer and is filled by judgement, not translation:
`canParachuteDrop`, `canSlingload`, `canTransportWholeVehicle`, `convertNativeLoadToCTLD`,
`maxCratesOnboard`, `maxVehicleWeight`, `maxWholeVehiclesOnboard`, `useNativeDcsCargoSystem`,
`loadableVehiclesRED` / `loadableVehiclesBLUE`. A Gazelle and a Yak-52 realistically carry one
soldier and no crate, so most of these are `false` / `0` / absent.

## What an aircraft without an entry actually loses

Established by reading `CTLD_player.lua` and each `buildMenuSection`, because both the handoff and the
published documentation state it too strongly ("only aircraft listed here receive CTLD F10 menus" —
[configuration.md](../../docs/mission-maker/configuration.md)). `buildMenu` runs for **every** player;
each section gates itself on `playerObj.isTransport`, which is `caps ~= nil`.

| Still available with no entry | Gone |
|---|---|
| the `CTLD` root menu and **Check Cargo** | crates |
| **RECON**, entirely — no `isTransport` gate | troops |
| **JTAC**: the submenu and status; only *Request JTAC Equipment* is gated | beacons, smoke |

So the missing entry costs the transport half of CTLD, not the menu itself. That correction belongs in
the docs (ticket 02) as much as the entries belong in the catalogue.

## Decision: the Ka-50 gets no entry

v1 listed `Ka-50` and `Ka-50_3` with the *global* troop limit and both actions enabled — a side effect
of two missing table entries, not a decision: `ctld.getUnitActions` defaulted to
`{crates = true, troops = true}` and `ctld.getTransportLimit` to `ctld.numberOfTroops`
([CTLD.lua:11088-11102](../../migration/source/CTLD.lua#L11088)). A single-seat attack helicopter
slinging crates and carrying `numberOfTroops` soldiers is not behaviour to port.

The remaining argument for an entry with both transport modes off was menu access — and the reading
above kills it: recon and JTAC status are already there without one. **The only thing such an entry
would add is the ability to drop a radio beacon** (`CTLD_beacon.lua` returns early on
`not playerObj.isTransport`), on an aircraft that has nothing to unload in order to place it.

**Decided (David, 2026-08-01): no entry for `Ka-50` / `Ka-50_3`.** Six transport fields set to `false`
would advertise a transport that is not one; the catalogue should describe aircraft that carry things.
This is a **deliberate deviation from v1** and the PR must say so, because it looks like a regression
to anyone diffing against the monolith.

## Definition of done

- The five entries exist in `src/CTLD_config.yaml`, shaped like the existing ones, and a busted spec
  pins their presence and shape.
- Any type name they reference resolves against the datamine (`ctld-tools validate` is the blocking
  gate; `CTLDTypeCollector` makes a typo visible).
- The documentation no longer claims that an aircraft without an entry gets no menu, in EN and FR.
- The Ka-50 decision is recorded where a reader will find it — not only in this PRD.

## Out of scope

- Any change to how `capabilitiesByType` is read, or to `addPlayerAircraftByType`.
- Adding aircraft beyond these five. The catalogue is a starting point a mission can extend; this lot
  closes a gap found in production, it does not attempt DCS-wide coverage.
- Re-vendoring CTLD in VMCT. Tracked there; nothing in VMCT changes when this lands.
