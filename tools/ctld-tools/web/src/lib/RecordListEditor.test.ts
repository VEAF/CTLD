import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import RecordListEditor from './RecordListEditor.svelte'
import type { Field } from './tables'

const FIELDS: Field[] = [
  { name: 'name', type: 'string' },
  { name: 'inf', type: 'number' },
  { name: 'jtac', type: 'boolean' },
]

function setup() {
  const onchange = vi.fn()
  render(RecordListEditor, {
    records: [{ name: 'Standard Group', inf: 6, jtac: false }],
    fields: FIELDS,
    blank: () => ({ name: '' }),
    onchange,
  })
  return { onchange }
}

const last = (m: ReturnType<typeof vi.fn>) => m.mock.calls.at(-1)![0] as Record<string, unknown>[]

test('renders records with typed editors', () => {
  setup()
  expect(screen.getByDisplayValue('Standard Group')).toBeInTheDocument()
  expect(screen.getByDisplayValue('6')).toBeInTheDocument()
})

test('editing a numeric field coerces and emits', async () => {
  const { onchange } = setup()
  await fireEvent.change(screen.getByDisplayValue('6'), { target: { value: '9' } })
  expect(last(onchange)[0].inf).toBe(9)
})

test('add and remove emit the new list', async () => {
  const { onchange } = setup()
  await fireEvent.click(screen.getByText('+ add'))
  expect(last(onchange)).toHaveLength(2)
  await fireEvent.click(screen.getAllByTitle('remove row')[0])
  expect(last(onchange)).toHaveLength(1)
})
