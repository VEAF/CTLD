import { fireEvent, render, screen } from '@testing-library/svelte'
import { expect, test, vi } from 'vitest'
import CompletionSummary from './CompletionSummary.svelte'
import type { CompletionAddition } from './api'

const ADDED: CompletionAddition[] = [
  { key: 'crateSpawnGap', value: 0.5, section: 'advanced' },
  { key: 'enableParachuteDrop', value: true, section: 'mm_facing' },
]

function setup(additions = ADDED) {
  const onundo = vi.fn()
  const onclose = vi.fn()
  render(CompletionSummary, { additions, labelOf: (k: string) => `label ${k}`, onundo, onclose })
  return { onundo, onclose }
}

test('it says how many settings were added and lists each one with its default', () => {
  setup()
  expect(screen.getByText('2 settings added from the catalogue')).toBeInTheDocument()
  expect(screen.getByText('label crateSpawnGap')).toBeInTheDocument()
  expect(screen.getByText('crateSpawnGap')).toBeInTheDocument()
  expect(screen.getByText('0.5')).toBeInTheDocument()
  expect(screen.getByText('label enableParachuteDrop')).toBeInTheDocument()
  expect(screen.getByText('true')).toBeInTheDocument()
})

test('one added setting uses the singular', () => {
  setup([ADDED[0]])
  expect(screen.getByText('1 setting added from the catalogue')).toBeInTheDocument()
})

test('undoing an addition reports its key', async () => {
  const { onundo } = setup()
  await fireEvent.click(screen.getAllByRole('button', { name: 'Undo' })[1])
  expect(onundo).toHaveBeenCalledWith(ADDED[1])
})

test('it can be dismissed', async () => {
  const { onclose } = setup()
  await fireEvent.click(screen.getByRole('button', { name: 'Dismiss' }))
  expect(onclose).toHaveBeenCalled()
})

test('fields of list entries are grouped under the entry they belong to', async () => {
  const fields: CompletionAddition[] = [
    { key: 'crateSpawnSector', value: 'side', section: 'advanced', container: 'capabilitiesByType', entry: 'Mi-8MT' },
    { key: 'crateSpawnDistance', value: 4, section: 'advanced', container: 'capabilitiesByType', entry: 'Mi-8MT' },
    { key: 'size', value: 1.31, section: 'advanced', container: 'spawnableCratesModels', entry: 'load' },
  ]
  const { onundo } = setup(fields)
  expect(screen.getByText('3 settings added from the catalogue')).toBeInTheDocument()
  expect(screen.getByText('Mi-8MT')).toBeInTheDocument()
  expect(screen.getByText('load')).toBeInTheDocument()
  await fireEvent.click(screen.getAllByRole('button', { name: 'Undo' })[0])
  expect(onundo).toHaveBeenCalledWith(fields[0])
})
