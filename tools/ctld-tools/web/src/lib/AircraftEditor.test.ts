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
