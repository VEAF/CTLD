// Search across every setting, standard and advanced, in every family.
//
// With ~136 settings over sixteen families, guessing which family owns a setting is the slowest
// path to it. Search is also the escape hatch from the standard/advanced split: a value hidden
// behind the Advanced disclosure is still one query away.

import type { SchemaInfo } from './api'
import { settingLabel } from './labels'

export interface Hit {
  key: string
  family: string
  score: number
}

// Lower score sorts first. The ranking answers "did the user type a name, or a concept?":
// a label prefix is almost certainly the setting they mean; a description match is a discovery.
const LABEL_PREFIX = 0
const LABEL_PART = 1
const KEY_PART = 2
const DESCRIPTION_PART = 3

/**
 * Rank the settings matching `query`. Case-insensitive over label, raw key and description.
 * An empty (or whitespace-only) query returns no hits — the caller then shows the selected family.
 */
export function searchSettings(
  query: string,
  keys: string[],
  schema: SchemaInfo | null,
  familyFor: (key: string) => string,
): Hit[] {
  const q = query.trim().toLowerCase()
  if (!q) return []
  const hits: Hit[] = []
  for (const key of keys) {
    const label = settingLabel(key, schema?.keys[key]?.label).toLowerCase()
    const description = (schema?.keys[key]?.description ?? '').toLowerCase()
    let score: number | null = null
    if (label.startsWith(q)) score = LABEL_PREFIX
    else if (label.includes(q)) score = LABEL_PART
    else if (key.toLowerCase().includes(q)) score = KEY_PART
    else if (description.includes(q)) score = DESCRIPTION_PART
    if (score !== null) hits.push({ key, family: familyFor(key), score })
  }
  // Stable within a score band: alphabetical by label, so repeated searches don't reshuffle.
  const name = (k: string) => settingLabel(k, schema?.keys[k]?.label)
  return hits.sort((a, b) => a.score - b.score || name(a.key).localeCompare(name(b.key)))
}
