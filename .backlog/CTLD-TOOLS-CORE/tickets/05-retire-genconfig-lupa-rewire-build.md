# 05 — Retire gen-config/lupa, rewire build + CI (the hard one)

Status: ✅ done
Type: tool (Python) + build + test

> **Decisions (validated with David):** `embed` is the YAML→Lua-string wrap, a single core
> function (`ctld_tools/embed.py`) reused by the build (`configDefault`) **and** the lot-3 MM
> export (`configUser`) — the wrap is business logic, so it lives here per the anti-duplication
> rule, and `merge_CTLD.ps1` calls `ctld-tools embed`. The `inject` CLI command is dropped (no
> CLI UX investment) but `miz.py` stays as a library for lot 3. The JSON oracle is committed at
> `tests/ci/data/config_defaults.json`; busted reads it via `dkjson` (added to the busted CI job).

Remove the last Lua-facing Python and drop `lupa`. Resolve the two dependencies `gen-config` still
served (deliberately kept through lot 1 for exactly these — see lot-1 tickets 04/05 scope notes).

- **Round-trip oracle (decision i, validated with David):** the busted parity test compares
  `parseYAML(YAML)` to a reference emitted by the **core (ruamel)** as JSON — committed and loaded by
  the test. An independent Python path replacing the `gen-config` `__configDefaults` Lua oracle.
- **i18n static source:** `generate_i18n_dicts.ps1` must scan the YAML `desc`/`name` values (not
  `config_defaults.lua`, which disappears) so the label keys stay tracked by the dict sync.
- **Build:** `merge_CTLD.ps1` stops calling `gen-config`; it already embeds the YAML string
  (`configDefault`, lot 1 t03). Drop the generated `CTLD_config_defaults.lua` artifact + its
  `.gitignore` / `listToMerge` / busted-loader references. CI (`ci.yml` busted job) drops `gen-config`
  and loads the JSON oracle instead.
- Delete `genconfig.py`, `genreference.py`, `extract.py`, `reference.json` + `Reference.from_src`,
  `luaconfig.py`; drop `lupa` from `pyproject`. Trim the CLI to `embed`/`validate`/`gen`.
  ruff/mypy/pytest + `python-quality` + busted CI green.

Files: `ctld_tools/{genconfig,genreference,extract,reference,luaconfig}.py`, `pyproject.toml`,
`tools/build/merge_CTLD.ps1`, `tools/build/generate_i18n_dicts.ps1`, `.github/workflows/ci.yml`,
`tests/ci/**`, `tests/**`. Depends on: 02, 03.
