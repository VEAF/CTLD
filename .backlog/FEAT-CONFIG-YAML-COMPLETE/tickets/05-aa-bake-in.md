# 05 — AA bake-in + injection-loop removal (last lupa use)

Status: ✅ done
Type: src + build + test

> **Scope note (done):** AA crates expanded once (via `load_default_settings(inject_aa=True)`) and
> written to `CTLD_config.yaml` (`SAM mid range` 21 + `SAM long range` 13 entries), **golden-compared**
> to the old injection output (identical). `injectAACrates` + its `ctld.initialize()` call site removed.
> **`TEMPLATES` kept** (decision A, validated with David): the runtime assembly still needs the
> assembly rules (parts/count/launcher/name), which are NOT in the YAML — so `TEMPLATES` moves from
> `CTLDConfig:load()` to a static declaration in `CTLD_aasystem.lua` rather than being deleted.
> `mixedSet` block style used (the runtime parser has no non-empty flow-list support).

AA crates become ordinary catalogue entries in the YAML instead of being generated at runtime.

- **Expand once**: run `CTLDCrateAssemblyManager.injectAACrates` / `TEMPLATES` a single time (via
  `lupa`, or a one-shot Python/Lua script) and write the resulting crate entries — per-part crates,
  auto `mixedSet` "All crates", repair crate, with `ctld.tr(...)` on text — into
  `src/CTLD_config.yaml` under their sections. Commit the expanded YAML.
- **Delete** the runtime injection path: `injectAACrates`, the `TEMPLATES` materialisation, and its
  call site in `ctld.initialize()`. The runtime assembly/spawn behaviour (`spawnSystemAt`, etc.)
  stays — only the **catalogue materialisation** moves to build/data.
- This is the **last use of `lupa`** in the runtime/build (its dependency removal + the dead
  `extract`/`gen-config`/`gen-reference` commands are lot 2).
- mixedSet consistency (every referenced weight exists) is validated by the tool in lot 2; here,
  assert the baked entries match what the loop produced (golden compare of the pre/post catalogue).

Files: `src/CTLD_config.yaml`, `src/CTLD_aasystem.lua`, `src/CTLD_bootstrap.lua`/init site,
`tests/ci/**`. Existing AA scenarios must stay green. luacheck/lua5.1 clean.
Depends on: 04.
