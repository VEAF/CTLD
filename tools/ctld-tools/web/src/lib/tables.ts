// Field specs for the structured Data tables — the editor type per field, since the
// schema only carries descriptions (not types). Tooltips come from schema.tableFields.

import { humanize } from './labels'
import type { EditorType } from './model'

export interface Field {
  name: string
  type: EditorType
  tip?: string | null
  choices?: string[]
}

// Column headings for the structured tables. Each wording restates the field's own schema
// description (`tableFields` in CTLD_config_schema.yaml) — e.g. `at` is documented as
// "Number of anti-tank soldiers (RPG)" — so no meaning is invented here.
const FIELD_LABELS: Record<string, string> = {
  aa: 'Anti-air (MANPAD)',
  at: 'Anti-tank (RPG)',
  canPickup: 'Pickup allowed',
  colour: 'Smoke colour',
  cratesRequired: 'Crates required',
  desc: 'Display name',
  groupSize: 'Group size',
  iconId: 'Map icon ID',
  inf: 'Infantry',
  jtac: 'JTAC',
  mg: 'Machine-gunners',
  mortar: 'Mortar crew',
  name: 'Display name',
  side: 'Coalition',
  troopLimit: 'Troop limit',
  unit: 'DCS unit type',
  weight: 'Weight (kg)',
  zoneName: 'DCS zone name',
}

/** A readable column heading for a table field. */
export function fieldLabel(field: string): string {
  return FIELD_LABELS[field] ?? humanize(field)
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
