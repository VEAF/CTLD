import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import AiZonesEditor from './AiZonesEditor.svelte'

// The two traps this editor exists to respect (FEAT-EDITOR-COVERAGE ticket 04):
//  1. `coalition` is a STRING here, while every other coalition field is the numeric `side`.
//  2. `troopStock` / `vehicleStock` carry the magic key `All` and the magic value -1.

const FIELDS = {
  dcsZoneName: { tip: 'DCS trigger zone name' },
  coalition: { tip: 'a word, not a number', choices: ['RED', 'BLUE', 'NEUTRAL'] },
  cargoType: { tip: 'what moves', choices: ['T', 'V', 'TV'] },
  aiDropMode: { tip: 'how it delivers', choices: ['G', 'P', 'GP'] },
  isPickup: { tip: 'loads here' },
  isDropoff: { tip: 'delivers here' },
  troopStock: { tip: 'template → count' },
  vehicleStock: { tip: 'type → count' },
  troopTemplates: { tip: 'restrict' },
  vehicleTypes: { tip: 'restrict' },
}

function setup(zones: Record<string, unknown>[] = []) {
  const onchange = vi.fn()
  render(AiZonesEditor, { zones, fields: FIELDS, troopTemplates: ['Standard Group'], onchange })
  return onchange
}

test('the coalition select offers the schema choices, not a literal', () => {
  setup([{ dcsZoneName: 'AIZ_1', coalition: 'BLUE' }])
  const select = screen.getByLabelText(/Coalition/i) as HTMLSelectElement
  expect([...select.options].map((o) => o.value)).toEqual(['RED', 'BLUE', 'NEUTRAL'])
})

test('coalition round-trips as a string — a number would read as "any coalition"', async () => {
  const onchange = setup([{ dcsZoneName: 'AIZ_1', coalition: 'BLUE' }])
  await fireEvent.change(screen.getByLabelText(/Coalition/i), { target: { value: 'RED' } })
  const written = onchange.mock.lastCall![0][0].coalition
  expect(written).toBe('RED')
  expect(typeof written).toBe('string')
})

test('cargoType and aiDropMode also come from the schema', () => {
  setup([{ dcsZoneName: 'AIZ_1' }])
  expect([...(screen.getByLabelText(/Cargo type/i) as HTMLSelectElement).options].map((o) => o.value)).toEqual(['T', 'V', 'TV'])
  expect([...(screen.getByLabelText(/Delivery mode/i) as HTMLSelectElement).options].map((o) => o.value)).toEqual(['G', 'P', 'GP'])
})

test('a new stock entry defaults to unlimited, so -1 is never typed by hand', async () => {
  const onchange = setup([{ dcsZoneName: 'AIZ_1' }])
  await fireEvent.click(screen.getAllByText('+ stock entry')[0])
  await fireEvent.change(screen.getAllByPlaceholderText('All')[0], { target: { value: 'Standard Group' } })
  expect(onchange.mock.lastCall![0][0].troopStock).toEqual({ 'Standard Group': -1 })
})

test('unticking unlimited turns the magic value into a plain count', async () => {
  const onchange = setup([{ dcsZoneName: 'AIZ_1', troopStock: { 'Standard Group': -1 } }])
  await fireEvent.click(screen.getAllByLabelText(/unlimited/i)[0])
  expect(onchange.mock.lastCall![0][0].troopStock).toEqual({ 'Standard Group': 0 })
})

test('the All key is offered as a placeholder rather than left as lore', () => {
  setup([{ dcsZoneName: 'AIZ_1', troopStock: { All: -1 } }])
  expect(screen.getAllByPlaceholderText('All').length).toBeGreaterThan(0)
})

test('an emptied restriction list is written as absent, which the engine reads as "all"', async () => {
  const onchange = setup([{ dcsZoneName: 'AIZ_1', troopTemplates: ['Standard Group'] }])
  await fireEvent.click(screen.getAllByLabelText(/Remove/i).find((b) => b.getAttribute('aria-label')?.includes('Standard Group'))!)
  expect(onchange.mock.lastCall![0][0].troopTemplates).toBeUndefined()
})

test('adding a zone seeds the fields the engine needs', async () => {
  const onchange = setup([])
  await fireEvent.click(screen.getByText('+ AI zone'))
  const zone = onchange.mock.lastCall![0][0]
  expect(typeof zone.coalition).toBe('string')
  expect(zone.cargoType).toBe('T')
})

test('dcsZoneName suggests real zone names read from the tracked mission', () => {
  const onchange = vi.fn()
  render(AiZonesEditor, {
    // Neither name matches the AIZ_ convention (ticket 03), so this stays a pure autocomplete
    // check with no reconciliation side effect — that has its own tests further below.
    zones: [{ dcsZoneName: 'AIZ_1' }],
    fields: FIELDS,
    missionZoneNames: ['TRZ_pz1', 'Custom_Zone_1'],
    onchange,
  })
  const input = screen.getByLabelText(/DCS trigger zone/i) as HTMLInputElement
  const listId = input.getAttribute('list')
  expect(listId).toBeTruthy()
  const options = [...document.querySelectorAll(`#${listId} option`)].map((o) => (o as HTMLOptionElement).value)
  expect(options).toEqual(['TRZ_pz1', 'Custom_Zone_1'])
})

test('dcsZoneName still accepts free text with no mission tracked, or a name outside the list', async () => {
  const onchange = setup([{ dcsZoneName: 'AIZ_1' }]) // no missionZoneNames passed
  await fireEvent.change(screen.getByLabelText(/DCS trigger zone/i), { target: { value: 'Not_A_Real_Zone' } })
  expect(onchange.mock.lastCall![0][0].dcsZoneName).toBe('Not_A_Real_Zone')
})

test('a fresh scan silently adds an entry for an AIZ_-convention zone with none yet, stock left for the MM to fill in', async () => {
  const onchange = vi.fn()
  const { rerender } = render(AiZonesEditor, { zones: [], fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones: [], fields: FIELDS, missionZoneNames: ['AIZ_depot_B_P_V'], onchange })

  expect(onchange).toHaveBeenCalledTimes(1)
  const added = onchange.mock.lastCall![0][0]
  expect(added).toMatchObject({ dcsZoneName: 'AIZ_depot_B_P_V', coalition: 'BLUE', isPickup: true, cargoType: 'V' })
  expect(added.troopStock).toBeUndefined()
  expect(added.vehicleStock).toBeUndefined()
})

test('re-scanning the same mission again does not duplicate the entry it already added', async () => {
  const onchange = vi.fn()
  const { rerender } = render(AiZonesEditor, { zones: [], fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones: [], fields: FIELDS, missionZoneNames: ['AIZ_depot_B_P_V'], onchange })
  onchange.mockClear()

  // A new scan is a new array from App.svelte's fetch, even when the mission itself hasn't changed.
  await rerender({ zones: [], fields: FIELDS, missionZoneNames: ['AIZ_depot_B_P_V'], onchange })
  expect(onchange).not.toHaveBeenCalled()
})

test('a scan never overwrites an entry that already exists, complete or not', async () => {
  const onchange = vi.fn()
  const zones = [{ dcsZoneName: 'AIZ_depot_B_P_V', coalition: 'RED', isPickup: false, isDropoff: true }]
  const { rerender } = render(AiZonesEditor, { zones, fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones, fields: FIELDS, missionZoneNames: ['AIZ_depot_B_P_V'], onchange })
  expect(onchange).not.toHaveBeenCalled()
})

test('a scan never adds a zone whose name does not match the AIZ_ convention', async () => {
  const onchange = vi.fn()
  const { rerender } = render(AiZonesEditor, { zones: [], fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones: [], fields: FIELDS, missionZoneNames: ['My_Custom_Zone', 'TRZ_pz1'], onchange })
  expect(onchange).not.toHaveBeenCalled()
})
