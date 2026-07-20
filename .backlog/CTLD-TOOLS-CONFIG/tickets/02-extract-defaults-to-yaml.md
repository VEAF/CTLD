# 02 — One-shot extractor: `CTLD_config.lua` defaults → `ctld-config.yaml`

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

A documented **one-shot migration utility** that parses the `self.settings[...]` defaults block of
`src/CTLD_config.lua` and produces the initial **`ctld-config.yaml`**, sectioned **MM-facing** vs
**advanced/technical**. It must capture every value, type and structure verbatim (scalars, nested
tables, arrays, mixed key styles, numeric precision on `weight`/`side`), and record the i18n fields
(`desc`, `name`) in a way the generator (ticket 03) can turn back into `ctld.tr("…")`.

This utility is **not** a perennial build command — it runs once to seed the YAML. Its correctness is
proven by the parity test (ticket 04), not by asserting its own output.

`ctld-config.yaml` is committed as the source of truth.

## Acceptance criteria

- [ ] Produces `ctld-config.yaml` covering the full current defaults block, sectioned MM-facing vs advanced.
- [ ] i18n text fields flagged so the generator can re-emit `ctld.tr(...)`.
- [ ] No value/type/structure lost or coerced (verified via ticket 04).
- [ ] Documented as a one-shot migration utility (README + docstring), not part of the build.
- [ ] `ctld-config.yaml` committed.

## Blocked by

Ticket 01.
