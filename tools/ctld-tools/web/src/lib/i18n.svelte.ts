// The UI's active language.
//
// English is the base dictionary (`strings.ts`); the backend supplies translations for any other
// language from the same catalogs the CLI's validation messages use. Reactive, so switching language
// re-renders every label without a reload.
//
// The language the user picks is remembered in localStorage: the OS locale is only the first guess,
// and a MM running an English Windows may well want the French UI.

import { getI18n } from './api'
import { EN_STRINGS } from './strings'

const STORAGE_KEY = 'ctld-tools.lang'

let lang = $state('en')
let overrides = $state<Record<string, string>>({})
let available = $state<string[]>(['en'])

/** The active language code. */
export function currentLanguage(): string {
  return lang
}

/** The languages the backend ships a catalog for. */
export function availableLanguages(): string[] {
  return available
}

/** The language remembered from a previous session, if any. */
export function storedLanguage(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY)
  } catch {
    return null // private mode / storage disabled — fall back to the OS locale
  }
}

/**
 * Translate a key, interpolating `{name}` placeholders.
 *
 * Resolution: the active language's catalog, then English, then the key itself — the key surfacing
 * in the UI means a missing string, which the parity test is there to prevent.
 */
export function t(key: string, vars?: Record<string, string | number>): string {
  const template = overrides[key] ?? EN_STRINGS[key] ?? key
  if (!vars) return template
  return template.replace(/\{(\w+)\}/g, (whole, name) => (name in vars ? String(vars[name]) : whole))
}

/**
 * Translate a counted string, picking the `.one` / `.many` variant.
 * `base` is the key without the suffix: `plural('web.changed', 3)` → `web.changed.many`.
 */
export function plural(base: string, n: number, vars?: Record<string, string | number>): string {
  return t(`${base}.${n === 1 ? 'one' : 'many'}`, { n, ...vars })
}

/**
 * Switch language: load its catalog and remember the choice. English needs no fetch — it is the
 * base dictionary. A failed fetch leaves the previous language in place rather than blanking the UI.
 */
export async function setLanguage(next: string): Promise<void> {
  const code = next.trim().toLowerCase().slice(0, 2)
  if (code === 'en') {
    overrides = {}
    lang = 'en'
  } else {
    const body = await getI18n(code)
    overrides = body.strings
    lang = body.lang
    if (body.available.length) available = body.available
  }
  try {
    localStorage.setItem(STORAGE_KEY, lang)
  } catch {
    /* storage disabled — the choice just won't survive a restart */
  }
}

/**
 * Resolve the initial language: the remembered choice, else whatever the backend detected from the
 * OS locale. Also captures the available-language list for the picker.
 */
export async function initLanguage(): Promise<void> {
  const remembered = storedLanguage()
  const body = await getI18n(remembered ?? undefined)
  if (body.available.length) available = body.available
  lang = body.lang
  overrides = body.lang === 'en' ? {} : body.strings
}
