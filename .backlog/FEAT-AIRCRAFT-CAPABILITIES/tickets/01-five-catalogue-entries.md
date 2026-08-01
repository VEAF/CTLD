# 01 — five capability entries: four Gazelles and the Yak-52

**Status:** done

No dependency.

## What changes

Five entries in `capabilitiesByType` (`src/CTLD_config.yaml`, section `mm_facing`), shaped like the
existing ones — `SK-60` is the closest template, being the non-slinging, non-vehicle case:

| type | troops | crates | maxTroopsOnboard |
|---|---|---|---|
| `SA342L` | ✓ | ✗ | 1 |
| `SA342M` | ✓ | ✗ | 1 |
| `SA342Mistral` | ✓ | ✗ | 1 |
| `SA342Minigun` | ✓ | ✗ | 1 |
| `Yak-52` | ✓ | ✗ | 1 |

The rest follows from "one soldier, nothing else": `canSlingload: false`,
`canTransportWholeVehicle: false`, `maxWholeVehiclesOnboard: 0`, `useNativeDcsCargoSystem: false`,
`convertNativeLoadToCTLD: false`, no `loadableVehicles*`, no `maxVehicleWeight`. `canParachuteDrop`
is the one worth a thought rather than a default — a Gazelle dropping a paratrooper is plausible, a
Yak-52 less so; whichever way it goes, both languages of the docs must agree with it.

Rebuild `CTLD.lua` (`tools\build\merge_CTLD.ps1`) and regenerate the defaults oracle
(`poetry -C tools/ctld-tools run ctld-tools gen --yaml src/CTLD_config.yaml --out tests/ci/data/config_defaults.json`)
— adding a catalogue key without re-emitting the oracle fails `config_spec` and the python-quality
drift guard, as PR #80 found.

## Watch out

- **`maxTroopsOnboard: 1` is a real limit, not a formality.** Check what the troop menu does when a
  template's group size exceeds the aircraft limit: a Gazelle offered a 6-man squad it cannot carry is
  a worse experience than no entry at all. If the menu already filters by `maxTroopsOnboard`, say so in
  the PR; if it does not, that is a finding, not a fix to sneak in here.
- No `loadableVehicles*` means no datamine-checked type names in this ticket. If any get added, they
  go through the datamine (`github.com/Quaggles/dcs-lua-datamine`), never a guess.

## Acceptance

- A player in an `SA342M` gets the CTLD menu with troops and without crates.
- The five entries validate: `ctld-tools validate` clean, busted config gate clean.
- No existing entry changes.
- `Ka-50` / `Ka-50_3` are still absent — deliberately (see the PRD).

## Tests

- busted: each of the five types resolves to a capability record with `troopsEnabled = true`,
  `cratesEnabled = false`, `maxTroopsOnboard = 1`.
- busted: `_detectCapabilities` reports `isTransport = true` for `SA342M` and `false` for `Ka-50`.
- busted: the shipped catalogue still parses and matches the oracle (existing spec, must stay green).
