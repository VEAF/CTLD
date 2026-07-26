# 11 — French UI

**Status:** done

## Why

The PRD deferred this to a later lot; David asked for it now. For a francophone Mission Maker with
little computing background, an English-only interface is the last real barrier — and the backend
already had the whole i18n machinery (`ctld_tools/i18n.py`, EN+FR JSON catalogs, OS-locale detection,
`--lang` / `CTLD_LANG`) serving the CLI's validation messages.

## Work

**Catalogs.** 90 `web.*` keys added to `ctld_tools/data/locales/{en,fr}.json`. The `web.` prefix keeps
the web app's strings distinct from the retired TUI's `tui.*`. Counted strings ship as `.one` / `.many`
pairs rather than a naive `+ 's'`.

**Backend.**
- `i18n.py` gains `available_languages()` and `catalog_keys(prefix=…)`.
- `GET /api/i18n?lang=` → `{ lang, available, strings }`, restricted to the `web.*` slice.
- `GET /api/schema?lang=` translates setting descriptions, table-field headings and family
  labels/descriptions — switching language translates the *settings*, not just the chrome.

**Frontend.**
- `strings.ts` holds the EN dictionary (needed before any fetch: first paint and the boot-failure
  path must never show raw keys); `i18n.svelte.ts` provides reactive `t()` / `plural()` /
  `setLanguage()` and layers the backend's translations on top.
- A language picker in the header, remembered in `localStorage` — the OS locale is only the first
  guess, and someone on an English Windows may well want the French UI. Switching re-fetches the
  schema.
- Every component moved off the old `UI.*` literals.

**Guarding the duplication.** EN living in both the frontend and the backend catalog is a real
duplication, so `i18n.parity.test.ts` reads the JSON catalogs from disk and fails the build if: the
key sets diverge, an EN text differs, FR is missing a key, a placeholder is dropped in translation, a
plural pair is half-defined, or an FR string is still identical to EN outside a known short list.

## Known limit

**Setting names stay English.** They are derived from the config key (`humanize`), and translating
them means authoring a `label:` for ~136 settings — the same job as ticket 10 but an order of
magnitude bigger. A French MM sees an English name + the **French description** + the raw key. Noted
on `dev/roadmap.md`.

## Done when

- The whole chrome, family labels/descriptions and setting descriptions render in FR.
- Language survives a restart; an unknown `lang` falls back to EN.
- Backend tests pin the language explicitly (without `?lang=` the endpoint follows the OS locale,
  which differs between a dev machine and CI — caught while writing these tests).
