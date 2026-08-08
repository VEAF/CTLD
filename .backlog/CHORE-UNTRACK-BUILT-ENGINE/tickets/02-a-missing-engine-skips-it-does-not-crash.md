# 02 — A missing engine skips the test, it does not crash it

**Status:** todo
**Lot:** CHORE-UNTRACK-BUILT-ENGINE

## Problem

Found by removing `CTLD.lua` and running the suite: `test_web_app.py::test_inject_into_miz` fails
with `KeyError: 'injected'` instead of skipping. Its neighbours in `test_install.py` and
`test_resources.py` all carry `skipif(not (REPO / "CTLD.lua").is_file())`; this one does not.

Today the file is always there, so nobody sees it. Once it is generated rather than committed, a
contributor who clones and runs `pytest` before building gets an error that says nothing about the
actual cause — and the error is a `KeyError` deep in a response payload, not a message about a
missing engine.

## Change

Give it the same guard as its neighbours. If the endpoint should instead report the missing engine
to the caller, that is a different ticket — the install path already raises a message saying how to
build it (`resources.read_engine`), and this test is not the place to redesign that.

## Acceptance

- [ ] With no `CTLD.lua`, the suite reports skips and **zero failures**.
- [ ] With `CTLD.lua`, the test runs and asserts what it asserts today.
