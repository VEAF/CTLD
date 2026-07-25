# 03 — Build embeds configDefault YAML string

Status: ✅ done
Type: build + src

> **Scope note (done):** the additive half landed here — the build embeds `ctld.configDefault`
> and busted round-trips it. **Dropping `gen-config` / `__configDefaults` is deferred to ticket 04**:
> the runtime `load()` and the busted loader still consume `__configDefaults` until the loader
> switches to `configDefault` in 04. Removing it here would break every test (no green commit).

The build stops generating a Lua defaults **table** and instead embeds the canonical YAML **string**.

- `merge_CTLD.ps1` emits a Lua module setting `ctld.configDefault` (name per PRD) to the verbatim
  contents of `src/CTLD_config.yaml` as a long-bracket string `[[ ... ]]` (guard against `]]` in the
  YAML; use a `[==[ ]==]` level if needed). Merged **after** the `CTLD_i18n_*` modules (the parsed
  table evaluates `ctld.tr(...)` at load).
- **Drop** the `ctld-tools gen-config` call from the build (the generated `CTLD_config_defaults.lua`
  Lua-table artifact disappears). Python is still needed by the build for other steps until lot 2.
- No behaviour yet — this ticket only makes the string available; the loader consumes it in 04.

Files: `tools/build/merge_CTLD.ps1`, `listToMerge.txt` / merge order, `.gitignore` (drop the old
generated artifact). Test: the merged `CTLD.lua` contains a parseable `ctld.configDefault` whose
`parseYAML` round-trip matches the reference (reuse 02's parity harness).
Depends on: 02.
