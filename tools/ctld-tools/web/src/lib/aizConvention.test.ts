import { expect, test } from 'vitest'
import { addMissingAizZones, defaultTroopStock, findOrphanedAizZones, parseAizZoneName } from './aizConvention'

test('parses a well-formed pickup zone', () => {
  expect(parseAizZoneName('AIZ_depot_B_P_V')).toEqual({
    dcsZoneName: 'AIZ_depot_B_P_V',
    coalition: 'BLUE',
    isPickup: true,
    isDropoff: false,
    cargoType: 'V',
  })
})

test('parses a well-formed dropoff zone', () => {
  expect(parseAizZoneName('AIZ_fwd_R_D_GP')).toEqual({
    dcsZoneName: 'AIZ_fwd_R_D_GP',
    coalition: 'RED',
    isPickup: false,
    isDropoff: true,
    aiDropMode: 'GP',
  })
})

test('every coalition code maps to its full name', () => {
  expect(parseAizZoneName('AIZ_x_R_P_T')?.coalition).toBe('RED')
  expect(parseAizZoneName('AIZ_x_B_P_T')?.coalition).toBe('BLUE')
  expect(parseAizZoneName('AIZ_x_N_P_T')?.coalition).toBe('NEUTRAL')
})

test('tolerates a trailing legacy stock-number suffix', () => {
  // The real form already present in Test_CTLDNEXT_01.miz — must still parse the first 4 fields.
  expect(parseAizZoneName('AIZ_depot_B_P_V_10')).toEqual({
    dcsZoneName: 'AIZ_depot_B_P_V_10',
    coalition: 'BLUE',
    isPickup: true,
    isDropoff: false,
    cargoType: 'V',
  })
})

test('rejects the wrong prefix', () => {
  expect(parseAizZoneName('TRZ_depot_B_P_V')).toBeNull()
})

test('rejects too few fields', () => {
  expect(parseAizZoneName('AIZ_depot_B_P')).toBeNull()
  expect(parseAizZoneName('AIZ_depot')).toBeNull()
})

test('rejects an unknown coalition code', () => {
  expect(parseAizZoneName('AIZ_depot_X_P_V')).toBeNull()
})

test('rejects neither P nor D', () => {
  expect(parseAizZoneName('AIZ_depot_B_X_V')).toBeNull()
})

test('rejects a cargoType invalid for a pickup zone', () => {
  expect(parseAizZoneName('AIZ_depot_B_P_G')).toBeNull() // G is a drop mode, not a cargo type
})

test('rejects an aiDropMode invalid for a dropoff zone', () => {
  expect(parseAizZoneName('AIZ_depot_B_D_V')).toBeNull() // V is a cargo type, not a drop mode
})

test('a name with an internal underscore does not parse — the format is positional, not right-anchored', () => {
  // Unlike EXZ_ (ADR 0016), AIZ_'s trailing content is arbitrary-length, so name must be one token.
  expect(parseAizZoneName('AIZ_forward_depot_B_P_V')).toBeNull()
})

test('addMissingAizZones creates an entry for every unmatched AIZ_ zone, stock left absent', () => {
  const result = addMissingAizZones(['AIZ_depot_B_P_V', 'TRZ_pz1'], [])
  expect(result).toEqual([
    { dcsZoneName: 'AIZ_depot_B_P_V', coalition: 'BLUE', isPickup: true, isDropoff: false, cargoType: 'V' },
  ])
  expect(result[0]).not.toHaveProperty('troopStock')
  expect(result[0]).not.toHaveProperty('vehicleStock')
})

test('defaultTroopStock is unlimited-all when cargo includes troops, absent otherwise', () => {
  expect(defaultTroopStock('T')).toEqual({ All: -1 })
  expect(defaultTroopStock('TV')).toEqual({ All: -1 })
  expect(defaultTroopStock('V')).toBeUndefined()
  expect(defaultTroopStock(undefined)).toBeUndefined()
})

test('addMissingAizZones gives a troop-cargo pickup zone a safe troopStock, never vehicleStock', () => {
  const result = addMissingAizZones(['AIZ_depot_B_P_T', 'AIZ_hub_B_P_TV'], [])
  expect(result).toEqual([
    { dcsZoneName: 'AIZ_depot_B_P_T', coalition: 'BLUE', isPickup: true, isDropoff: false, cargoType: 'T', troopStock: { All: -1 } },
    { dcsZoneName: 'AIZ_hub_B_P_TV', coalition: 'BLUE', isPickup: true, isDropoff: false, cargoType: 'TV', troopStock: { All: -1 } },
  ])
  for (const zone of result) expect(zone).not.toHaveProperty('vehicleStock')
})

test('addMissingAizZones never touches an already-present entry', () => {
  const existing = [{ dcsZoneName: 'AIZ_depot_B_P_V', coalition: 'BLUE', isPickup: true, isDropoff: false, cargoType: 'V', troopStock: { All: 3 } }]
  const result = addMissingAizZones(['AIZ_depot_B_P_V'], existing)
  expect(result).toBe(existing) // same reference: nothing changed
})

test('addMissingAizZones ignores a zone name that does not match the convention', () => {
  const existing: Record<string, unknown>[] = []
  const result = addMissingAizZones(['Not_A_Real_Zone', 'TRZ_pz1'], existing)
  expect(result).toBe(existing)
})

test('addMissingAizZones returns the same reference when there is nothing to add', () => {
  const existing = [{ dcsZoneName: 'AIZ_depot_B_P_V' }]
  expect(addMissingAizZones(['AIZ_depot_B_P_V'], existing)).toBe(existing)
})

test('findOrphanedAizZones flags an AIZ_-convention entry whose zone is gone from the mission', () => {
  const existing = [{ dcsZoneName: 'AIZ_depot_B_P_V' }]
  expect(findOrphanedAizZones([], existing)).toEqual(existing)
  expect(findOrphanedAizZones(['TRZ_pz1'], existing)).toEqual(existing)
})

test('findOrphanedAizZones never flags an entry whose zone still exists', () => {
  const existing = [{ dcsZoneName: 'AIZ_depot_B_P_V' }]
  expect(findOrphanedAizZones(['AIZ_depot_B_P_V'], existing)).toEqual([])
})

test('findOrphanedAizZones never flags a freely-named entry, even if its zone is gone', () => {
  const existing = [{ dcsZoneName: 'My_Custom_Zone' }]
  expect(findOrphanedAizZones([], existing)).toEqual([])
  expect(findOrphanedAizZones(['TRZ_pz1'], existing)).toEqual([])
})
