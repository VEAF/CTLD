# 01 — the tool reports the CTLD version, from one source

**Status:** todo

No dependency. Blocks 02 and 03.

## What changes

- The tool's version **is** `ctld.VERSION` — the same string `src/CTLD_config.lua` carries and the
  build stamps into `CTLD.lua`. Not a copy in `pyproject.toml` maintained by hand: that is how it
  drifted to `0.1.0` and stayed there. Read it from the bundled engine (or from `src/` in a
  checkout), the way the build already extracts it with a regex in `merge_CTLD.ps1`.
- `ctld-tools --version` prints it.
- The web API exposes it, and the frontend shows it where the user can find it (the help panel is the
  natural home — ticket 03).
- The literal `version="2.0"` in the FastAPI app declaration goes away.

## Watch out

- The regex must accept a pre-release suffix: `2.0.0-rc3`, not just `x.y.z`. The build's own pattern
  is `ctld%.VERSION%s*=%s*"([^"]+)"` — reuse that shape rather than a stricter semver pattern.
- From a source checkout with no built `CTLD.lua`, fall back to `src/CTLD_config.lua`. The tests run
  in exactly that situation.

## Acceptance

- `ctld-tools --version` prints the same string as `ctld.VERSION`.
- The API and the frontend show that string; grepping the frontend for a hardcoded version finds
  nothing.
- A pre-release version survives intact, suffix included.

## Tests

- pytest: the version accessor returns what `src/CTLD_config.lua` declares — no fixture copy of the
  number, read the real file, so a bump cannot desynchronise the test.
- pytest: a `2.0.0-rc3`-shaped version is returned whole.
- The exe smoke-check in `release.yml` asserts `--version` prints the release's version.
