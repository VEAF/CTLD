import { fireEvent, render, screen } from '@testing-library/svelte'
import { afterEach, expect, test, vi } from 'vitest'
import AiZonesEditor from './AiZonesEditor.svelte'

afterEach(() => vi.unstubAllGlobals())

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

test('a stock count is a whole-number field and rounds a typed decimal', async () => {
  const onchange = setup([{ dcsZoneName: 'AIZ_1', troopStock: { 'Standard Group': 5 } }])
  const input = screen.getByDisplayValue('5')
  expect(input).toHaveAttribute('step', '1')
  await fireEvent.change(input, { target: { value: '6.01' } })
  expect(onchange.mock.lastCall![0][0].troopStock).toEqual({ 'Standard Group': 6 })
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

test('adding a zone also seeds a safe troopStock, since its default cargo includes troops', async () => {
  const onchange = setup([])
  await fireEvent.click(screen.getByText('+ AI zone'))
  const zone = onchange.mock.lastCall![0][0]
  expect(zone.troopStock).toEqual({ All: -1 })
  expect(zone.vehicleStock).toBeUndefined()
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

test('a scan proposes removing an orphaned AIZ_ entry with a recap, and removes it once confirmed', async () => {
  const confirmSpy = vi.fn((_message?: string) => true)
  vi.stubGlobal('confirm', confirmSpy)
  const onchange = vi.fn()
  const zones = [{ dcsZoneName: 'AIZ_depot_B_P_V', coalition: 'BLUE', isPickup: true, cargoType: 'V' }]
  const { rerender } = render(AiZonesEditor, { zones, fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones, fields: FIELDS, missionZoneNames: ['TRZ_pz1'], onchange }) // AIZ_depot_B_P_V is gone

  expect(confirmSpy).toHaveBeenCalledTimes(1)
  expect(confirmSpy.mock.calls[0][0]).toContain('AIZ_depot_B_P_V')
  expect(onchange.mock.lastCall![0]).toEqual([])
})

test('declining the removal recap leaves the orphaned entry untouched', async () => {
  vi.stubGlobal('confirm', vi.fn(() => false))
  const onchange = vi.fn()
  const zones = [{ dcsZoneName: 'AIZ_depot_B_P_V', coalition: 'BLUE', isPickup: true, cargoType: 'V' }]
  const { rerender } = render(AiZonesEditor, { zones, fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones, fields: FIELDS, missionZoneNames: ['TRZ_pz1'], onchange })

  expect(confirm).toHaveBeenCalled()
  expect(onchange).not.toHaveBeenCalled() // nothing actually changed, so no commit
})

test('a freely-named entry is never proposed for removal, even if its zone disappears', async () => {
  const confirmSpy = vi.fn(() => true)
  vi.stubGlobal('confirm', confirmSpy)
  const onchange = vi.fn()
  const zones = [{ dcsZoneName: 'My_Custom_Zone', coalition: 'BLUE', isPickup: true }]
  const { rerender } = render(AiZonesEditor, { zones, fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones, fields: FIELDS, missionZoneNames: ['TRZ_pz1'], onchange }) // My_Custom_Zone's zone is gone

  expect(confirmSpy).not.toHaveBeenCalled()
  expect(onchange).not.toHaveBeenCalled()
})

test('a confirmed re-scan leaves AIZ_ entries exactly matching the mission — additions and removals both applied', async () => {
  vi.stubGlobal('confirm', vi.fn(() => true))
  const onchange = vi.fn()
  const zones = [
    { dcsZoneName: 'AIZ_old_B_P_V', coalition: 'BLUE', isPickup: true, cargoType: 'V' }, // orphaned by the rescan
    { dcsZoneName: 'My_Custom_Zone', coalition: 'RED', isPickup: false, isDropoff: true }, // untouched regardless
  ]
  const { rerender } = render(AiZonesEditor, { zones, fields: FIELDS, missionZoneNames: [], onchange })
  await rerender({ zones, fields: FIELDS, missionZoneNames: ['AIZ_new_R_D_G'], onchange })

  const finalNames = (onchange.mock.lastCall![0] as Record<string, unknown>[]).map((z) => z.dcsZoneName)
  expect(finalNames).toContain('AIZ_new_R_D_G')
  expect(finalNames).toContain('My_Custom_Zone')
  expect(finalNames).not.toContain('AIZ_old_B_P_V')
})

// ── FIX-CTLD-TOOLS-AIZ-STOCK-GAP ticket 03: inline stock indicator ────────────────

test('a troop-cargo pickup zone with no troopStock shows the warning indicator on the heading and the field', () => {
  setup([{ dcsZoneName: 'base', coalition: 'BLUE', isPickup: true, cargoType: 'T' }])
  const flags = screen.getAllByTitle('Troop pickup is disabled here until troopStock is set')
  expect(flags).toHaveLength(2) // one on the legend, one beside the troopStock field
  for (const flag of flags) expect(flag).toHaveClass('warn')
})

test('a vehicle-cargo pickup zone with no vehicleStock shows the informational indicator on the heading and the field', () => {
  setup([{ dcsZoneName: 'depot', coalition: 'BLUE', isPickup: true, cargoType: 'V' }])
  const flags = screen.getAllByTitle('No virtual stock set — this zone only offers a vehicle physically placed in the Mission Editor')
  expect(flags).toHaveLength(2)
  for (const flag of flags) expect(flag).toHaveClass('info')
})

test('the troop and vehicle indicators are visually distinguishable from each other', () => {
  setup([{ dcsZoneName: 'hub', coalition: 'BLUE', isPickup: true, cargoType: 'TV' }])
  const warn = screen.getAllByTitle('Troop pickup is disabled here until troopStock is set')
  const info = screen.getAllByTitle('No virtual stock set — this zone only offers a vehicle physically placed in the Mission Editor')
  expect(warn[0]).toHaveClass('warn')
  expect(info[0]).toHaveClass('info')
  expect(warn[0].className).not.toBe(info[0].className)
})

test('a complete pickup entry shows neither indicator', () => {
  setup([
    {
      dcsZoneName: 'depot',
      coalition: 'BLUE',
      isPickup: true,
      cargoType: 'TV',
      troopStock: { All: -1 },
      vehicleStock: { Hummer: 3 },
    },
  ])
  expect(screen.queryByTitle('Troop pickup is disabled here until troopStock is set')).not.toBeInTheDocument()
  expect(
    screen.queryByTitle('No virtual stock set — this zone only offers a vehicle physically placed in the Mission Editor'),
  ).not.toBeInTheDocument()
})

test('a dropoff-only entry shows neither indicator', () => {
  setup([{ dcsZoneName: 'lz', coalition: 'BLUE', isDropoff: true, aiDropMode: 'G' }])
  expect(screen.queryByTitle('Troop pickup is disabled here until troopStock is set')).not.toBeInTheDocument()
  expect(
    screen.queryByTitle('No virtual stock set — this zone only offers a vehicle physically placed in the Mission Editor'),
  ).not.toBeInTheDocument()
})

test('filling in the missing troopStock removes the warning indicator immediately', async () => {
  setup([{ dcsZoneName: 'base', coalition: 'BLUE', isPickup: true, cargoType: 'T' }])
  expect(screen.getAllByTitle('Troop pickup is disabled here until troopStock is set')).toHaveLength(2)

  await fireEvent.click(screen.getAllByText('+ stock entry')[0]) // troopStock is the first stock row
  await fireEvent.change(screen.getAllByPlaceholderText('All')[0], { target: { value: 'Standard Group' } })

  expect(screen.queryByTitle('Troop pickup is disabled here until troopStock is set')).not.toBeInTheDocument()
})
