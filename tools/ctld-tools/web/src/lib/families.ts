// The 12 functional families (FullGas taxonomy, reconciled into the schema) + an Other
// catch-all. Labels are the UI names; keys are the schema `group:` values.

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
  [OTHER_FAMILY]: 'Other',
}

export function familyLabel(key: string): string {
  return FAMILY_LABELS[key] ?? key
}
