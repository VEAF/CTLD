import { describe, expect, it } from 'vitest'
import type { SchemaInfo, Snapshot } from './api'
import { classify, OTHER_FAMILY, parameterFamilies } from './model'

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
