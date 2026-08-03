# 02 — write the engine, the sounds and the config into the `.miz`

**Status:** done

Depends on: 01.

## What changes

`inject_userconfig()` becomes a full install. Into the archive:

| Payload | Where | Why |
|---|---|---|
| `CTLD.lua` | `l10n/DEFAULT/CTLD.lua` | the engine |
| `CTLD_userConfig.lua` | `l10n/DEFAULT/CTLD_userConfig.lua` | the YAML snapshot, in a Lua string |
| `beacon.ogg`, `beaconsilent.ogg` | `l10n/DEFAULT/` | `radioTransmission()` resolves `l10n/DEFAULT/<name>` |

And two MISSION START `DO SCRIPT FILE` triggers, **config first, engine second** — the engine reads
`ctld.configUser` at load, so the order is not cosmetic.

## Read VMCT first — decided, not optional

`DO SCRIPT FILE` does not name a path: it names a **resource key**, declared in the mission's
dictionary/resource map. That plumbing is what makes this ticket non-trivial, and VMCT's mission
builder already does all of it. **Read it before writing anything**
(`d:\dev\_VEAF\VEAF-Mission-Creation-Tools`, the mission-build scripts) and follow its approach
rather than reinventing one — the existing `miz.py` header already credits it for the trigger-index
rewriting.

Open question the reading must settle: whether a `.ogg` needs a resource-map entry at all, or
whether presence in the zip is enough for `trigger.action.radioTransmission`. The engine passes
`"l10n/DEFAULT/" .. ctld.gs("radioSound")` as a plain string, which suggests presence is enough —
confirm, do not assume.

## Idempotence

Re-running the tool on the same `.miz` must **replace**, never accumulate. The current inline
injection already does this by matching a marker comment; extend the same discipline to files,
triggers and resource-map entries. A `.miz` injected three times must be byte-comparable to one
injected once (modulo zip ordering).

## Acceptance

- A stock `.miz` + the tool → a mission that loads CTLD, with working beacons, no Mission Editor
  step.
- Injecting twice yields the same result as once: two triggers, one copy of each file, no orphan
  resource-map entry.
- The configuration trigger precedes the engine trigger.
- A `.miz` that already carries a hand-made CTLD trigger is not silently duplicated — either it is
  replaced or the user is told; decide and say which.

## Tests

- pytest: after injection the archive contains the four files and both triggers, in order.
- pytest: injecting twice is idempotent, asserted on the parsed mission table, not on bytes.
- pytest: the injected mission still parses through `luadata` and keeps every pre-existing trigger,
  with rewritten indices — the invariant the current tests already cover, extended to the new
  triggers.
- Integration (L3, `auto`) if it can be made to run offline: a mission injected by the tool boots
  CTLD and reports the expected version in the startup report.
