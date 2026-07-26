import { describe, expect, it } from 'vitest'
import type { SchemaInfo } from './api'
import { searchSettings } from './search'

const schema: SchemaInfo = {
  families: [],
  familyMeta: {},
  keys: {
    enableCrates: { group: 'crates', standard: true, choices: null, description: 'Master switch for crate spawning' },
    crateSpacing: { group: 'crates', standard: false, choices: null, description: null },
    maxDropHeight: { group: 'crates', standard: false, choices: null, description: 'Highest altitude to drop a crate from' },
    hoverTime: { group: null, standard: false, choices: null, description: 'Seconds a pilot must hover' },
  },
  tableFields: {},
  zoneFields: {},
}

const keys = Object.keys(schema.keys)
const familyFor = (k: string) => schema.keys[k]?.group ?? 'other'
const run = (q: string) => searchSettings(q, keys, schema, familyFor).map((h) => h.key)

describe('searchSettings', () => {
  it('returns nothing for an empty or blank query', () => {
    expect(run('')).toEqual([])
    expect(run('   ')).toEqual([])
  })

  it('matches the human label, case-insensitively', () => {
    expect(run('enable crates')).toEqual(['enableCrates'])
    expect(run('ENABLE CRATES')).toEqual(['enableCrates'])
  })

  it('matches the raw key, which is what the docs name', () => {
    expect(run('maxDrop')).toContain('maxDropHeight')
  })

  it('matches the description, so a concept finds its setting', () => {
    expect(run('hover')).toContain('hoverTime')
    expect(run('spawning')).toContain('enableCrates')
  })

  it('ranks a label prefix above a description match', () => {
    // "crate" prefixes no label; `crateSpacing`'s label starts with it, the others only mention it.
    const hits = run('crate')
    expect(hits[0]).toBe('crateSpacing')
    expect(hits).toContain('enableCrates')
  })

  it('reports the family that owns each hit', () => {
    const hits = searchSettings('hover', keys, schema, familyFor)
    expect(hits[0]).toMatchObject({ key: 'hoverTime', family: 'other' })
  })

  it('is stable — the same query twice gives the same order', () => {
    expect(run('crate')).toEqual(run('crate'))
  })

  it('still matches on label and key when the schema is missing', () => {
    // Descriptions are gone, so a description-only term finds nothing, but names still work.
    expect(searchSettings('hover', keys, null, familyFor).map((h) => h.key)).toEqual(['hoverTime'])
    expect(searchSettings('spawning', keys, null, familyFor)).toEqual([])
  })
})
