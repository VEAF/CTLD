// The functional families (FullGas's 12 + a Parachute family for the lot-1 parachute
// physics settings) + an Other catch-all. Labels are the UI names; keys are the schema
// `group:` values.

import { OTHER_FAMILY } from './model'

export const FAMILY_LABELS: Record<string, string> = {
  general: 'General',
  crates: 'Crates',
  troops: 'Troops',
  boarding: 'Boarding',
  jtac: 'JTAC',
  smoke: 'Smoke',
  beacon: 'Beacon',
  fob: 'FOB / FARP',
  recon: 'Recon',
  mines: 'Mines',
  aa: 'AA system',
  soldier_weights: 'Soldier weights',
  parachute: 'Parachute',
  [OTHER_FAMILY]: 'Other',
}

export function familyLabel(key: string): string {
  return FAMILY_LABELS[key] ?? key
}
