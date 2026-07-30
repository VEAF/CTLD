import { fireEvent, render, screen, waitFor } from '@testing-library/svelte'
import { beforeEach, expect, test, vi } from 'vitest'
import App from './App.svelte'

const SCHEMA = {
  families: ['aa', 'troops'],
  keys: {
    numberOfTroops: { group: 'troops', standard: true, choices: null, label: null, unit: null, description: 'Default troop group size' },
    aaRearmDistance: { group: 'aa', standard: false, choices: null, label: null, unit: null, description: 'Rearm range (metres)' },
  },
  familyMeta: {
    aa: { label: 'AA system', unit: null, description: 'Anti-air systems assembled from crates.', order: 100 },
    troops: { label: 'Troops', unit: null, description: 'Loading, deploying and extracting infantry.', order: 40 },
    crates: { label: 'Crates', unit: null, description: 'Spawning and unpacking supply crates.', order: 30 },
    aircraft: { label: 'Aircraft', unit: null, description: 'Which airframes carry what.', order: 20 },
  },
  tableFields: {
    spawnableCrates: {
      desc: { tip: 'Display name' },
      unit: { tip: 'DCS type' },
      weight_kg: { tip: 'mass' },
    },
  },
  zoneFields: {},
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

const DEFAULTS = { values: { numberOfTroops: 10, aaRearmDistance: 300 } }

let findings: unknown[] = []

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

beforeEach(() => {
  findings = []
  vi.stubGlobal('confirm', vi.fn(() => true))
  global.fetch = vi.fn((input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input)
    if (url.includes('/api/schema')) return Promise.resolve(jsonResponse(SCHEMA))
    if (url.includes('/api/i18n')) {
      const fr = url.includes('lang=fr')
      return Promise.resolve(
        jsonResponse({
          lang: fr ? 'fr' : 'en',
          available: ['en', 'fr'],
          strings: fr ? { 'web.state.clean': 'Aucune modification' } : {},
        }),
      )
    }
    if (url.endsWith('/api/defaults')) return Promise.resolve(jsonResponse(DEFAULTS))
    if (url.endsWith('/api/dcs-types')) return Promise.resolve(jsonResponse({ types: ['Ka-50', 'UH-1H'] }))
    if (url.endsWith('/api/catalog/load-default')) return Promise.resolve(jsonResponse(SNAP))
    if (url.endsWith('/api/catalog/load')) return Promise.resolve(jsonResponse(SNAP))
    if (url.endsWith('/api/catalog/save')) return Promise.resolve(jsonResponse({ saved: '/out.yaml' }))
    if (url.endsWith('/api/dialog/open')) return Promise.resolve(jsonResponse({ path: '/cfg.yaml' }))
    if (url.endsWith('/api/dialog/save')) return Promise.resolve(jsonResponse({ path: '/out.yaml' }))
    if (url.endsWith('/api/dialog/miz')) return Promise.resolve(jsonResponse({ path: '/m.miz' }))
    if (url.endsWith('/api/inject')) return Promise.resolve(jsonResponse({ injected: '/m.miz' }))
    if (url.endsWith('/api/catalog/setting') && init?.method === 'PUT') {
      return Promise.resolve(jsonResponse(JSON.parse(String(init.body)))) // echo {key, value}
    }
    if (url.endsWith('/api/validate')) return Promise.resolve(jsonResponse({ hasErrors: false, findings }))
    if (url.endsWith('/api/version-gap'))
      return Promise.resolve(
        jsonResponse({ fromVersion: '2.0.0', toVersion: '2.0.0', isEmpty: true, added: [], removed: [], changed: [] }),
      )
    return Promise.reject(new Error(`unexpected fetch: ${url}`))
  }) as unknown as typeof fetch
})

test('boots straight onto a populated catalogue, with no user action', async () => {
  render(App)
  // The old empty state ("Load the defaults … to begin") asked a question a first-time MM
  // could not answer; the app now loads the defaults itself.
  expect(await screen.findByRole('button', { name: /Troops/ })).toBeInTheDocument()
  expect(screen.getByText('CTLD defaults')).toBeInTheDocument()
})

test('every family surfaces in the single navigation, tables included', async () => {
  render(App)
  expect(await screen.findByRole('button', { name: /Troops/ })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: /AA system/ })).toBeInTheDocument()
  // spawnableCrates is a table, and lives in the Crates family rather than a Data screen.
  expect(screen.getByRole('button', { name: /Crates/ })).toBeInTheDocument()
  expect(screen.getByRole('button', { name: /Aircraft/ })).toBeInTheDocument()
})

test('the Parameters / Data vocabulary is gone', async () => {
  render(App)
  await screen.findByRole('button', { name: /Troops/ })
  expect(screen.queryByText(/how CTLD behaves/)).not.toBeInTheDocument()
  expect(screen.queryByText(/what CTLD operates on/)).not.toBeInTheDocument()
})

test('a setting shows its human label, its raw key and its unit', async () => {
  render(App)
  await fireEvent.click(await screen.findByRole('button', { name: /AA system/ }))
  // Advanced is collapsed but rendered, so the label is in the DOM either way.
  expect(await screen.findByText('AA rearm distance')).toBeInTheDocument()
  expect(screen.getByText('aaRearmDistance')).toBeInTheDocument()
  expect(screen.getByText('m')).toBeInTheDocument() // from "(metres)" in the description
})

test('editing a scalar PUTs the coerced value', async () => {
  render(App)
  await fireEvent.click(await screen.findByRole('button', { name: /AA system/ }))
  const field = await screen.findByLabelText('AA rearm distance')
  await fireEvent.change(field, { target: { value: '350' } })
  expect(global.fetch).toHaveBeenCalledWith(
    '/api/catalog/setting',
    expect.objectContaining({ method: 'PUT', body: JSON.stringify({ key: 'aaRearmDistance', value: 350 }) }),
  )
})

test('a changed setting can be reset to the CTLD default', async () => {
  render(App)
  await fireEvent.click(await screen.findByRole('button', { name: /AA system/ }))
  const field = await screen.findByLabelText('AA rearm distance')
  await fireEvent.change(field, { target: { value: '350' } })

  const reset = await screen.findByRole('button', { name: /Reset to default: AA rearm distance/ })
  await fireEvent.click(reset)
  expect(global.fetch).toHaveBeenCalledWith(
    '/api/catalog/setting',
    expect.objectContaining({ method: 'PUT', body: JSON.stringify({ key: 'aaRearmDistance', value: 300 }) }),
  )
  // Back at the default → nothing left to reset.
  await waitFor(() =>
    expect(screen.queryByRole('button', { name: /Reset to default: AA rearm distance/ })).not.toBeInTheDocument(),
  )
})

test('the header tracks whether work is saved', async () => {
  render(App)
  await fireEvent.click(await screen.findByRole('button', { name: /Troops/ }))
  expect(screen.getByText('No changes')).toBeInTheDocument()

  const field = await screen.findByLabelText('Number of troops')
  await fireEvent.change(field, { target: { value: '12' } })
  expect(await screen.findByText('Unsaved changes')).toBeInTheDocument()

  await fireEvent.click(screen.getByRole('button', { name: 'Save as…' }))
  expect(await screen.findByText('Saved')).toBeInTheDocument()
})

test('a family with no common settings opens its advanced list, not an empty panel', async () => {
  render(App)
  // `aa` holds only aaRearmDistance, flagged advanced — the panel must not look empty.
  await fireEvent.click(await screen.findByRole('button', { name: /AA system/ }))
  const disclosure = document.querySelector('details.advanced') as HTMLDetailsElement
  expect(disclosure.open).toBe(true)
})

test('search finds a setting from a family that is not selected', async () => {
  render(App)
  await screen.findByRole('button', { name: /Troops/ }) // Troops family is selected first
  await fireEvent.input(screen.getByPlaceholderText(/Search all settings/), { target: { value: 'rearm' } })
  expect(await screen.findByText('AA rearm distance')).toBeInTheDocument()
  expect(screen.getByText('1 setting found')).toBeInTheDocument()
  expect(screen.getByText(/in AA system/)).toBeInTheDocument()
})

test('a validation finding names the setting and jumps to its family', async () => {
  findings = [{ severity: 'error', where: 'settings', key: 'aaRearmDistance', message: 'must be positive' }]
  render(App)
  const finding = await screen.findByRole('button', { name: /AA rearm distance.*must be positive/ })
  expect(screen.getByText(/1 problem to fix before injecting/)).toBeInTheDocument()
  await fireEvent.click(finding)
  // Navigated to the owning family and revealed the setting.
  expect(await screen.findByLabelText('AA rearm distance')).toBeInTheDocument()
})

test('injection is blocked while the config has errors', async () => {
  findings = [{ severity: 'error', where: 'settings', key: 'aaRearmDistance', message: 'must be positive' }]
  render(App)
  await screen.findByText(/1 problem to fix before injecting/)
  expect(screen.getByRole('button', { name: /Inject into mission/ })).toBeDisabled()
})

test('injecting reports success and what happens next', async () => {
  render(App)
  await fireEvent.click(await screen.findByRole('button', { name: /Inject into mission/ }))
  expect(await screen.findByText(/Injected into \/m\.miz/)).toBeInTheDocument()
  expect(screen.getByText(/applied when the mission starts/)).toBeInTheDocument()
})

test('switching language translates the chrome and re-fetches the schema', async () => {
  render(App)
  await screen.findByRole('button', { name: /Troops/ })
  expect(screen.getByText('No changes')).toBeInTheDocument()

  await fireEvent.change(screen.getByRole('combobox', { name: /Language/ }), { target: { value: 'fr' } })

  // The chrome now comes from the backend catalog…
  expect(await screen.findByText('Aucune modification')).toBeInTheDocument()
  // …and the schema is re-requested for the new language, since descriptions live in it.
  expect(global.fetch).toHaveBeenCalledWith('/api/schema?lang=fr')
})

test('help opens, and is written from the schema and the catalogue', async () => {
  render(App)
  // Wait for the boot fetch: the help button exists from the first paint, and clicking it earlier
  // would render the panel before there is a catalogue to describe.
  await screen.findByRole('button', { name: /Troops/ })
  await fireEvent.click(screen.getByRole('button', { name: /Help/ }))
  const dialog = await screen.findByRole('dialog')
  expect(dialog).toBeInTheDocument()

  // Counts come from the live catalogue: 2 scalar settings across the families it produces.
  expect(screen.getByText(/2 settings across \d+ families/)).toBeInTheDocument()
  // Family descriptions are the schema's, not a hand-written copy.
  expect(screen.getByText('Anti-air systems assembled from crates.')).toBeInTheDocument()
  // The data inventory lists the real tables with their real sizes.
  expect(screen.getByText('spawnableCrates')).toBeInTheDocument()
  expect(screen.getByText('1 sections')).toBeInTheDocument() // { Support: [] }
  expect(screen.getByText('1 entries')).toBeInTheDocument() // transportPilotNames
})

test('help closes on Escape', async () => {
  render(App)
  await screen.findByRole('button', { name: /Troops/ })
  await fireEvent.click(screen.getByRole('button', { name: /Help/ }))
  await screen.findByRole('dialog')
  await fireEvent.keyDown(window, { key: 'Escape' })
  await waitFor(() => expect(screen.queryByRole('dialog')).not.toBeInTheDocument())
})

test('opening a file warns before discarding unsaved changes', async () => {
  render(App)
  await fireEvent.click(await screen.findByRole('button', { name: /Troops/ }))
  const field = await screen.findByLabelText('Number of troops')
  await fireEvent.change(field, { target: { value: '12' } })
  await screen.findByText('Unsaved changes')

  await fireEvent.click(screen.getByRole('button', { name: 'Open a config file…' }))
  expect(confirm).toHaveBeenCalled()
})
