// Classify a catalogue into the two screens (ADR 0011 point 7):
//   Parameters — scalar settings (how CTLD behaves), grouped by schema family.
//   Data       — structured entries (what CTLD operates on): crates, troops, zones, …

import type { SchemaInfo, SchemaKey, Snapshot, ZoneField } from './api'

export const OTHER_FAMILY = 'other'

export interface Screens {
  parameters: Record<string, string[]> // family → setting keys
  data: string[] // structured top-level keys
}

function isStructured(v: unknown): boolean {
  return v !== null && typeof v === 'object' // arrays and objects
}

export function classify(snap: Snapshot, schema: SchemaInfo): Screens {
  const parameters: Record<string, string[]> = {}
  const data: string[] = []
  for (const key of snap.keys) {
    if (isStructured(snap.values[key])) {
      data.push(key)
    } else {
      const family = schema.keys[key]?.group ?? OTHER_FAMILY
      ;(parameters[family] ??= []).push(key)
    }
  }
  for (const family of Object.keys(parameters)) parameters[family].sort()
  data.sort()
  return { parameters, data }
}

export function parameterFamilies(screens: Screens): string[] {
  return Object.keys(screens.parameters).sort()
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

// Split a family's setting keys into Standard vs Advanced (schema `standard:` flag).
export function standardSplit(keys: string[], schema: SchemaInfo): { standard: string[]; advanced: string[] } {
  const standard: string[] = []
  const advanced: string[] = []
  for (const key of keys) (schema.keys[key]?.standard ? standard : advanced).push(key)
  return { standard, advanced }
}
