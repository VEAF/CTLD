// Field specs for the structured Data tables — the editor type per field, since the
// schema only carries descriptions (not types). Tooltips come from schema.tableFields.

import { t } from './i18n.svelte'
import { humanize } from './labels'
import type { TableField } from './api'
import type { EditorType } from './model'

export interface Field {
  name: string
  type: EditorType
  tip?: string | null
  choices?: string[]
}

// Fields with a translated heading (`web.field.<name>`); anything else falls back to a label
// derived from the field name. Each wording restates the field's own schema description
// (`tableFields` in CTLD_config_schema.yaml) — e.g. `at` is "Number of anti-tank soldiers (RPG)".
const LABELLED_FIELDS = new Set([
  'vehicleTypes',
  'vehicleStock',
  'troopTemplates',
  'troopStock',
  'isPickup',
  'isDropoff',
  'dcsZoneName',
  'coalition',
  'cargoType',
  'aiDropMode',
  'aa',
  'at',
  'canPickup',
  'colour',
  'cratesRequired',
  'desc',
  'groupSize',
  'iconId',
  'inf',
  'isJTAC',
  'jtac',
  'mg',
  'mortar',
  'name',
  'side',
  'spawnAs',
  'troopLimit',
  'unit',
  'weight',
  'zoneName',
])

/** A readable column heading for a table field. */
export function fieldLabel(field: string): string {
  return LABELLED_FIELDS.has(field) ? t(`web.field.${field}`) : humanize(field)
}

/**
 * The `<datalist>` of DCS type names, mounted once in App.svelte and referenced by every field that
 * takes a DCS type. Any such field is a combo — pick from the 1000+ datamine types, or type a name
 * freely (a mod's type will not be in the list).
 */
export const DCS_TYPES_LIST = 'dcs-types'

// Every count in a troop group is a number, `jtac` included — the catalogue ships `jtac: 1` and
// `jtac: 2`. Typing it `boolean` (as this did) rendered a checkbox that was unchecked for any numeric
// value, so "JTAC Group" and "JTAC Group 2" looked identical and "Single JTAC" looked empty; worse,
// toggling it wrote `true`/`false` into the Mission Maker's YAML in place of the count.
// `'integer'` (not `'number'`): a soldier/launcher count is whole by nature (FIX-CTLD-TOOLS-INTEGER-FIELDS
// ticket 02, closing GitHub issue #157 — the reported bug was exactly a decimal in this table's `inf`).
export const TROOP_FIELDS: Omit<Field, 'tip'>[] = [
  { name: 'name', type: 'string' },
  { name: 'inf', type: 'integer' },
  { name: 'mg', type: 'integer' },
  { name: 'at', type: 'integer' },
  { name: 'aa', type: 'integer' },
  { name: 'mortar', type: 'integer' },
  { name: 'jtac', type: 'integer' },
]

// Merge a field spec with the schema metadata for a table (schema.tableFields[table]): the
// tooltip, and the allowed values when the schema declares a closed set.
export function withTips(fields: Omit<Field, 'tip'>[], meta: Record<string, TableField> | undefined): Field[] {
  return fields.map((f) => ({
    ...f,
    tip: meta?.[f.name]?.tip ?? null,
    choices: f.choices ?? meta?.[f.name]?.choices ?? undefined,
  }))
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
// Onboard-capacity limits are whole counts (FIX-CTLD-TOOLS-INTEGER-FIELDS ticket 02);
// `maxVehicleWeight` is a continuous kg value and stays `'number'`.
export const AIRCRAFT_NUMS: Omit<Field, 'tip'>[] = [
  { name: 'maxCratesOnboard', type: 'integer' },
  { name: 'maxTroopsOnboard', type: 'integer' },
  { name: 'maxWholeVehiclesOnboard', type: 'integer' },
  { name: 'maxVehicleWeight', type: 'number' },
]

export function blankAircraft(): Record<string, unknown> {
  const rec: Record<string, unknown> = {}
  for (const b of AIRCRAFT_BOOLS) rec[b] = false
  for (const n of AIRCRAFT_NUMS) rec[n.name] = 0
  rec.loadableVehiclesBLUE = []
  rec.loadableVehiclesRED = []
  return rec
}
