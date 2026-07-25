// Classify a catalogue into the two screens (ADR 0011 point 7):
//   Parameters — scalar settings (how CTLD behaves), grouped by schema family.
//   Data       — structured entries (what CTLD operates on): crates, troops, zones, …

import type { SchemaInfo, Snapshot } from './api'

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
