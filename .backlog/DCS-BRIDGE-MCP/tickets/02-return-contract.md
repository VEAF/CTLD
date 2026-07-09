# 02 — Freeze the scenario return contract

Status: ✅ done
Type: AFK

## What to build

Formalise the bridge-era return contract described in the PRD and encode it as reusable helpers,
so templates and migrated scenarios all emit the same parsable verdict.

Contract (see PRD §Return contract for rationale):

- Verdict strings: `<TAG> PASS <p>/<t>`, `<TAG> FAIL <f>/<t>: <reasons>`, `<TAG> ABORT: <msg>`,
  `<TAG> RUNNING`, `<TAG> STARTED`.
- Global result variable `_G["_SCN_<ID>_RESULT"]`, updated to the current verdict.
- Synchronous scenarios `return` the final verdict; asynchronous ones `return "<TAG> STARTED"`
  and update `_G[...]` when they finish.

Provide a small helper block (verdict formatter + result-variable setter) that scenarios reuse,
and document the contract in one place (the `integration-testing` skill).

## Acceptance criteria

- [ ] Contract documented verbatim (grammar for each verdict string).
- [ ] A helper produces the verdict string from `passed/failed/failReasons` and writes
      `_G["_SCN_<ID>_RESULT"]`.
- [ ] Grammar is unambiguous to parse (fixed prefix, deterministic separators).
- [ ] Covers the async case (STARTED + polled result variable).

## Blocked by

None — this is the spec the rest of the lot depends on.
