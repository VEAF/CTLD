# FIX-CONFIG-LABELS-I18N-LANG

**Status:** merged (PR #314). Compacted from `FIX-CONFIG-LABELS-I18N-LANG/` on 2026-11-23; the ticket files live on in git history.

Issue #310 (VMCT): the `desc` / `name` labels of the configuration were translated before the settings were filled, so they followed the global language and ignored the snapshot's own `i18n_lang` (an English mission with `i18n_lang: fr` got a French menu and English labels). They are now translated after the settings are in place.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-translate-the-labels-after-the-settings` | ✅ done (PR #314) | 01 — Translate the labels of the configuration after the settings are in place |

## PRD

## FIX-CONFIG-LABELS-I18N-LANG — the labels of the configuration ignore the configuration's own `i18n_lang`

**Status:** ✅ done (PR #314)

GitHub issue #310 (reported by VMCT), decided with the maintainer on 2026-11-18.

### Problem Statement

A mission maker writes `i18n_lang: fr` in the mission's `ctld-config.yaml`. The setting is explicit; the guide of the host project says it wins, "c'est voulu". It does, for every text CTLD shows: the F10 menu, the messages.

It does not win for the **labels of the configuration**: the descriptions of crates and groups, the names of aircraft — every `desc` and `name` string, which are translation keys. They come out in the **global** language instead, the one a host script aligns on the mission's own language. A mission in English with `i18n_lang: fr` therefore gets a French menu and English crate and group labels, side by side.

The cause is the order of the load: CTLD translates the labels **before** it fills the settings. At that moment the language lookup cannot see the snapshot's `i18n_lang` yet, so it falls back to the global language.

### Solution

The labels are translated after the settings are in place, so they follow the snapshot's `i18n_lang` like every other text. A snapshot that sets no `i18n_lang` keeps using the global language, as today.

### User Stories

1. As a mission maker, I want the labels of my configuration in the language I set with `i18n_lang`, so that the menu and the labels agree.
2. As a mission maker, I want an explicit `i18n_lang` to win over the language a host script aligned on the mission, so that my choice is not overridden.
3. As a mission maker whose snapshot sets no `i18n_lang`, I want nothing to change, so that the global language still applies.
4. As a mission maker running on the default configuration (no snapshot), I want nothing to change.
5. As a host-project maintainer (VMCT), I want the sentence of my guide ("your explicit `i18n_lang` wins") to be true for the labels too, so that I do not have to name an exception.
6. As a CTLD developer, I want a test that sets a snapshot language different from the global one, in both directions, so that the order of the load cannot regress.

### Implementation Decisions

- The load fills the settings first, then translates the labels. The label tables are shared with the settings, so translating them in place translates what the settings hold.
- The default lists a snapshot lacks (the version-gap block) were already translated after the settings were filled: unchanged.
- `i18n_lang` stays out of the engine catalogue on purpose (it is a bare global read by the translation function; a snapshot that sets it lands in the settings): so a snapshot without it still falls back to the global language.
- No new message, no translation key, no configuration or catalogue change.

### Testing Decisions

- A good test observes the label a loaded configuration holds, not how the load is organised.
- Seam: the configuration unit spec, which already loads snapshots. Three cases: a snapshot with `i18n_lang: fr` and a global `en` gives the French label; a snapshot with `i18n_lang: en` and a global `fr` gives the English one; a snapshot with no `i18n_lang` and a global `fr` gives the French one (control, unchanged). The spec loads the French dictionary itself (the test loader only loads English).
- The two first cases fail before the change and pass after it; every existing case passes unchanged.
- Not run in DCS: the load order is fully covered by the unit spec.

### Out of Scope

- The second half of the issue, the sentence of the VMCT guide (`GUIDE.md`, `GUIDE.en.md`): it lives in VEAF-Mission-Creation-Tools. After this fix it is true as written.
- Re-translating labels when the language changes after the load (they are translated once, at load).

### Further Notes

The issue suggested either reading `i18n_lang` from the snapshot before translating, or translating after the settings are filled. The second is the smaller change and reuses the lookup every other text already goes through.
