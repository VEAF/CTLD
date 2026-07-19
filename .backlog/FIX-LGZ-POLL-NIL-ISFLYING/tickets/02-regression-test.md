Status: ⬜ ready

# 02 — Regression test: LGZ poller processes player with _isFlying=nil

## What

Add a busted unit test (L1) that exercises the guard condition in `_lgzGroundPoll`
directly. The test verifies:

1. A player stub with `_isFlying = nil` **is** processed by the poller (zone key updated,
   `refreshRequestEquipmentSection` called).
2. A player stub with `_isFlying = true` (in-flight) is **skipped** (no refresh called).
3. A player stub with `_isFlying = false` (landed) is processed (no regression on the
   existing path).

## Where

`tests/unit/CTLD_crate_spec.lua` — add a describe block under the existing crate manager
tests, or create `tests/unit/CTLD_lgzPoll_spec.lua` if the pattern fits better as a
dedicated file. Follow the existing L1 pattern (stub out DCS globals, instantiate via
`getInstance()` or test the function logic directly).

## Acceptance

- Three sub-cases (`nil`, `true`, `false`) all pass.
- `busted tests/ci/` green.
- Coverage ratchet does not regress.
