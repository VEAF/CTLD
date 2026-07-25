// Field specs for the structured Data tables — the editor type per field, since the
// schema only carries descriptions (not types). Tooltips come from schema.tableFields.

import type { EditorType } from './model'

export interface Field {
  name: string
  type: EditorType
  tip?: string | null
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
