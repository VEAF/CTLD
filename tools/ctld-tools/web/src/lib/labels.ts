// Human-readable labels for raw config keys, and the unit a setting is expressed in.
//
// Catalogue keys are Lua identifiers (`maximumDistanceLogistic`, `JTAC_smokeColour_BLUE`,
// `RIFLE_WEIGHT`). A Mission Maker should not have to read camelCase — but the raw key still
// matters, since it is what the docs, the forum threads and the validation messages name. So the
// UI leads with the label and keeps the key alongside it, de-emphasised.
//
// Nothing here invents meaning: a label is built from the key's own words, and a unit is read out
// of the schema description, which already documents it ("Max height (m) for fast-rope insertion").
// Guessing a unit from a key name would risk showing metres where the engine expects feet.

// Words that keep a fixed casing wherever they appear in a derived label. Only unambiguous
// tokens belong here — `at`, for instance, would wreck `troopPickupAtFOB`.
const ACRONYMS: Record<string, string> = {
  aa: 'AA',
  agl: 'AGL',
  ai: 'AI',
  blue: 'BLUE',
  ctld: 'CTLD',
  dcs: 'DCS',
  dms: 'DMS',
  f10: 'F10',
  farp: 'FARP',
  fc3: 'FC3',
  fob: 'FOB',
  jtac: 'JTAC',
  manpad: 'MANPAD',
  mg: 'MG',
  msl: 'MSL',
  red: 'RED',
  rpg: 'RPG',
}

// Keys whose derived label would read badly. Each wording is taken from the setting's own schema
// description — no new claim about what the setting does.
const LABEL_OVERRIDES: Record<string, string> = {
  CIV_WEIGHT: 'Civilian personal items weight',
  KIT_WEIGHT: 'Helmet and backpack weight',
  i18n_lang: 'CTLD interface language',
  location_DMS: 'Show coordinates as Degrees-Minutes-Seconds',
}

// Split a key into its words: `_` separators, camelCase humps, upper-case runs, and letter→digit
// boundaries (`allow9Line` → allow 9 Line, while `FC3` and `F10` stay whole).
function words(key: string): string[] {
  return key
    .split(/[_\s]+/)
    .flatMap((segment) =>
      segment
        .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
        .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
        .replace(/([a-z])([0-9])/g, '$1 $2')
        .split(/\s+/),
    )
    .filter(Boolean)
}

/** A sentence-case label for a config key. Falls back to the key itself if it has no words. */
export function humanize(key: string): string {
  const override = LABEL_OVERRIDES[key]
  if (override) return override
  // Drop a word repeated back-to-back: `JTAC_jtacStatusF10` would otherwise read
  // "JTAC JTAC status F10", since the prefix and the name say the same thing.
  const parts = words(key)
    .map((w) => ACRONYMS[w.toLowerCase()] ?? w.toLowerCase())
    .filter((w, i, all) => i === 0 || w.toLowerCase() !== all[i - 1].toLowerCase())
  if (!parts.length) return key
  const [first, ...rest] = parts
  const head = ACRONYMS[first.toLowerCase()] ? first : first[0].toUpperCase() + first.slice(1)
  return [head, ...rest].join(' ')
}

// Units as the schema descriptions spell them, mapped to the symbol shown next to the field.
const UNIT_PATTERNS: [RegExp, string][] = [
  [/\((?:m|metres|meters)\)/i, 'm'],
  [/\(kg\)/i, 'kg'],
  [/\((?:s|seconds)\)/i, 's'],
]

/**
 * The unit documented in a schema description, or null when it documents none.
 * Only an explicit parenthesised unit counts — `(0–1, lower = less drift)` is not a unit.
 */
export function unitOf(description: string | null | undefined): string | null {
  if (!description) return null
  for (const [pattern, unit] of UNIT_PATTERNS) if (pattern.test(description)) return unit
  return null
}
