import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import CratesEditor from './CratesEditor.svelte'

function setup() {
  const onchange = vi.fn()
  const crates = {
    Support: [{ desc: 'Ammo', unit: 'Ural-375', weight: 1001.01, cratesRequired: 1 }],
  }
  render(CratesEditor, { crates, fields: { desc: { tip: 'Display name' } }, onchange })
  return { onchange }
}

function lastValue(onchange: ReturnType<typeof vi.fn>) {
  return onchange.mock.calls.at(-1)![0] as Record<string, Record<string, unknown>[]>
}

test('renders the crate entries', () => {
  setup()
  expect(screen.getByDisplayValue('Ammo')).toBeInTheDocument()
  expect(screen.getByDisplayValue('Ural-375')).toBeInTheDocument()
})

test('editing a field emits the whole structure', async () => {
  const { onchange } = setup()
  await fireEvent.change(screen.getByDisplayValue('Ammo'), { target: { value: 'Ammo box' } })
  expect(lastValue(onchange).Support[0].desc).toBe('Ammo box')
})

test('adding a crate emits a new entry', async () => {
  const { onchange } = setup()
  await fireEvent.click(screen.getByText('+ Add crate'))
  expect(lastValue(onchange).Support).toHaveLength(2)
})

test('removing a crate emits the shorter list', async () => {
  const { onchange } = setup()
  // The control names what it removes, so a row of ✕ buttons stays unambiguous.
  await fireEvent.click(screen.getByTitle('Remove Ammo'))
  expect(lastValue(onchange).Support).toHaveLength(0)
})

test('the DCS unit field is a combo backed by the shared type list', () => {
  setup()
  const unitField = screen.getByDisplayValue('Ural-375')
  // Free text plus a picker: a mod's type will not be in the datamine list.
  expect(unitField).toHaveAttribute('list', 'dcs-types')
  expect(unitField).toHaveClass('combo')
})

test('labels the crate fields in words, not schema keys', () => {
  setup()
  expect(screen.getByText('Display name')).toBeInTheDocument()
  expect(screen.getByText('DCS unit type')).toBeInTheDocument()
  expect(screen.getByText('Weight (kg)')).toBeInTheDocument()
  expect(screen.getByText('Coalition')).toBeInTheDocument()
})

// ── isJTAC + spawnAs (FEAT-EDITOR-COVERAGE ticket 03) ─────────────────────────
// The engine lases any isJTAC descriptor regardless of spawnAs, and the catalogue already ships
// two ground JTACs — only the editor was short. The two ship together because they determine each
// other: flagging an aircraft type as a JTAC without being able to set spawnAs gives a broken
// ground spawn with no message.

const JTAC_FIELDS = {
  desc: { tip: 'Display name' },
  spawnAs: { tip: 'Unpacks as', choices: ['GROUND', 'AIR'] },
  isJTAC: { tip: 'Mark as JTAC' },
}
const SPAWN_AS_BY_TYPE = {
  'MQ-9 Reaper': 'AIRPLANE',
  'UH-1H': 'HELICOPTER',
  Hummer: 'GROUND',
}

function renderJtacCrates(crate: Record<string, unknown>) {
  const onchange = vi.fn()
  render(CratesEditor, {
    crates: { Support: [{ desc: 'C', unit: crate.unit ?? 'Hummer', weight: 1, ...crate }] },
    fields: JTAC_FIELDS,
    spawnAsByType: SPAWN_AS_BY_TYPE,
    onchange,
  })
  return onchange
}

test('the spawnAs select offers exactly the schema choices, not a literal', () => {
  renderJtacCrates({})
  const select = screen.getByLabelText(/Unpacks as/i) as HTMLSelectElement
  expect([...select.options].map((o) => o.value)).toEqual(['GROUND', 'AIR'])
})

test('AIR resolves to HELICOPTER or AIRPLANE from the unit type', async () => {
  const onchange = renderJtacCrates({ unit: 'UH-1H' })
  await fireEvent.change(screen.getByLabelText(/Unpacks as/i), { target: { value: 'AIR' } })
  expect(onchange.mock.lastCall![0].Support[0].spawnAs).toBe('HELICOPTER')

  const onchange2 = renderJtacCrates({ unit: 'MQ-9 Reaper' })
  await fireEvent.change(screen.getAllByLabelText(/Unpacks as/i)[1], { target: { value: 'AIR' } })
  expect(onchange2.mock.lastCall![0].Support[0].spawnAs).toBe('AIRPLANE')
})

test('a stored AIRPLANE reads back as AIR, so a round-trip does not drift', () => {
  renderJtacCrates({ unit: 'MQ-9 Reaper', spawnAs: 'AIRPLANE' })
  expect((screen.getByLabelText(/Unpacks as/i) as HTMLSelectElement).value).toBe('AIR')
})

test('GROUND is written as an absent key, matching how the catalogue ships', async () => {
  const onchange = renderJtacCrates({ unit: 'MQ-9 Reaper', spawnAs: 'AIRPLANE' })
  await fireEvent.change(screen.getByLabelText(/Unpacks as/i), { target: { value: 'GROUND' } })
  expect(onchange.mock.lastCall![0].Support[0].spawnAs).toBeUndefined()
})

test('isJTAC toggles on any crate, ground included', async () => {
  const onchange = renderJtacCrates({ unit: 'Hummer' })
  await fireEvent.click(screen.getByLabelText(/JTAC/i))
  expect(onchange.mock.lastCall![0].Support[0].isJTAC).toBe(true)
})

test('unticking isJTAC removes the key rather than writing false', async () => {
  const onchange = renderJtacCrates({ unit: 'Hummer', isJTAC: true })
  await fireEvent.click(screen.getByLabelText(/JTAC/i))
  expect(onchange.mock.lastCall![0].Support[0].isJTAC).toBeUndefined()
})
