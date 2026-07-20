# 01 — Embedded reference catalogue (lupa build-time-only)

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Make the reference catalogue **embeddable** so the tool works without `src/`:

- New build step **`gen-reference`** (lupa): from `src/`, produce a bundled data file (JSON) holding
  the catalogue needed to resolve/validate — crates **including AA-injected** ones, troop-group
  names, array-setting names, and the crate name→weight index.
- **`Reference.from_embedded()`**: reads the bundled catalogue. Becomes the **default** for `validate`
  and `gen-user` (and the TUI); `--src` → `from_src` stays as a dev override.
- Move **lupa to the `build`/dev dependency group** — the runtime (MM `.exe`) must not import it.
  Only `gen-reference` (build/dev) uses lupa.
- Record the shift as a note on **ADR 0009** (embedded reference + lupa build-time-only).

## Acceptance criteria

- [ ] `gen-reference` produces the bundled catalogue from `src/` (AA crates included).
- [ ] `Reference.from_embedded()` resolves identically to `from_src()` (crate name→weight, troops, arrays).
- [ ] `validate` / `gen-user` run with **no `--src`**; `--src` still works as override.
- [ ] Runtime imports (TUI/validate/gen-user default path) do **not** import lupa.
- [ ] pytest: parity `from_embedded` == `from_src`; golden on the generated bundle.
- [ ] ADR 0009 note added.

## Blocked by

None (extends `CTLD-TOOLS-USERCONFIG`).
