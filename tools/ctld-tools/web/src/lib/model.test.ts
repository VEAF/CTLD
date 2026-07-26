import { describe, expect, it } from 'vitest'
import type { SchemaInfo, SchemaKey, Snapshot, ZoneField } from './api'
import {
  classify,
  coerce,
  editorType,
  isChanged,
  namedToZone,
  OTHER_FAMILY,
  settingKeys,
  zoneToNamed,
  type EditorType,
} from './model'

const schema: SchemaInfo = {
  families: ['aa', 'troops', 'jtac'],
  familyMeta: {},
  keys: {
    numberOfTroops: { group: 'troops', standard: true, choices: null, label: null, description: null },
    aaRearmDistance: { group: 'aa', standard: false, choices: null, label: null, description: null },
    // hoverTime has no schema entry and no prefix rule → OTHER_FAMILY
  },
  tableFields: {},
  zoneFields: {},
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

const familyNamed = (name: string) => classify(snap, schema).find((f) => f.key === name)

describe('classify', () => {
  it('groups settings and their tables into one family each', () => {
    // `spawnableCrates` lands in `crates`, not in a separate Data screen.
    expect(familyNamed('crates')).toMatchObject({ data: ['spawnableCrates'] })
    expect(familyNamed('aircraft')).toMatchObject({ data: ['transportPilotNames'] })
    expect(familyNamed('troops')).toMatchObject({ standard: ['numberOfTroops'] })
  })

  it('splits a family by the schema standard flag', () => {
    expect(familyNamed('aa')).toMatchObject({ standard: [], advanced: ['aaRearmDistance'] })
  })

  it('returns families in domain order', () => {
    expect(classify(snap, schema).map((f) => f.key)).toEqual(['aircraft', 'crates', 'troops', 'aa', OTHER_FAMILY])
  })

  it('never drops a key — every catalogue key lands in exactly one family', () => {
    const placed = classify(snap, schema)
      .flatMap((f) => [...f.standard, ...f.advanced, ...f.data])
      .sort()
    expect(placed).toEqual([...snap.keys].sort())
  })

  it('puts an unplaceable setting in `other` rather than dropping it', () => {
    expect(familyNamed(OTHER_FAMILY)).toMatchObject({ advanced: ['hoverTime'] })
  })
})

describe('settingKeys', () => {
  it('lists the scalar keys only — what search covers', () => {
    expect(settingKeys(snap)).toEqual(['numberOfTroops', 'aaRearmDistance', 'hoverTime'])
  })
})

describe('editorType', () => {
  const enumMeta: SchemaKey = { group: null, standard: false, choices: ['a', 'b'], label: null, description: null }

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

describe('isChanged', () => {
  it('detects a real edit', () => {
    expect(isChanged(15, 10)).toBe(true)
    expect(isChanged(false, true)).toBe(true)
    expect(isChanged('beacon2.ogg', 'beacon.ogg')).toBe(true)
  })

  it('ignores an identical value', () => {
    expect(isChanged(10, 10)).toBe(false)
    expect(isChanged('a', 'a')).toBe(false)
    expect(isChanged(true, true)).toBe(false)
  })

  it('does not flag a value that only round-tripped through a text field', () => {
    // A number editor hands back "10" where the default is 10 — not an edit.
    expect(isChanged('10', 10)).toBe(false)
    expect(isChanged(10, '10')).toBe(false)
  })

  it('compares structured values by content', () => {
    expect(isChanged({ a: [1, 2] }, { a: [1, 2] })).toBe(false)
    expect(isChanged({ a: [1, 2] }, { a: [1, 3] })).toBe(true)
    expect(isChanged(['x'], ['x', 'y'])).toBe(true)
  })

  it('claims no change when no default is known', () => {
    expect(isChanged('anything', undefined)).toBe(false)
  })
})

describe('zone conversion', () => {
  const fields: ZoneField[] = [
    { name: 'zoneName', pos: 0, type: 'str' },
    { name: 'colour', pos: 1, type: 'str', choices: ['blue', 'red'] },
    { name: 'troopLimit', pos: 2, type: 'int' },
    { name: 'iconId', pos: 3, type: 'int', optional: true },
  ]

  it('maps positional → named by position', () => {
    expect(zoneToNamed(['pickzone1', 'blue', -1], fields)).toEqual({
      zoneName: 'pickzone1',
      colour: 'blue',
      troopLimit: -1,
      iconId: undefined,
    })
  })

  it('rebuilds positional, dropping an absent trailing optional', () => {
    const named = { zoneName: 'z', colour: 'red', troopLimit: 5 }
    expect(namedToZone(named, fields)).toEqual(['z', 'red', 5])
  })

  it('includes the optional when present and coerces ints', () => {
    const named = { zoneName: 'z', colour: 'red', troopLimit: '5', iconId: '7' }
    expect(namedToZone(named, fields)).toEqual(['z', 'red', 5, 7])
  })

  it('round-trips', () => {
    const arr = ['pickzone1', 'blue', 10]
    expect(namedToZone(zoneToNamed(arr, fields), fields)).toEqual(arr)
  })
})
