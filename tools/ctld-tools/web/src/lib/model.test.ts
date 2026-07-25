import { describe, expect, it } from 'vitest'
import type { SchemaInfo, SchemaKey, Snapshot } from './api'
import {
  classify,
  coerce,
  editorType,
  OTHER_FAMILY,
  parameterFamilies,
  standardSplit,
  type EditorType,
} from './model'

const schema: SchemaInfo = {
  families: ['aa', 'troops', 'jtac'],
  keys: {
    numberOfTroops: { group: 'troops', standard: true, choices: null, description: null },
    aaRearmDistance: { group: 'aa', standard: false, choices: null, description: null },
    // hoverTime has no schema entry → falls into OTHER_FAMILY
  },
}

const snap: Snapshot = {
  path: null,
  keys: ['numberOfTroops', 'aaRearmDistance', 'hoverTime', 'spawnableCrates', 'transportPilotNames'],
  values: {
    numberOfTroops: 10,
    aaRearmDistance: 300,
    hoverTime: 10,
    spawnableCrates: { Support: [] },
    transportPilotNames: ['Pilot #1'],
  },
}

describe('classify', () => {
  it('splits scalars into Parameters (by family) and structures into Data', () => {
    const screens = classify(snap, schema)
    expect(parameterFamilies(screens)).toEqual(['aa', OTHER_FAMILY, 'troops'])
    expect(screens.parameters.troops).toEqual(['numberOfTroops'])
    expect(screens.parameters[OTHER_FAMILY]).toEqual(['hoverTime'])
    expect(screens.data).toEqual(['spawnableCrates', 'transportPilotNames'])
  })

  it('never drops a key — every catalogue key lands in exactly one screen', () => {
    const screens = classify(snap, schema)
    const placed = [...Object.values(screens.parameters).flat(), ...screens.data].sort()
    expect(placed).toEqual([...snap.keys].sort())
  })
})

describe('editorType', () => {
  const enumMeta: SchemaKey = { group: null, standard: false, choices: ['a', 'b'], description: null }

  it('resolves each scalar type', () => {
    expect(editorType(enumMeta, 'a')).toBe('enum')
    expect(editorType(undefined, true)).toBe('boolean')
    expect(editorType(undefined, 42)).toBe('number')
    expect(editorType(undefined, 'text')).toBe('string')
  })

  it('is total — every key renders an editor (generic fallback, coverage gate)', () => {
    const valid: EditorType[] = ['boolean', 'enum', 'number', 'string']
    const metas: (SchemaKey | undefined)[] = [undefined, enumMeta]
    const values: unknown[] = [true, 0, 3.14, 'x', null, undefined, ['a'], { k: 1 }]
    for (const meta of metas) for (const v of values) expect(valid).toContain(editorType(meta, v))
  })
})

describe('coerce', () => {
  it('coerces per editor type', () => {
    expect(coerce('25', 'number')).toBe(25)
    expect(coerce('not-a-number', 'number')).toBe('not-a-number')
    expect(coerce(true, 'boolean')).toBe(true)
    expect(coerce('hello', 'string')).toBe('hello')
  })
})

describe('standardSplit', () => {
  it('splits a family by the schema standard flag', () => {
    const schema2: SchemaInfo = {
      families: [],
      keys: {
        a: { group: 'x', standard: true, choices: null, description: null },
        b: { group: 'x', standard: false, choices: null, description: null },
      },
    }
    expect(standardSplit(['a', 'b', 'c'], schema2)).toEqual({ standard: ['a'], advanced: ['b', 'c'] })
  })
})
