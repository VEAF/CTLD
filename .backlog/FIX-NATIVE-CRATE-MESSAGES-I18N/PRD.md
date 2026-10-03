# FIX-NATIVE-CRATE-MESSAGES-I18N — the four native-crate player messages are not translated

**Status:** ⬜ ready

Formalizes the `dev/roadmap.md` entry "Caisses — message anglais en dur « Crate loaded (parachute-ready) »",
raised by the automated code review of `develop` (issue #236) and left out of
`FIX-DCS-OBJECT-NAME-COMPARISON`. Scope decided 2026-10-03: the roadmap named one message, the code has four with
the same defect in the same block, and all four are fixed.

## Problem Statement

When a crate is loaded into, or released from, an aircraft through DCS's own cargo UI, CTLD tells the pilot with
an on-screen message. Four of those messages are built with `string.format` and never go through `ctld.tr`:

- "[CTLD] Crate loaded (parachute-ready): %s" — the load is handed over to CTLD;
- "[CTLD] Crate loaded (DCS native): %s" — the load stays DCS-managed;
- "[CTLD] Crate falling (DCS native parachute): %s" — a native release in flight;
- "[CTLD] Crate unloaded (DCS native): %s" — a native release on the ground.

A French, Spanish or Korean pilot sees them in English, next to translated messages. They also escape the
`pre-push` hook that checks the i18n dictionaries, which only sees keys passed through `ctld.tr`, which is why
they survived.

## Solution

The four messages go through `ctld.tr` with the crate label as a positional parameter, like their neighbours,
and each gets a key in the four dictionaries (EN, FR, ES, KO) with a translation. The English text a pilot sees
is unchanged.

## User Stories

1. As a pilot playing in French, I want the "crate loaded (parachute-ready)" message in French, so that I
   understand what CTLD did with my DCS-loaded crate.
2. As a pilot playing in French, I want the "crate loaded (DCS native)" message in French, so that I know the
   crate stays under DCS management.
3. As a pilot playing in French, I want the "crate falling (DCS native parachute)" message in French, so that I
   understand a released crate is descending.
4. As a pilot playing in French, I want the "crate unloaded (DCS native)" message in French, so that ground
   release is clear.
5. As a Spanish-speaking pilot, I want the same four messages in Spanish, so that I am not left with English.
6. As a Korean-speaking pilot, I want the same four messages in Korean, so that I am not left with English.
7. As an English-speaking pilot, I want the messages exactly as they are today, so that nothing changes for me.
8. As a pilot, I want the crate's label to appear in the translated message, so that I know which crate it is.
9. As a mission maker overriding a translation in `CTLD_userConfig.lua`, I want these messages to be
   overridable like any other, so that I can adapt the wording.
10. As a CTLD developer, I want the four strings to be dictionary keys, so that the `pre-push` hook and the CI
    dictionary guard cover them.
11. As a CTLD developer, I want a test per message that switches the language and checks the translated text, so
    that a message going back to a hard-coded string is caught.
12. As a maintainer, I want the roadmap entry removed once the work lands and a CHANGELOG entry added, so that
    the roadmap lists only open work.

## Implementation Decisions

- The four messages use `ctld.tr` with the label as `%1`; the leading `[CTLD]` prefix stays in the text, like
  the existing `"[CTLD] Zone validation …"` keys. English text unchanged apart from `%s` becoming `%1`.
- Four keys added to the dictionaries; the build adds them (empty in FR/ES/KO) and the translations are filled
  in by hand: French "Caisse chargée (prête pour le parachutage)", "Caisse chargée (natif DCS)", "Caisse en
  chute (parachute natif DCS)", "Caisse déchargée (natif DCS)"; Spanish and Korean equivalents. Wording is a
  proposal for the maintainer to review.
- No behaviour change besides the language of the text: the conditions that select a message, its duration and
  its recipient are untouched. No config, schema or catalogue change.
- Only these four messages. Other English strings, if any, are out of scope.

## Testing Decisions

- A good test observes the text the pilot would see for a given language, not the call that produced it.
- Seam: the existing native-cargo functional spec (the on-board cargo list harness, which already drives load,
  conversion and release with a stubbed message sink). Four new cases with the active language set to French:
  a native load, a conversion (the delayed CTLD load), a release on the ground and a release in flight, each
  asserting the exact French text including the crate label. Written first and seen failing (the hard-coded
  English comes out). One English control case keeps the unchanged text for English.
- The dictionary guard (CI) and the `pre-push` hook cover the keys once they exist.
- No live-DCS test: the change is the language of a string.

## Out of Scope

- Any other hard-coded English string, and the wording of existing translations.
- The duplicate crate-state predicates (separate roadmap entry).

## Further Notes

Source: `dev/roadmap.md` entry "Caisses — message anglais en dur « Crate loaded (parachute-ready) »" (from issue
#236's review). No GitHub issue to close.
