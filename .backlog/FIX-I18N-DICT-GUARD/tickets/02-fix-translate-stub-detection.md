Status: ready

# 02 — Fix `translate_i18n.py` stub detection + test coverage for `tools/build/`

## Parent

`.backlog/FIX-I18N-DICT-GUARD/PRD.md` (ADR 0013)

## What to build

`translate_i18n.py`'s stub-selection logic currently treats a non-EN dictionary entry as
"untranslated" only when its value is identical to the English text (`lang_dict.get(k) == v`). But
`generate_i18n_dicts.ps1 -Apply` writes a freshly-added non-EN entry as an empty string (`""`), not
a copy of the English value — so a newly-added key is never selected for translation, with or
without `ANTHROPIC_API_KEY` set locally. Extend the predicate to also match an empty value, for any
key not listed in that dictionary's `__keep_en` block.

While making this testable, extract the dictionary-file parser currently private to
`translate_i18n.py` (`_parse_dict`) into a new small shared module, `tools/build/
i18n_dict_utils.py`. This module will also be consumed by ticket 03's diff-checker script, so both
tools rely on one parser rather than two that can drift apart.

This is also the first test coverage `tools/build/` has ever had, so this ticket wires up the test
runner: a new step in `python-quality.yml` (already triggered on `tools/build/**` changes) installs
pytest with plain `pip` (no poetry — matches the existing "pip only" decision for
`translate_i18n.py`) and runs `pytest tools/build/`.

## Acceptance criteria

- [ ] The dict-file parser is extracted into `tools/build/i18n_dict_utils.py` and reused by
      `translate_i18n.py` (no behavior change to parsing itself).
- [ ] `translate_i18n.py`'s stub-selection predicate treats a value of `""` as a stub needing
      translation, in addition to a value identical to the EN text.
- [ ] A key listed in a dictionary's `__keep_en` block is never selected as a stub, regardless of
      its value (empty or otherwise) — existing behavior preserved.
- [ ] Unit tests cover: empty value → stub; value identical to EN text → stub; a real translation →
      not a stub; a `__keep_en`-listed key → never a stub.
- [ ] Unit tests cover the extracted parser against representative dict-file text fixtures
      (well-formed entries, escaped quotes, a `__keep_en` block).
- [ ] `python-quality.yml` runs `pytest tools/build/` as part of its pipeline and the new tests
      execute (and pass) in CI, not only locally.
- [ ] Manually verified: running `translate_i18n.py` locally (with `ANTHROPIC_API_KEY` set) against
      a dictionary containing a freshly-added `""` entry results in that entry being sent for
      translation.

## Blocked by

None - can start immediately (parallel with ticket 01)
