import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import CratesEditor from './CratesEditor.svelte'

function setup() {
  const onchange = vi.fn()
  const crates = {
    Support: [{ desc: 'Ammo', unit: 'Ural-375', weight: 1001.01, cratesRequired: 1 }],
  }
  render(CratesEditor, { crates, fields: { desc: 'Display name' }, onchange })
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
  await fireEvent.click(screen.getByText('+ crate'))
  expect(lastValue(onchange).Support).toHaveLength(2)
})

test('removing a crate emits the shorter list', async () => {
  const { onchange } = setup()
  await fireEvent.click(screen.getByTitle('remove crate'))
  expect(lastValue(onchange).Support).toHaveLength(0)
})
