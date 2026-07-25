# 06 — userSetup removal + version tag

Status: ✅ done
Type: src + build

> **Scope notes (done):**
> - `ctld.userSetup` + `CTLD_userSetup.lua` deleted; listToMerge, the `runUserSetup` dispatch in
>   bootstrap, the busted loader, and the userSetup specs removed. `CTLD_userConfig.lua` rewritten to
>   the `ctld.configUser` complete-YAML model. v1 Legacy API untouched.
> - **Version tag = top-level** (decision B): `configVersion: "2.0.0"` in `CTLD_config.yaml` +
>   `CTLD_config_schema.yaml`. Both `gen-config` (`_load_yaml`) and `CTLDConfig:load()` now merge the
>   `mm_facing`/`advanced` sections **plus** top-level keys, so `configVersion` lands in settings.
> - **genuser kept (decision B):** deleting it would cascade to the whole CLI edit chain (editmodel /
>   scaffold / cli `gen-user` / TUI). Only `test_genuser.py` (the one test executing the removed
>   `userSetup` runtime) is deleted. `genuser.py` carries a `⚠️ DEAD CODE` marker and the **lot 2
>   cleanup checklist** (in the PRD) lists the full gen-user/TUI chain for removal — so it is not
>   forgotten.

Close the demolition and stamp the version for the tool's re-migration flow.

- **Remove `ctld.userSetup`** and the helper API (`ctld.addCrate/removeCrate/patchCrate/`
  `addTroopGroup/removeTroopGroup/addTo/patchTroopGroup/logDefaults`) — delete
  `src/CTLD_userSetup.lua` and its merge-list entry + any bootstrap call of the callbacks. Clean
  break (pre-2.0.0, no released consumers). The **v1 Legacy API (ADR 0004) stays untouched**.
- Update `dist/CTLD_userConfig.lua` (the MM template) to the new model: a single mission-start
  trigger setting `ctld.configUser` to a complete YAML string (no more `userSetup` block / no
  `yamlConfigDatas`).
- **Version tag**: stamp a version on `src/CTLD_config.yaml` and `src/CTLD_config_schema.yaml`
  (a top-level `_version` / `configVersion` key — name per PRD), embedded through 03 so the runtime
  and a `configUser` can both carry it. The tool (lots 2/3) consumes it for the version-gap popup;
  this ticket only **stores/propagates** it.

Files: `src/CTLD_userSetup.lua` (delete), `listToMerge.txt`, `src/CTLD_bootstrap.lua`,
`dist/CTLD_userConfig.lua`, `src/CTLD_config.yaml`, `src/CTLD_config_schema.yaml`, `tests/ci/**`.
CHANGELOG `[Unreleased]`. Depends on: 04, 05.
