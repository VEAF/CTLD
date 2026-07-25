import { fireEvent, render, screen } from '@testing-library/svelte'
import { beforeEach, expect, test, vi } from 'vitest'
import App from './App.svelte'

const SCHEMA = {
  families: ['aa', 'troops'],
  keys: {
    numberOfTroops: { group: 'troops', standard: true, choices: null, description: null },
    aaRearmDistance: { group: 'aa', standard: false, choices: null, description: null },
  },
}

const SNAP = {
  path: null,
  keys: ['numberOfTroops', 'aaRearmDistance', 'spawnableCrates', 'transportPilotNames'],
  values: {
    numberOfTroops: 10,
    aaRearmDistance: 300,
    spawnableCrates: { Support: [] },
    transportPilotNames: ['Pilot #1'],
  },
}

function jsonResponse(body: unknown) {
  return new Response(JSON.stringify(body), { status: 200, headers: { 'Content-Type': 'application/json' } })
}

beforeEach(() => {
  global.fetch = vi.fn((input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (url.endsWith('/api/schema')) return Promise.resolve(jsonResponse(SCHEMA))
    if (url.endsWith('/api/catalog/load-default')) return Promise.resolve(jsonResponse(SNAP))
    if (url.endsWith('/api/catalog/setting') && init?.method === 'PUT') {
      return Promise.resolve(jsonResponse(JSON.parse(String(init.body)))) // echo {key, value}
    }
    return Promise.reject(new Error(`unexpected fetch: ${url}`))
  }) as unknown as typeof fetch
})

test('parameter families all render in the nav after load', async () => {
  render(App)
  await fireEvent.click(screen.getByText('Load defaults'))
  // Every group present among the scalar settings surfaces as a family button (labelled).
  expect(await screen.findByRole('button', { name: 'AA system' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'Troops' })).toBeInTheDocument()
})

test('data screen lists every structured key', async () => {
  render(App)
  await fireEvent.click(screen.getByText('Load defaults'))
  await fireEvent.click(await screen.findByText(/^Data/))
  expect(await screen.findByRole('button', { name: 'spawnableCrates' })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: 'transportPilotNames' })).toBeInTheDocument()
})

test('editing a scalar PUTs the coerced value', async () => {
  render(App)
  await fireEvent.click(screen.getByText('Load defaults'))
  // 'aa' is the first family; aaRearmDistance is a number editor in it.
  const field = await screen.findByLabelText('aaRearmDistance')
  await fireEvent.change(field, { target: { value: '350' } })
  expect(global.fetch).toHaveBeenCalledWith(
    '/api/catalog/setting',
    expect.objectContaining({ method: 'PUT', body: JSON.stringify({ key: 'aaRearmDistance', value: 350 }) }),
  )
})
