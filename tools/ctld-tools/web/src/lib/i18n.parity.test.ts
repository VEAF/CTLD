// The EN dictionary lives in the frontend (strings.ts) and the translations in the backend catalogs
// (ctld_tools/data/locales/*.json). That is a deliberate split — EN is needed before any fetch, for
// the first paint and the boot-failure path — but it is also a duplication, so it gets a guard:
// this test fails the build the moment the two drift apart in either direction.

import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import { EN_STRINGS } from './strings'

// vitest runs with the Vite root (tools/ctld-tools/web) as cwd; the catalogs sit next to it in the
// Python package. `import.meta.url` is not a file:// URL under jsdom, hence the cwd-relative path.
const LOCALES = resolve(process.cwd(), '../ctld_tools/data/locales')
const WEB_PREFIX = 'web.'

function catalog(lang: string): Record<string, string> {
  const all = JSON.parse(readFileSync(resolve(LOCALES, `${lang}.json`), 'utf-8')) as Record<string, string>
  return Object.fromEntries(Object.entries(all).filter(([key]) => key.startsWith(WEB_PREFIX)))
}

const en = catalog('en')
const fr = catalog('fr')

// `{name}` placeholders a template expects, so a translation cannot silently lose one.
const placeholders = (template: string) => [...template.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort()

describe('frontend EN dictionary ↔ backend catalogs', () => {
  it('covers exactly the same keys as the EN catalog', () => {
    expect(Object.keys(EN_STRINGS).sort()).toEqual(Object.keys(en).sort())
  })

  it('uses the same text as the EN catalog', () => {
    for (const [key, text] of Object.entries(en)) expect(EN_STRINGS[key], key).toBe(text)
  })
})

describe('FR catalog', () => {
  it('translates every web key', () => {
    expect(Object.keys(fr).sort()).toEqual(Object.keys(en).sort())
  })

  it('actually differs from EN (no untranslated leftovers)', () => {
    // A handful of strings are legitimately identical across the two languages. Each one is listed
    // deliberately, so a genuinely untranslated string cannot slip in unnoticed:
    //   web.aizone.add_restriction — "restriction" is spelled the same
    //   web.field.coalition       — likewise "Coalition"
    //   web.field.isJTAC          — an acronym
    //   web.field.jtac            — likewise
    //   web.field.side            — "Coalition" is spelled the same
    //   web.header.config         — likewise "Configuration"
    //   web.help.validation_title — likewise "Validation"
    //   web.help.data_sections    — "{n} sections" is identical in both
    const identical = Object.keys(en).filter((key) => en[key] === fr[key])
    expect(identical).toEqual(
      [
        'web.aizone.add_restriction',
        'web.field.coalition',
        'web.field.isJTAC',
        'web.field.jtac',
        'web.field.side',
        'web.header.config',
        'web.help.data_sections',
        'web.help.validation_title',
      ].sort(),
    )
  })

  it('keeps every placeholder', () => {
    for (const key of Object.keys(en)) expect(placeholders(fr[key]), key).toEqual(placeholders(en[key]))
  })
})

describe('plural pairs', () => {
  it('ships both variants wherever one exists', () => {
    for (const key of Object.keys(en)) {
      if (key.endsWith('.one')) expect(en, key).toHaveProperty(key.replace(/\.one$/, '.many'))
      if (key.endsWith('.many')) expect(en, key).toHaveProperty(key.replace(/\.many$/, '.one'))
    }
  })

  it('interpolates the count in both variants', () => {
    for (const [key, text] of Object.entries(en)) {
      if (key.endsWith('.one') || key.endsWith('.many')) expect(text, key).toContain('{n}')
    }
  })
})
