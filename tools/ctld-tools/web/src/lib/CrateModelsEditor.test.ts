import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import CrateModelsEditor from './CrateModelsEditor.svelte'

// spawnableCratesModels is a FIXED-KEY object: load / sling / dynamic are the three modes
// _crateModelKey resolves, so no row can be added or removed (FEAT-EDITOR-COVERAGE ticket 05).

const MODELS = {
  load: { canCargo: true, type: 'ammo_cargo' },
  sling: { canCargo: true, type: 'container_cargo', shape_name: 'bw_container_cargo' },
  dynamic: { canCargo: true, type: 'ammo_cargo' },
}

function setup(models = MODELS) {
  const onchange = vi.fn()
  render(CrateModelsEditor, { models: structuredClone(models), onchange })
  return onchange
}

test('renders exactly the three transport modes', () => {
  setup()
  for (const label of ['Carried inside', 'Slung underneath', 'DCS dynamic cargo']) {
    expect(screen.getByText(label)).toBeTruthy()
  }
})

test('offers no way to add or remove a mode', () => {
  setup()
  expect(screen.queryByText(/^\+/)).toBeNull()
  expect(screen.queryAllByLabelText(/remove/i)).toHaveLength(0)
})

test('editing the DCS static type writes it back', async () => {
  const onchange = setup()
  await fireEvent.change(screen.getAllByLabelText(/DCS static type/i)[0], { target: { value: 'uh1h_cargo' } })
  expect(onchange.mock.lastCall![0].load.type).toBe('uh1h_cargo')
})

test('clearing shape_name omits the key rather than writing an empty string', async () => {
  // The engine only sets data.shape_name when the key is present; "" would change the DCS
  // static definition rather than restore the default.
  const onchange = setup()
  await fireEvent.change(screen.getAllByLabelText(/Shape name/i)[1], { target: { value: '' } })
  expect(onchange.mock.lastCall![0].sling).not.toHaveProperty('shape_name')
})

test('canCargo round-trips as a boolean, not a string', async () => {
  const onchange = setup()
  await fireEvent.click(screen.getAllByLabelText(/Cargo-capable/i)[0])
  expect(onchange.mock.lastCall![0].load.canCargo).toBe(false)
})

test('the retired category field is never introduced', async () => {
  const onchange = setup()
  await fireEvent.change(screen.getAllByLabelText(/DCS static type/i)[0], { target: { value: 'ammo_cargo' } })
  for (const model of Object.values(onchange.mock.lastCall![0] as Record<string, object>)) {
    expect(model).not.toHaveProperty('category')
  }
})
