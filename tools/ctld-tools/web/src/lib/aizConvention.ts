// The ctld-tools-only partial AIZ_ naming convention (FEAT-CTLD-TOOLS-AIZ-SYNC ticket 03) — see
// CONTEXT.md's "Tool-only naming convention" glossary entry and ADR 0017. The CTLD engine never
// parses this; it is purely an authoring shortcut this app uses to pre-fill `aiZones` entries.
//
// Format: AIZ_<name>_<coalition:R|B|N>_<P|D>_<cargoType-or-aiDropMode>[_<trailing...>]
// Parsed strictly left-to-right and positionally (not right-anchored like EXZ_'s `<name>`,
// ADR 0016): `name` is exactly the second `_`-delimited segment, because — unlike EXZ_'s fixed
// two-field tail — anything after the 4th field here is an arbitrary-length trailing suffix
// (e.g. a legacy stock-number like the `_10` in `AIZ_depot_B_P_V_10`), so there is no fixed end
// to anchor on. This constrains `name` to a single token; see ADR 0017.

type Zone = Record<string, unknown>

export type Coalition = 'RED' | 'BLUE' | 'NEUTRAL'

export interface AizParsed {
  dcsZoneName: string
  coalition: Coalition
  isPickup: boolean
  isDropoff: boolean
  cargoType?: string
  aiDropMode?: string
}

const COALITION_CODES: Record<string, Coalition> = { R: 'RED', B: 'BLUE', N: 'NEUTRAL' }
const CARGO_TYPES = new Set(['T', 'V', 'TV'])
const DROP_MODES = new Set(['G', 'P', 'GP'])

/** Parses one DCS zone name against the AIZ_ convention, or returns null when it doesn't match. */
export function parseAizZoneName(dcsZoneName: string): AizParsed | null {
  const parts = dcsZoneName.split('_')
  if (parts.length < 5 || parts[0] !== 'AIZ') return null

  const coalition = COALITION_CODES[parts[2]]
  if (!coalition) return null

  const pOrD = parts[3]
  if (pOrD !== 'P' && pOrD !== 'D') return null
  const isPickup = pOrD === 'P'

  const fourth = parts[4]
  if (isPickup ? !CARGO_TYPES.has(fourth) : !DROP_MODES.has(fourth)) return null

  return {
    dcsZoneName,
    coalition,
    isPickup,
    isDropoff: !isPickup,
    ...(isPickup ? { cargoType: fourth } : { aiDropMode: fourth }),
  }
}

/**
 * Every AIZ_-convention zone in `missionZoneNames` with no existing `aiZones` entry for that exact
 * `dcsZoneName` gets a new one, its 4 parseable fields filled in — `troopStock`/`vehicleStock` are
 * deliberately left absent, not an empty table, so the existing "pickup zone missing stock"
 * validation warning already signals "still needs attention".
 *
 * Additions only: an existing entry is never overwritten, and a zone name that doesn't match the
 * convention is never touched, whatever happens to it in the mission — see ticket 04 for the
 * (confirmation-gated) removal half of this reconciliation.
 *
 * Returns the same array reference when nothing changed, so a caller can cheaply tell whether an
 * update actually happened.
 */
export function addMissingAizZones(missionZoneNames: string[], existingZones: Zone[]): Zone[] {
  const known = new Set(existingZones.map((z) => String(z.dcsZoneName ?? '')))
  const additions: Zone[] = []
  for (const name of missionZoneNames) {
    if (known.has(name)) continue
    const parsed = parseAizZoneName(name)
    if (parsed) additions.push(parsed as unknown as Zone)
  }
  return additions.length ? [...existingZones, ...additions] : existingZones
}
