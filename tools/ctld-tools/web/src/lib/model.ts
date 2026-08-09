// Classify a catalogue into functional families — the single navigation axis.
//
// ADR 0011 point 7 originally split the UI into two screens (Parameters = scalars, Data =
// structures). That split follows the *shape* of the value, which is an implementation detail: it
// filed `enableCrates` and `spawnableCrates` under different screens even though a Mission Maker
// thinks of both as "crates". Here every key — scalar or structured — lands in the family that owns
// its subject, and a family renders its settings and its tables together.

import type { SchemaInfo, SchemaKey, Snapshot, ZoneField } from './api'
import { DATA_FAMILY, familyOf, orderFamilies, OTHER_FAMILY } from './families'

export { OTHER_FAMILY }

export interface Family {
  key: string
  /** Scalar settings flagged `standard:` in the schema. */
  standard: string[]
  /** Everything else scalar — shown behind a disclosure. */
  advanced: string[]
  /** Structured keys (crates, troop groups, zones, …) owned by this family. */
  data: string[]
}

function isStructured(v: unknown): boolean {
  return v !== null && typeof v === 'object' // arrays and objects
}

/**
 * Group every catalogue key into its family, in domain order. Total: each key lands in exactly one
 * family, so no setting can become unreachable.
 */
export function classify(snap: Snapshot, schema: SchemaInfo): Family[] {
  const byKey = new Map<string, Family>()
  const family = (name: string): Family => {
    let f = byKey.get(name)
    if (!f) {
      f = { key: name, standard: [], advanced: [], data: [] }
      byKey.set(name, f)
    }
    return f
  }

  for (const key of snap.keys) {
    // A `hidden` key is written by the tool beside another setting (the original name of a custom
    // beacon sound, ADR 0012). It lives in the configuration but is not a setting: listing it would
    // invite hand-editing a label into disagreeing with the sound it describes.
    if (schema.keys[key]?.hidden) continue
    if (isStructured(snap.values[key])) {
      family(DATA_FAMILY[key] ?? OTHER_FAMILY).data.push(key)
    } else {
      const meta = schema.keys[key]
      const f = family(familyOf(key, meta?.group))
      ;(meta?.standard ? f.standard : f.advanced).push(key)
    }
  }

  for (const f of byKey.values()) {
    f.standard.sort()
    f.advanced.sort()
    f.data.sort()
  }
  return orderFamilies(byKey.keys(), schema.familyMeta).map((name) => byKey.get(name)!)
}

/**
 * Every scalar setting key in the catalogue, used by search.
 *
 * `schema` is optional only so old call sites keep working; pass it, or search will offer the
 * hidden tool-written keys that `classify` deliberately leaves out of the families.
 */
export function settingKeys(snap: Snapshot, schema?: SchemaInfo): string[] {
  return snap.keys.filter((k) => !isStructured(snap.values[k]) && !schema?.keys[k]?.hidden)
}

// ── scalar editors ────────────────────────────────────────────────
export type EditorType = 'boolean' | 'enum' | 'number' | 'string'

// Resolve the editor for a scalar setting. Never returns "nothing": an uncovered key
// falls back to a typed text field, so the coverage gate is always satisfiable.
export function editorType(meta: SchemaKey | undefined, value: unknown): EditorType {
  if (meta?.choices && meta.choices.length > 0) return 'enum'
  if (typeof value === 'boolean') return 'boolean'
  if (typeof value === 'number') return 'number'
  return 'string'
}

// Coerce an editor's raw output back to the value type before sending it to the backend.
export function coerce(raw: string | boolean, type: EditorType): unknown {
  if (type === 'boolean') return Boolean(raw)
  if (type === 'number') {
    const n = Number(raw)
    return Number.isNaN(n) ? raw : n
  }
  return raw
}

/**
 * Has this value been changed from the CTLD default?
 *
 * Compared loosely on purpose: a number that has been through a text field comes back as `"10"`
 * while the default is `10`, and flagging that as a change would light up the whole panel after a
 * no-op edit. Structured values are compared by their JSON form.
 */
export function isChanged(value: unknown, fallback: unknown): boolean {
  if (value === fallback) return false
  if (fallback === undefined) return false // no default known → nothing to compare against
  const bothScalar = (v: unknown) => v === null || typeof v !== 'object'
  if (bothScalar(value) && bothScalar(fallback)) return String(value) !== String(fallback)
  return JSON.stringify(value) !== JSON.stringify(fallback)
}

// ── zones (positional arrays ↔ named records) ─────────────────────
export function zoneToNamed(arr: unknown[], fields: ZoneField[]): Record<string, unknown> {
  const out: Record<string, unknown> = {}
  for (const f of fields) out[f.name] = arr[f.pos]
  return out
}

// Rebuild the positional array. Non-optional fields are always emitted (in pos order, gaps
// filled with a type default); trailing optional fields only when they hold a value.
export function namedToZone(named: Record<string, unknown>, fields: ZoneField[]): unknown[] {
  const sorted = [...fields].sort((a, b) => a.pos - b.pos)
  const out: unknown[] = []
  for (const f of sorted) {
    const v = named[f.name]
    const has = v !== undefined && v !== null && v !== ''
    if (f.optional && !has) continue
    out[f.pos] = has ? (f.type === 'int' ? Number(v) : v) : f.type === 'int' ? 0 : ''
  }
  return out
}
