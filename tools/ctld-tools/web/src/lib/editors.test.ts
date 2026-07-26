import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import type { ZoneField } from './api'
import JsonEditor from './JsonEditor.svelte'
import KeyValueEditor from './KeyValueEditor.svelte'
import StringListEditor from './StringListEditor.svelte'
import VersionGapPopup from './VersionGapPopup.svelte'
import ZonesEditor from './ZonesEditor.svelte'

const last = (m: ReturnType<typeof vi.fn>) => m.mock.calls.at(-1)![0]

test('StringListEditor edits, adds and removes', async () => {
  const onchange = vi.fn()
  render(StringListEditor, { items: ['MEDEVAC #1', 'transport1'], onchange })
  await fireEvent.change(screen.getByDisplayValue('MEDEVAC #1'), { target: { value: 'MEDEVAC #2' } })
  expect(last(onchange)).toEqual(['MEDEVAC #2', 'transport1'])
  await fireEvent.click(screen.getByText('+ Add'))
  expect(last(onchange)).toHaveLength(3)
})

test('KeyValueEditor emits a name→number map', async () => {
  const onchange = vi.fn()
  render(KeyValueEditor, { map: { Hummer: 2500 }, onchange })
  await fireEvent.change(screen.getByDisplayValue('2500'), { target: { value: '3000' } })
  expect(last(onchange)).toEqual({ Hummer: 3000 })
})

test('JsonEditor parses valid JSON and reports invalid', async () => {
  const onchange = vi.fn()
  render(JsonEditor, { value: { a: 1 }, onchange })
  const ta = screen.getByRole('textbox')
  await fireEvent.input(ta, { target: { value: '{"a": 2}' } }) // sync bind:value
  await fireEvent.change(ta) // trigger commit
  expect(last(onchange)).toEqual({ a: 2 })
  await fireEvent.input(ta, { target: { value: '{bad' } })
  await fireEvent.change(ta)
  expect(screen.getByRole('alert')).toBeInTheDocument()
})

test('VersionGapPopup summarises the three diff buckets and closes', async () => {
  const onclose = vi.fn()
  render(VersionGapPopup, {
    gap: {
      fromVersion: '2.0.0',
      toVersion: '2.1.0',
      isEmpty: false,
      added: ['newSetting'],
      removed: ['oldSetting'],
      changed: [{ key: 'hoverTime', old: 10, new: 15 }],
    },
    onclose,
  })
  expect(screen.getByRole('dialog')).toBeInTheDocument()
  // Counted summaries the MM can act on, rather than three raw key lists.
  expect(screen.getByText('1 setting new in this CTLD version')).toBeInTheDocument()
  expect(screen.getByText('1 setting no longer used by CTLD')).toBeInTheDocument()
  expect(screen.getByText('1 default value changed')).toBeInTheDocument()
  // It must say plainly that nothing was merged behind the user's back.
  expect(screen.getByText(/Nothing has been merged/)).toBeInTheDocument()
  expect(screen.getByText('Hover time')).toBeInTheDocument()
  await fireEvent.click(screen.getByRole('button', { name: 'Continue' }))
  expect(onclose).toHaveBeenCalled()
})

test('ZonesEditor round-trips positional arrays through named fields', async () => {
  const onchange = vi.fn()
  const fields: ZoneField[] = [
    { name: 'zoneName', pos: 0, type: 'str' },
    { name: 'colour', pos: 1, type: 'str', choices: ['blue', 'red'] },
    { name: 'troopLimit', pos: 2, type: 'int' },
  ]
  render(ZonesEditor, { zones: [['pickzone1', 'blue', -1]], fields, onchange })
  await fireEvent.change(screen.getByDisplayValue('pickzone1'), { target: { value: 'pickzone2' } })
  expect(last(onchange)).toEqual([['pickzone2', 'blue', -1]])
})
