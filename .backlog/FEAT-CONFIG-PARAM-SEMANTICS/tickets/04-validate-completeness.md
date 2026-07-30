# 04 — `validate`: a missing parameter is an ERROR

**Status:** done

Independent of 02 / 03 — different layer, can be built in parallel.

> `validate()` gains an injected `default: Catalog | None`, mirroring the existing `types` parameter so
> the function stays pure; the check is skipped when it is absent. Path resolution stays in the callers
> (`cli.py` via `resources.default_catalog_path()`, `web/app.py` via `session.default_catalog()`) rather
> than in the core module.
>
> **`test_web_app.py` needed a fix this ticket caused.** Its `SAMPLE` fixture is a 3-setting snapshot,
> so `test_validate_clean_and_bad_unit`'s `hasErrors is False` would have started failing. The clean
> assertion now loads the default catalogue — the only genuinely complete subject — and the tiny fixture
> became the vehicle for a new test asserting an incomplete catalogue *is* reported.
>
> **Verified, including through the packaged exe.** `fastapi` and `httpx` were missing from the local
> venv (`poetry install` cannot reach pypi.org, but `pip` has a working internal index), so they were
> installed at their `poetry.lock` versions — **164 tests pass**, `test_web_app.py` included, and ruff
> check + format are clean. The frontend and `ctld-tools.exe` then built with the CI recipe, and
> `GET /api/validate` on the default catalogue, served by the exe, returns
> `{"hasErrors":false,"findings":[]}` — the completeness rule produces no false positive on the real
> shipped catalogue.

## Why

`validate` checks crate weights, unknown DCS unit types and schema `choices`. It never checks that
the document is **complete**, so a config authored against an older catalogue exports cleanly and
then relies on the engine's net. The tool should catch it first, at design time, where the MM can act
on it — `version-gap` already detects the version lag and offers re-migration.

`ERROR` is the right severity: errors block export (`has_errors()` — [validate.py:10](../../../tools/ctld-tools/ctld_tools/validate.py#L10)),
and an incomplete document is not something to bless. The engine still survives it (ticket 02),
because nothing forces an MM to run the tool at all.

## What changes

- New rule in `tools/ctld-tools/ctld_tools/validate.py`: for every key in the **default** catalogue
  whose value is a scalar, the catalogue under validation must have it. Missing → one `Finding` per
  key, severity `ERROR`, new i18n key (e.g. `validate.parameter.missing`).
- The classifier lives with the rule: scalar default → parameter. `Catalog.keys()` is one flat
  namespace ([catalog.py:68](../../../tools/ctld-tools/ctld_tools/catalog.py#L68)) and does not
  distinguish the two, so derive the tier from the default's value shape — same rule as the engine, so
  the two layers cannot disagree.
- Add the EN + FR strings to `ctld_tools/data/locales/`.

**Key off the default catalogue, never the schema.** `i18n_lang` is declared in
`CTLD_config_schema.yaml` but deliberately **absent from the default catalogue** — the schema says so
in a comment at [line 29](../../../src/CTLD_config_schema.yaml#L29): it is a bare `ctld.i18n_lang`
global that lands in `settings` and wins through `ctld.gs()`. A completeness rule driven by the schema
would demand it and fail every valid config. The engine has the same rule for the same reason.
- Surface it in the web app's validation panel like any other error; no bespoke UI.

## Acceptance

- A catalogue missing one scalar key → one ERROR naming that key; export blocked.
- A catalogue missing `spawnableCrates` entirely → **no** finding. Removing a list is legitimate.
- A complete catalogue → no new findings.
- The tool's classifier and the engine's agree on every key of the shipped catalogue.

## Tests

- pytest: missing scalar → ERROR; missing collection → clean; complete → clean.
- pytest: a parity test asserting the tool's parameter set equals the engine's, computed from the
  same default catalogue, so the two tiers cannot drift.
- pytest: EN/FR locale parity for the new key (the existing `i18n.parity` guard should cover it).
