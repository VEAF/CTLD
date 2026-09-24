import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import SettingRow from './SettingRow.svelte'
import type { SchemaKey } from './api'

const BASE: SchemaKey = { group: null, standard: false, choices: null, editor: null, hidden: false, label: null, unit: null, description: null }

function setup(meta: SchemaKey, value: unknown) {
  const onedit = vi.fn()
  const onreset = vi.fn()
  render(SettingRow, { settingKey: 'numberOfTroops', meta, value, fallback: value, onedit, onreset })
  return { onedit }
}

test('an integer-typed setting renders a whole-number step', () => {
  setup({ ...BASE, type: 'integer' }, 10)
  expect(screen.getByDisplayValue('10')).toHaveAttribute('step', '1')
})

test('a plain number setting keeps the unrestricted step', () => {
  setup(BASE, 10)
  expect(screen.getByDisplayValue('10')).toHaveAttribute('step', 'any')
})

test('editing an integer-typed setting reports its type as integer, for the caller to round', async () => {
  const { onedit } = setup({ ...BASE, type: 'integer' }, 10)
  await fireEvent.change(screen.getByDisplayValue('10'), { target: { value: '6.01' } })
  expect(onedit).toHaveBeenCalledWith('numberOfTroops', '6.01', 'integer')
})

test('editing a plain number setting reports its type as number', async () => {
  const { onedit } = setup(BASE, 10)
  await fireEvent.change(screen.getByDisplayValue('10'), { target: { value: '6.01' } })
  expect(onedit).toHaveBeenCalledWith('numberOfTroops', '6.01', 'number')
})
