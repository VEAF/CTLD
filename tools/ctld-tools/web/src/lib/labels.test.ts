import { describe, expect, it } from 'vitest'
import { humanize, unitOf } from './labels'

describe('humanize', () => {
  it('splits camelCase into a sentence-case label', () => {
    expect(humanize('enableCrates')).toBe('Enable crates')
    expect(humanize('maximumDistanceLogistic')).toBe('Maximum distance logistic')
    expect(humanize('fastRopeMaximumHeight')).toBe('Fast rope maximum height')
  })

  it('handles SCREAMING_SNAKE keys', () => {
    expect(humanize('RIFLE_WEIGHT')).toBe('Rifle weight')
    expect(humanize('SOLDIER_WEIGHT')).toBe('Soldier weight')
  })

  it('keeps acronyms upper-case, wherever they sit', () => {
    expect(humanize('JTAC_laseIntervalSeconds')).toBe('JTAC lase interval seconds')
    expect(humanize('jtacLaserCodeMax')).toBe('JTAC laser code max')
    expect(humanize('JTAC_smokeColour_BLUE')).toBe('JTAC smoke colour BLUE')
    expect(humanize('AASystemLimitRED')).toBe('AA system limit RED')
    expect(humanize('radioSoundFC3')).toBe('Radio sound FC3')
    expect(humanize('reconF10Menu')).toBe('Recon F10 menu')
    expect(humanize('enabledFOBBuilding')).toBe('Enabled FOB building')
  })

  it('separates a digit run from the word before it', () => {
    expect(humanize('JTAC_allow9Line')).toBe('JTAC allow 9 line')
  })

  it('does not mangle a word that merely contains an acronym', () => {
    // `at` is deliberately absent from the acronym table for exactly this case.
    expect(humanize('troopPickupAtFOB')).toBe('Troop pickup at FOB')
  })

  it('prefers an explicit override', () => {
    expect(humanize('i18n_lang')).toBe('CTLD interface language')
    expect(humanize('location_DMS')).toBe('Show coordinates as Degrees-Minutes-Seconds')
  })

  it('never returns empty', () => {
    expect(humanize('x')).toBe('X')
    expect(humanize('')).toBe('')
    expect(humanize('_')).toBe('_')
  })
})

describe('unitOf', () => {
  it('reads the unit the schema description documents', () => {
    expect(unitOf('Max height (m) for fast-rope insertion (≈ 60 ft)')).toBe('m')
    expect(unitOf('JTAC line-of-sight range (metres)')).toBe('m')
    expect(unitOf('JTAC laser + radio + binoculars (kg)')).toBe('kg')
    expect(unitOf('Auto-refresh interval (seconds)')).toBe('s')
  })

  it('reports no unit rather than guessing one', () => {
    // A parenthesised range is not a unit — and a description is optional in the first place.
    expect(unitOf('Horizontal inertia factor applied to the crate velocity (0–1, lower = less drift)')).toBeNull()
    expect(unitOf('Master switch for crate spawning and unpacking')).toBeNull()
    expect(unitOf(null)).toBeNull()
    expect(unitOf(undefined)).toBeNull()
    expect(unitOf('')).toBeNull()
  })
})
