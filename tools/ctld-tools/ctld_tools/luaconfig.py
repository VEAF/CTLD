"""Load the CTLD engine defaults by running CTLD_config.lua in-process (lupa).

`ctld.tr` is stubbed to identity so i18n keys (desc/name) are preserved verbatim.
Only the pure factory defaults are read (no user-YAML merge).
"""

from __future__ import annotations

from pathlib import Path

# lupa is imported lazily inside the functions below: it is a build-time dependency
# (this module runs CTLD_config.lua), and importing luaconfig must not pull it in — the
# MM .exe ships without lupa and never reaches these functions.

# Identity translator: keep the raw i18n key (do not resolve/translate).
IDENTITY_TR = "function(key, default) return default or key end"

_BOOTSTRAP = """
ctld = ctld or {{}}
ctldLogPath = ""
dofile("{src}core/class.lua")
-- CTLDCrateAssemblyManager must exist before load() (load sets its TEMPLATES).
dofile("{src}CTLD_aasystem.lua")
dofile("{src}CTLD_config.lua")
ctld.tr = {tr}
-- Complete-config model (ADR 0011): load() parses ctld.configDefault, the engine
-- YAML embedded verbatim; it applies ctld.tr to desc/name at load time.
do
    local fh = assert(io.open("{src}CTLD_config.yaml", "r"))
    ctld.configDefault = fh:read("*a")
    fh:close()
end
CTLDConfig.get():load()
"""


def _to_py(value):
    """Recursively convert a lupa Lua value into plain Python dict/list/scalars.

    A Lua table with keys exactly 1..n becomes a list; otherwise a dict.
    (Lua 5.x makes no array/dict distinction, so a `{[1]=..,[2]=..}` table maps
    to a list — semantically identical once regenerated for Lua 5.1.)
    """
    import lupa

    if lupa.lua_type(value) != "table":
        return value
    keys = list(value.keys())
    if keys and all(isinstance(k, int) for k in keys) and set(keys) == set(range(1, len(keys) + 1)):
        return [_to_py(value[i]) for i in range(1, len(keys) + 1)]
    return {_to_py(k): _to_py(value[k]) for k in keys}


def load_default_settings(src_dir: str | Path, tr: str = IDENTITY_TR, inject_aa: bool = False) -> dict:
    """Run CTLD_config.lua and return its default `settings` table as Python data.

    `tr` is the Lua body of ctld.tr (defaults to identity, preserving i18n keys).
    Tests can pass a distinctive translator to prove the desc/name wrappers are
    actually emitted by the generator.

    `inject_aa` runs CTLDCrateAssemblyManager.injectAACrates() so `spawnableCrates`
    includes the AA-system crate sections (needed to resolve/validate AA crate names).
    """
    import lupa

    src = str(src_dir).replace("\\", "/")
    if not src.endswith("/"):
        src += "/"
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(_BOOTSTRAP.format(src=src, tr=tr))
    if inject_aa:
        # injectAACrates logs via ctld.utils.log; stub it (utils isn't loaded here).
        lua.execute("ctld.utils = ctld.utils or {}; ctld.utils.log = ctld.utils.log or function() end")
        lua.execute("CTLDCrateAssemblyManager.injectAACrates(CTLDConfig.get().settings.spawnableCrates)")
    settings = lua.eval("CTLDConfig.get().settings")
    result = _to_py(settings)
    if not isinstance(result, dict):
        raise RuntimeError("CTLDConfig settings did not resolve to a table")
    return result
