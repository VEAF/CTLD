// The functional families — the app's only navigation axis.
//
// A family owns everything about one part of CTLD: its scalar settings *and* its structured tables.
// That is the whole point of dropping the old Parameters/Data split, which put `enableCrates` on one
// screen and `spawnableCrates` on another and left the user to guess which held what.
//
// A family comes from three sources, in order of authority:
//   1. the schema `group:` — authored metadata, always wins;
//   2. a prefix rule on the key name (below) — a stopgap for the ~44 settings the schema does not
//      cover yet, derived from the key's own spelling and nothing else;
//   3. `other`.

import type { FamilyMeta } from './api'

export const OTHER_FAMILY = 'other'

export const FAMILY_LABELS: Record<string, string> = {
  general: 'General',
  aircraft: 'Aircraft',
  crates: 'Crates',
  troops: 'Troops',
  zones: 'Zones',
  boarding: 'Boarding',
  fob: 'FOB / FARP',
  jtac: 'JTAC',
  recon: 'Recon',
  aa: 'AA system',
  beacon: 'Beacons',
  smoke: 'Smoke',
  mines: 'Mines',
  parachute: 'Parachute',
  soldier_weights: 'Soldier weights',
  [OTHER_FAMILY]: 'Other',
}

// Domain order, not alphabetical: the rail should read like the way a mission is put together —
// the airframes first, then what they carry, then where they operate, then the subsystems.
export const FAMILY_ORDER: string[] = [
  'general',
  'aircraft',
  'crates',
  'troops',
  'zones',
  'boarding',
  'fob',
  'jtac',
  'recon',
  'aa',
  'beacon',
  'smoke',
  'mines',
  'parachute',
  'soldier_weights',
  OTHER_FAMILY,
]

// Inline SVG bodies (24×24, stroked) — the rail has to be scannable, and bundling an icon library
// into an offline exe for sixteen glyphs is not worth it.
export const FAMILY_ICONS: Record<string, string> = {
  general: '<circle cx="12" cy="12" r="8.5"/><path d="M12 8v4l3 2"/>',
  aircraft: '<path d="M4 7h11M9.5 7V5M15 7c3 0 4.5 2 4.5 5v2H9.5V7M6 14h9v3H8a2 2 0 0 1-2-2z"/>',
  crates: '<path d="M3.5 8 12 4l8.5 4-8.5 4z"/><path d="M3.5 8v8L12 20l8.5-4V8"/><path d="M12 12v8"/>',
  troops: '<circle cx="9" cy="6" r="2.4"/><path d="M5 20v-3.5a4 4 0 0 1 8 0V20"/><path d="M16.5 10.5 20 9.5M16.5 10.5l2.5 2.5"/>',
  zones: '<path d="M12 21s6.5-5.6 6.5-11a6.5 6.5 0 1 0-13 0C5.5 15.4 12 21 12 21z"/><circle cx="12" cy="10" r="2.3"/>',
  boarding: '<path d="M4 18h16"/><path d="M8 18V9l6-4v13"/><path d="M11 12h3"/>',
  fob: '<path d="M3.5 20h17M6 20V9l6-4.5L18 9v11"/><path d="M10 20v-5h4v5"/>',
  jtac: '<circle cx="12" cy="12" r="7.5"/><circle cx="12" cy="12" r="2.5"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
  recon: '<circle cx="11" cy="11" r="6.5"/><path d="M20.5 20.5 16 16"/><path d="M8.5 11h5"/>',
  aa: '<path d="M12 3 5 20M12 3l7 17"/><path d="M8 13h8"/><path d="M4 20h16"/>',
  beacon: '<path d="M12 2.5v6"/><path d="M8.5 5.5 12 8.5l3.5-3"/><path d="M6 21.5 12 10l6 11.5z"/>',
  smoke: '<path d="M8 21c-2-3 0-5 1-7s0-4-1-6M13 21c-2-3 0-5 1-7s0-4-1-6M18 21c-2-3 0-5 1-7"/>',
  mines: '<circle cx="12" cy="14" r="4.5"/><path d="M12 9.5V5M7 14H2.5M21.5 14H17M8.2 10.2 5 7M15.8 10.2 19 7"/>',
  parachute: '<path d="M3.5 11a8.5 8.5 0 0 1 17 0z"/><path d="M3.5 11 12 20l8.5-9"/><path d="M12 11v9"/>',
  soldier_weights: '<path d="M6.5 7h11l-1.5 12h-8z"/><path d="M9.5 7V5.5h5V7"/><path d="M9 12h6"/>',
  [OTHER_FAMILY]: '<circle cx="12" cy="12" r="8.5"/><path d="M12 16.5v.01M12 7.5a2.2 2.2 0 0 1 1.2 4c-.7.5-1.2.9-1.2 1.8"/>',
}

/**
 * The family's display name. The schema's `families:` section is authoritative (and translated);
 * the constants above are the fallback when a family has no schema entry.
 */
export function familyLabel(key: string, meta?: Record<string, FamilyMeta>): string {
  return meta?.[key]?.label || FAMILY_LABELS[key] || key
}

/** What a Mission Maker will find in the family. Schema-only — never derived. */
export function familyDescription(key: string, meta?: Record<string, FamilyMeta>): string | null {
  return meta?.[key]?.description ?? null
}

export function familyIcon(key: string): string {
  return FAMILY_ICONS[key] ?? FAMILY_ICONS[OTHER_FAMILY]
}

/**
 * Order families for the rail. The schema's `order:` wins when present; otherwise the domain order
 * above, with anything unknown appended alphabetically.
 */
export function orderFamilies(families: Iterable<string>, meta?: Record<string, FamilyMeta>): string[] {
  const present = [...new Set(families)]
  if (meta && Object.keys(meta).length) {
    const rank = (f: string) => meta[f]?.order ?? 998
    return present.sort((a, b) => rank(a) - rank(b) || a.localeCompare(b))
  }
  const known = FAMILY_ORDER.filter((f) => present.includes(f))
  const extra = present.filter((f) => !FAMILY_ORDER.includes(f)).sort()
  return [...known, ...extra]
}

// Which family owns each structured table. Assigned by domain — the value's shape (list vs map)
// says nothing about where a user would look for it.
export const DATA_FAMILY: Record<string, string> = {
  spawnableCrates: 'crates',
  spawnableCratesModels: 'crates',
  logisticUnits: 'crates',
  groundVehicleWeights: 'crates',
  loadableGroups: 'troops',
  extractableGroups: 'troops',
  nbLimitSpawnedTroops: 'troops',
  capabilitiesByType: 'aircraft',
  transportPilotNames: 'aircraft',
  troopZones: 'zones',
  wpZones: 'zones',
  AIZones: 'zones',
  aiZones: 'zones',
  beaconIconColor: 'beacon',
}

// Prefix rules for settings the schema has no `group:` for. Ordered — first match wins, so the
// more specific pattern comes first. Purely spelling-based: no rule claims to know what a setting
// does, only that its name announces which subsystem it belongs to.
const PREFIX_RULES: [RegExp, string][] = [
  [/^AASystem/, 'aa'],
  [/^aa[A-Z]/, 'aa'],
  // `parachute` before `crate`: parachuteDescentRateCrates names both, and it is a parachute setting.
  [/parachute/i, 'parachute'],
  [/jtac/i, 'jtac'],
  [/_WEIGHT$/, 'soldier_weights'],
  [/^beacon/i, 'beacon'],
  [/^deployedBeacon/, 'beacon'],
  [/^smoke/i, 'smoke'],
  [/^recon/i, 'recon'],
  // fob before the generic zone rule, or fobLogisticZoneRadius would scatter into `zones`.
  [/^fob/i, 'fob'],
  [/^FOB/, 'fob'],
  [/^demine|Minefield/i, 'mines'],
  [/crate/i, 'crates'],
  [/sling/i, 'crates'],
  [/Zone(s|Radius)?$/, 'zones'],
  [/^debug/i, 'general'],
  [/^config/i, 'general'],
]

/** The family a setting belongs to: schema `group:` first, then a prefix rule, then `other`. */
export function familyOf(key: string, group: string | null | undefined): string {
  if (group) return group
  for (const [pattern, family] of PREFIX_RULES) if (pattern.test(key)) return family
  return OTHER_FAMILY
}
