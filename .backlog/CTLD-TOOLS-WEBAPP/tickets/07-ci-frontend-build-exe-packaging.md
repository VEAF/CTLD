# 07 — CI frontend build + exe packaging

Status: ✅ done
Type: build + CI

> FastAPI serves the built static at `/` (mount added last so `/api` wins); resources resolve from
> `sys._MEIPASS` when frozen. Verified locally in single-server mode (index.html + assets + API from
> one uvicorn). The PyInstaller exe build runs at CI (`release.yml` build-exe); the double-click /
> boot smoke is the maintainer's manual test.

The MM never needs Node: the frontend is **built at CI** and bundled as static assets served by
FastAPI; the console exe is built and attached to Releases (ADR 0011 point 8).

- `release.yml` (isolated job): set up Node, `npm ci && npm run build` in `tools/ctld-tools/web/`,
  copy the built assets into the package (`ctld_tools/web/static/`), then PyInstaller a
  **single console-mode** exe (no `--noconsole`) and attach it to the Release.
- FastAPI serves the bundled static assets at `/` (the ticket-01 stub is populated here).
- Verify the exe boots the app on double-click semantics (smoke) as VMCT does; the CLI
  (`embed`/`validate`/`gen`) still runs headless.
- `python-quality` / `ci.yml` unaffected (no Node needed for the Python gate).

Files: `.github/workflows/release.yml`, `ci.yml` (if needed), `pyproject` build group,
`tools/ctld-tools/web/**`. Depends on: 01, 03.
