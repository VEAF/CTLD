import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import AircraftEditor from './AircraftEditor.svelte'

function setup() {
  const onchange = vi.fn()
  render(AircraftEditor, {
    capabilities: { 'UH-1H': { cratesEnabled: true, maxCratesOnboard: 1, loadableVehiclesBLUE: [], loadableVehiclesRED: [] } },
    fields: {},
    onchange,
  })
  return { onchange }
}

const last = (m: ReturnType<typeof vi.fn>) => m.mock.calls.at(-1)![0] as Record<string, Record<string, unknown>>

test('lists existing aircraft types', () => {
  setup()
  expect(screen.getByText('UH-1H')).toBeInTheDocument()
})

test('adding a type via the picker emits it with defaults', async () => {
  const { onchange } = setup()
  await fireEvent.input(screen.getByPlaceholderText('Add an aircraft type…'), { target: { value: 'Mi-8MT' } })
  await fireEvent.click(screen.getByText('+ Add aircraft'))
  const v = last(onchange)
  expect(Object.keys(v)).toContain('Mi-8MT')
  expect(v['Mi-8MT'].cratesEnabled).toBe(false) // blank default
})

test('toggling a capability emits the change', async () => {
  const { onchange } = setup()
  const cb = screen.getByLabelText('Crates enabled') as HTMLInputElement
  await fireEvent.click(cb) // true → false
  expect(last(onchange)['UH-1H'].cratesEnabled).toBe(false)
})

test('names the coalition vehicle lists by side, not by schema key', () => {
  setup()
  expect(screen.getByText('Whole vehicles — BLUE')).toBeInTheDocument()
  expect(screen.getByText('Whole vehicles — RED')).toBeInTheDocument()
})

test('an onboard-capacity limit renders a whole-number step and rounds a typed decimal', async () => {
  const { onchange } = setup()
  const input = screen.getByDisplayValue('1')
  expect(input).toHaveAttribute('step', '1')
  await fireEvent.change(input, { target: { value: '2.7' } })
  expect(last(onchange)['UH-1H'].maxCratesOnboard).toBe(3)
})

test('maxVehicleWeight stays a continuous field, unaffected by the integer type', () => {
  const onchange = vi.fn()
  render(AircraftEditor, {
    capabilities: { 'UH-1H': { maxVehicleWeight: 1360.5 } },
    fields: {},
    onchange,
  })
  expect(screen.getByDisplayValue('1360.5')).toHaveAttribute('step', 'any')
})

// ── FEAT-NATIVE-CRATE-SPAWN-NEAR ticket 01: where an aircraft's crates spawn ──────────────────────

test('choosing a crate spawn sector writes it, and clearing it removes the key', async () => {
  const { onchange } = setup()
  const select = screen.getByLabelText('Crate spawn sector') as HTMLSelectElement
  await fireEvent.change(select, { target: { value: 'side' } })
  expect(last(onchange)['UH-1H'].crateSpawnSector).toBe('side')
  await fireEvent.change(select, { target: { value: '' } })
  expect(last(onchange)['UH-1H']).not.toHaveProperty('crateSpawnSector')
})

test('the crate spawn distance is a free number of metres, cleared to absent', async () => {
  const { onchange } = setup()
  const input = screen.getByLabelText('Crate spawn distance') as HTMLInputElement
  expect(input).toHaveAttribute('step', 'any')
  await fireEvent.change(input, { target: { value: '3.7' } })
  expect(last(onchange)['UH-1H'].crateSpawnDistance).toBe(3.7)
  await fireEvent.change(input, { target: { value: '' } })
  expect(last(onchange)['UH-1H'].crateSpawnDistance).toBeUndefined()
})

test('editing another capability keeps a declared crate spawn plan', async () => {
  const onchange = vi.fn()
  render(AircraftEditor, {
    capabilities: { 'Mi-8MT': { cratesEnabled: true, crateSpawnSector: 'side', crateSpawnDistance: 4.0, loadableVehiclesBLUE: [], loadableVehiclesRED: [] } },
    fields: {},
    onchange,
  })
  await fireEvent.click(screen.getByLabelText('Crates enabled'))
  const rec = last(onchange)['Mi-8MT']
  expect(rec.crateSpawnSector).toBe('side')
  expect(rec.crateSpawnDistance).toBe(4)
})
