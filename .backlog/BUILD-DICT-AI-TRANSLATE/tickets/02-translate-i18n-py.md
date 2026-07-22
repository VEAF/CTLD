Status: ready

# 02 — translate_i18n.py — script de traduction locale

## What to build

A standalone Python script `tools/build/translate_i18n.py` with a single dependency
(`tools/build/requirements-translate.txt` containing `anthropic`).

The script:
1. Reads the 4 dict files (`src/CTLD_i18n_*.lua`), identifies empty stubs by comparing each
   language against EN (a stub is a key whose value equals the EN value).
2. For each non-EN language with at least one stub (FR, ES, KO), makes one API call to Claude
   (`claude-haiku-4-5-20251001`) with a batch prompt: DCS/military context + EN dict + list of
   keys to translate → JSON response `{"key": "translation"}`.
3. Writes the translated values back into the dict Lua files in-place (UTF-8, no BOM).
4. On API error: prints a WARNING to stdout and exits with code 0 (non-blocking).
5. On missing/malformed JSON response: WARNING + leaves stubs untouched.

## Acceptance criteria

- [ ] Script exists at `tools/build/translate_i18n.py`
- [ ] `tools/build/requirements-translate.txt` lists `anthropic`
- [ ] Script correctly identifies empty stubs (value == EN value) vs already-translated keys
- [ ] One API call per language (not per key)
- [ ] Translated values are written back to the correct dict file, preserving Lua structure
- [ ] API error → WARNING printed, exit code 0, dict files unchanged
- [ ] Malformed JSON response → WARNING printed, dict files unchanged
- [ ] Script can be tested with a mock API (no real key required for unit tests)

## Blocked by

None — can start immediately.
