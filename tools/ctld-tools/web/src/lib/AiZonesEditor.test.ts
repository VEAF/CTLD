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
