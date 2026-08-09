import { fireEvent, render, screen, waitFor } from '@testing-library/svelte'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import SoundPicker from './SoundPicker.svelte'
import type { SoundState } from './api'

const DEFAULT_STATE: SoundState = {
  setting: 'radioSound',
  custom: false,
  file: 'beacon.ogg',
  originalName: null,
  size: null,
  available: true,
}

const CUSTOM_STATE: SoundState = {
  setting: 'radioSound',
  custom: true,
  file: 'CTLD_beacon_custom.ogg',
  originalName: 'Ma Balise Été.ogg',
  size: 410_000,
  available: true,
}

function mockFetch(handler: (url: string) => unknown) {
  vi.stubGlobal(
    'fetch',
    vi.fn(async (url: string) => ({ ok: true, json: async () => handler(url) })),
  )
}

beforeEach(() => mockFetch(() => ({})))
afterEach(() => vi.unstubAllGlobals())

describe('SoundPicker', () => {
  it('offers both sources, with the bundled one selected by default', () => {
    render(SoundPicker, { props: { sound: DEFAULT_STATE, onchange: () => {} } })
    const [dflt, custom] = screen.getAllByRole('radio') as HTMLInputElement[]
    expect(dflt.checked).toBe(true)
    expect(custom.checked).toBe(false)
  })

  it('shows the name the Mission Maker knows, not the reserved one, and still names the file', () => {
    render(SoundPicker, { props: { sound: CUSTOM_STATE, onchange: () => {} } })
    // ADR 0012: `CTLD_beacon_custom.ogg` means nothing to whoever picked `Ma Balise Été.ogg`.
    expect(screen.getByText(/Ma Balise Été\.ogg/)).toBeTruthy()
    expect(screen.getByText('CTLD_beacon_custom.ogg')).toBeTruthy()
    expect(screen.getByText('400 kB')).toBeTruthy()
  })

  it('warns when the file is no longer loaded — the case that would give silent beacons', () => {
    render(SoundPicker, { props: { sound: { ...CUSTOM_STATE, available: false }, onchange: () => {} } })
    expect(screen.getByText(/choose it again/i)).toBeTruthy()
  })

  it('asks the backend for a file and reports the change', async () => {
    const calls: string[] = []
    mockFetch((url) => {
      calls.push(url)
      return { setting: 'radioSound', file: 'CTLD_beacon_custom.ogg', originalName: 'x.ogg', size: 12 }
    })
    const onchange = vi.fn()
    render(SoundPicker, { props: { sound: DEFAULT_STATE, onchange } })

    await fireEvent.click(screen.getByRole('button'))
    await waitFor(() => expect(onchange).toHaveBeenCalled())
    expect(calls).toEqual(['/api/sounds/radioSound/custom'])
  })

  it('does not report a change when the Mission Maker cancels the dialog', async () => {
    mockFetch(() => ({ cancelled: true }))
    const onchange = vi.fn()
    render(SoundPicker, { props: { sound: DEFAULT_STATE, onchange } })

    await fireEvent.click(screen.getByRole('button'))
    await waitFor(() => expect(screen.getByRole('button')).not.toHaveProperty('disabled', true))
    expect(onchange).not.toHaveBeenCalled()
  })

  it('goes back to the bundled sound through its own endpoint', async () => {
    const calls: string[] = []
    mockFetch((url) => {
      calls.push(url)
      return { setting: 'radioSound', file: 'beacon.ogg' }
    })
    const onchange = vi.fn()
    render(SoundPicker, { props: { sound: CUSTOM_STATE, onchange } })

    const [dflt] = screen.getAllByRole('radio')
    await fireEvent.click(dflt)
    await waitFor(() => expect(onchange).toHaveBeenCalled())
    expect(calls).toEqual(['/api/sounds/radioSound/default'])
  })

  it('surfaces a refusal from the backend instead of failing silently', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => ({
        ok: false,
        statusText: 'Unprocessable',
        json: async () => ({ detail: 'music.ogg is not an Ogg file (no OggS signature)' }),
      })),
    )
    render(SoundPicker, { props: { sound: DEFAULT_STATE, onchange: () => {} } })

    await fireEvent.click(screen.getByRole('button'))
    await waitFor(() => expect(screen.getByText(/not an Ogg file/)).toBeTruthy())
  })
})
