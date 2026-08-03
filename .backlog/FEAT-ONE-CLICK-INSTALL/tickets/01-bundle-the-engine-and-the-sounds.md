# 01 — the exe carries `CTLD.lua` and the two `.ogg`

**Status:** done

No dependency. Blocks 02.

## What changes

- **Release workflow**: three more `--add-data` entries next to the two that already bundle
  `CTLD_config.yaml` and `CTLD_config_schema.yaml` — `CTLD.lua`, `assets/beacon.ogg`,
  `assets/beaconsilent.ogg`, all into `ctld_data`.
- **A single accessor** for bundled payloads, next to whatever reads the bundled YAML today
  (`ctld_tools/web/resources.py` is where the packaged-resource logic lives — check before adding a
  second mechanism). It must work **both** frozen (PyInstaller `_MEIPASS`) and from a source
  checkout, because that is how the tests and `poetry run` see it.
- **`assets/*.ogg` become release assets too.** A Mission Maker doing it by hand cannot get them
  from the release today — they are repo-only. That is a one-line change in `release.yml` and it
  closes the gap for the manual path.

## Watch out

- `CTLD.lua` is a **build artifact**. From a source checkout it may be absent or stale; the accessor
  must fail with a clear message ("run `tools\build\merge_CTLD.ps1` first") rather than serve an
  empty string. The exe build always has it: the release workflow rebuilds before packaging.
- The exe grows from 21 MB to about 22.5 MB. Expected; not a regression to report.

## Acceptance

- `ctld-tools.exe` exposes the bundled engine and both sounds, byte-identical to the release assets.
- The same code path works under `poetry run` in a checkout.
- A checkout with no `CTLD.lua` gives a message naming the build script, not a stack trace.
- `beacon.ogg` and `beaconsilent.ogg` are attached to the release.

## Tests

- pytest: the accessor returns the engine's bytes and both sounds; sizes match the files on disk.
- pytest: a missing bundled engine raises the documented error, with the build command in the
  message.
- The existing exe smoke-check in `release.yml` gains an assertion that the payloads are present in
  the frozen build — a bundle that silently loses a `--add-data` entry must fail the release, not
  ship.
