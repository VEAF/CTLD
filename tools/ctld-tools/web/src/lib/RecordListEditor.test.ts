import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import RecordListEditor from './RecordListEditor.svelte'
import type { Field } from './tables'

const FIELDS: Field[] = [
  { name: 'name', type: 'string' },
  { name: 'inf', type: 'integer' },
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

test('renders records with typed editors under readable headings', () => {
  setup()
  expect(screen.getByDisplayValue('Standard Group')).toBeInTheDocument()
  expect(screen.getByDisplayValue('6')).toBeInTheDocument()
  // `inf` is documented as "Number of infantry soldiers" — the heading says so.
  expect(screen.getByText('Infantry')).toBeInTheDocument()
  expect(screen.getByText('Display name')).toBeInTheDocument()
})

test('editing a numeric field coerces and emits', async () => {
  const { onchange } = setup()
  await fireEvent.change(screen.getByDisplayValue('6'), { target: { value: '9' } })
  expect(last(onchange)[0].inf).toBe(9)
})

test('an integer field renders a whole-number step and rounds a typed decimal', async () => {
  const { onchange } = setup()
  const input = screen.getByDisplayValue('6')
  expect(input).toHaveAttribute('step', '1')
  await fireEvent.change(input, { target: { value: '6.01' } })
  expect(last(onchange)[0].inf).toBe(6)
})

test('a plain number field keeps its 0.01 step, unaffected by the integer type', () => {
  render(RecordListEditor, {
    records: [{ name: 'x', weight: 5.5 }],
    fields: [{ name: 'weight', type: 'number' }],
    blank: () => ({}),
    onchange: vi.fn(),
  })
  expect(screen.getByDisplayValue('5.5')).toHaveAttribute('step', '0.01')
})

test('add and remove emit the new list', async () => {
  const { onchange } = setup()
  await fireEvent.click(screen.getByText('+ Add row'))
  expect(last(onchange)).toHaveLength(2)
  await fireEvent.click(screen.getAllByTitle('Remove this row')[0])
  expect(last(onchange)).toHaveLength(1)
})
