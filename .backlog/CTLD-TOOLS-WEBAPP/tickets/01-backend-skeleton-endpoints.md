# 01 — FastAPI backend skeleton + endpoint wrappers

Status: ✅ done
Type: tool (Python) + test

A **FastAPI** app whose endpoints are **thin wrappers over the lot-2 core** — no business logic
here (ADR 0011 point 7). Single user, ephemeral, **no DB / auth / migrations**.

- New `ctld_tools/web/` sub-package: `app.py` (FastAPI instance + routes), a small session-state
  holder for the currently-open catalogue (in-memory, single user).
- Endpoints wrapping lot 2: load a catalogue (`Catalog.load`/`loads`), read the flat settings +
  data, edit a setting (`Catalog.set`/`add_setting`/`remove`), save (`Catalog.save`/`dumps`),
  `validate` (schema + datamine + mixedSet), `version_gap`, and the schema metadata (`Schema`).
- Add `fastapi` + `uvicorn` to `pyproject` (main deps; the exe ships them). Keep the quality gate
  green (ruff/mypy). Static-asset mounting is a stub here (populated in ticket 07).
- Tests: FastAPI `TestClient` unit tests per endpoint — load→get→set→validate→save round-trip,
  version-gap on a stale config, error paths (unknown key, malformed YAML). No frontend.

Files: `ctld_tools/web/**`, `pyproject.toml`, `tests/**`. Depends on: lot 2 (core).
