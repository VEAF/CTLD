// Field specs for the structured Data tables — the editor type per field, since the
// schema only carries descriptions (not types). Tooltips come from schema.tableFields.

import type { EditorType } from './model'

export interface Field {
  name: string
  type: EditorType
  tip?: string | null
}

export const TROOP_FIELDS: Omit<Field, 'tip'>[] = [
  { name: 'name', type: 'string' },
  { name: 'inf', type: 'number' },
  { name: 'mg', type: 'number' },
  { name: 'at', type: 'number' },
  { name: 'aa', type: 'number' },
  { name: 'mortar', type: 'number' },
  { name: 'jtac', type: 'boolean' },
]

// Merge a field spec with the tooltips for a table (schema.tableFields[table]).
export function withTips(fields: Omit<Field, 'tip'>[], tips: Record<string, string | null> | undefined): Field[] {
  return fields.map((f) => ({ ...f, tip: tips?.[f.name] ?? null }))
}

// capabilitiesByType: type → record with boolean flags, numeric maxima, and two vehicle lists.
export const AIRCRAFT_BOOLS = [
  'cratesEnabled',
  'troopsEnabled',
  'canSlingload',
  'canParachuteDrop',
  'useNativeDcsCargoSystem',
  'canTransportWholeVehicle',
  'convertNativeLoadToCTLD',
]
export const AIRCRAFT_NUMS = ['maxCratesOnboard', 'maxTroopsOnboard', 'maxWholeVehiclesOnboard', 'maxVehicleWeight']

export function blankAircraft(): Record<string, unknown> {
  const rec: Record<string, unknown> = {}
  for (const b of AIRCRAFT_BOOLS) rec[b] = false
  for (const n of AIRCRAFT_NUMS) rec[n] = 0
  rec.loadableVehiclesBLUE = []
  rec.loadableVehiclesRED = []
  return rec
}
