Status: ready

# 03 — Intégration merge_CTLD.ps1

## What to build

After the `generate_i18n_dicts.ps1 -Apply` block in `merge_CTLD.ps1`, add a conditional block
that runs `translate_i18n.py` if `$env:ANTHROPIC_API_KEY` is set.

Behaviour:
- If `ANTHROPIC_API_KEY` absent → skip silently (no output).
- If `ANTHROPIC_API_KEY` present but `python` not found → WARNING, build continues.
- If `python` found but `translate_i18n.py` absent → WARNING, build continues.
- If script runs → log the result (e.g. "Translated: 12 key(s) in fr, 8 in es, 0 in ko").
- Any non-zero exit code from the script → WARNING, build continues (never `exit 1`).

## Acceptance criteria

- [ ] Block is placed after `generate_i18n_dicts.ps1 -Apply`, before the merge loop
- [ ] `ANTHROPIC_API_KEY` absent → no output, build unaffected
- [ ] `ANTHROPIC_API_KEY` present + python absent → WARNING line, build continues
- [ ] `ANTHROPIC_API_KEY` present + script error → WARNING line, build continues
- [ ] `ANTHROPIC_API_KEY` present + success → log line with per-language key counts
- [ ] Manual end-to-end test: set key, run `merge_CTLD.ps1`, verify stubs are filled

## Blocked by

- `02-translate-i18n-py.md`
