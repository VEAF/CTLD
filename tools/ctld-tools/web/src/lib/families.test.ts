import { describe, expect, it } from 'vitest'
import { DATA_FAMILY, familyIcon, familyLabel, familyOf, FAMILY_ORDER, orderFamilies, OTHER_FAMILY } from './families'

describe('familyOf', () => {
  it('lets the schema group win over any derivation', () => {
    // JTAC_ would otherwise be derived as `jtac`; authored metadata is authoritative.
    expect(familyOf('JTAC_dropEnabled', 'general')).toBe('general')
    expect(familyOf('anythingAtAll', 'crates')).toBe('crates')
  })

  it('derives the family from the key prefix when the schema is silent', () => {
    expect(familyOf('JTAC_laseIntervalSeconds', null)).toBe('jtac')
    expect(familyOf('jtacLaserCodeMin', null)).toBe('jtac')
    expect(familyOf('AASystemLimitRED', null)).toBe('aa')
    expect(familyOf('aaRearmDistance', null)).toBe('aa')
    expect(familyOf('parachuteDescentRateCrates', null)).toBe('parachute')
    expect(familyOf('RIFLE_WEIGHT', null)).toBe('soldier_weights')
    expect(familyOf('beaconTextSize', null)).toBe('beacon')
    expect(familyOf('deployedBeaconBattery', null)).toBe('beacon')
    expect(familyOf('smokeRefreshInterval', null)).toBe('smoke')
    expect(familyOf('reconSearchRadius', null)).toBe('recon')
    expect(familyOf('fobCrateCollectionRadius', null)).toBe('fob')
    expect(familyOf('defaultZoneRadius', null)).toBe('zones')
    expect(familyOf('demineRadius', null)).toBe('mines')
    expect(familyOf('showMinefieldOnF10Map', null)).toBe('mines')
  })

  it('prefers the more specific rule when two could match', () => {
    // fob before the generic *Zone rule, or FOB settings would scatter into `zones`.
    expect(familyOf('fobLogisticZoneRadius', null)).toBe('fob')
    expect(familyOf('fobMinDistanceFromZones', null)).toBe('fob')
  })

  it('places a setting whose name mentions a subsystem anywhere, not just as a prefix', () => {
    expect(familyOf('crateSpacing', null)).toBe('crates')
    expect(familyOf('maxDistanceFromCrate', null)).toBe('crates')
    expect(familyOf('maxSlingloadSpeed', null)).toBe('crates')
    expect(familyOf('enableAutoOrbitingFlyingJtacOnTarget', null)).toBe('jtac')
    expect(familyOf('autoUnpackRadiusParachute', null)).toBe('parachute')
    expect(familyOf('debugScreenLogDuration', null)).toBe('general')
  })

  it('falls back to `other` rather than inventing a family', () => {
    // Nothing in these names announces a subsystem, so guessing would be a lie.
    expect(familyOf('hoverTime', null)).toBe(OTHER_FAMILY)
    expect(familyOf('spawnDistanceInCircle', undefined)).toBe(OTHER_FAMILY)
    expect(familyOf('groundAglThreshold', null)).toBe(OTHER_FAMILY)
  })
})

describe('orderFamilies', () => {
  it('follows the domain order, not the alphabet', () => {
    expect(orderFamilies(['jtac', 'crates', 'general', 'aircraft'])).toEqual([
      'general',
      'aircraft',
      'crates',
      'jtac',
    ])
  })

  it('keeps `other` last and appends anything unknown after the known families', () => {
    const ordered = orderFamilies([OTHER_FAMILY, 'zzz', 'crates'])
    expect(ordered[0]).toBe('crates')
    expect(ordered).toContain('zzz')
    expect(ordered.indexOf(OTHER_FAMILY)).toBeLessThan(ordered.indexOf('zzz'))
  })

  it('ignores families that are not present', () => {
    expect(orderFamilies([])).toEqual([])
    expect(orderFamilies(['crates'])).toEqual(['crates'])
  })
})

describe('family metadata', () => {
  it('labels and icons every ordered family', () => {
    for (const f of FAMILY_ORDER) {
      // A real label, never the raw schema key falling through.
      expect(familyLabel(f), f).not.toBe(f)
      expect(familyIcon(f).length, f).toBeGreaterThan(0)
    }
  })

  it('routes every structured table to a family that exists in the order', () => {
    for (const [key, family] of Object.entries(DATA_FAMILY)) {
      expect(FAMILY_ORDER, `${key} → ${family}`).toContain(family)
    }
  })

  it('keeps crates and their settings in the same family', () => {
    // The whole point of dropping the Parameters/Data split.
    expect(DATA_FAMILY.spawnableCrates).toBe('crates')
    expect(familyOf('enableCrates', 'crates')).toBe('crates')
  })
})
