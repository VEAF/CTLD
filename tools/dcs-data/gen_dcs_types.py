#!/usr/bin/env python3
"""Generate the vendored set of known DCS unit/static type names.

Source: the ``Quaggles/dcs-lua-datamine`` repository, pinned at ``DATAMINE_REF``
for reproducibility. In that dump, every unit under ``_G/db/Units/**`` is one
file whose basename (minus ``.lua``) is exactly the DCS spawn ``type`` id (e.g.
``BMP-2.lua`` -> ``"BMP-2"``). So the type-name set is just the set of those
basenames -- no Lua parsing required.

Output: ``tests/data/dcs_types.lua`` -- a Lua module returning a lookup set
``{ ["BMP-2"] = true, ... }``. It is used ONLY by the offline config linter
(``tests/ci/unit/config_types_lint_spec.lua``); it is NOT part of the shipped
``CTLD.lua`` (never added to ``tools/build/listToMerge.txt``).

Usage (from repo root): ``python tools/dcs-data/gen_dcs_types.py``
To refresh against a newer DCS dump: bump ``DATAMINE_REF``, re-run, commit.
The CI does not run this (network); it is a manual maintenance tool.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

DATAMINE_REPO = "https://github.com/Quaggles/dcs-lua-datamine.git"
DATAMINE_REF = "dc7d15e8e34150441b109346eea4ca18eb0104a7"  # pinned; bump to refresh
UNITS_PATH = "_G/db/Units"

_REF_RE = re.compile(r"^[0-9A-Za-z._/-]+$")
_REPO_ROOT = Path(__file__).resolve().parents[2]
_OUT = _REPO_ROOT / "tests" / "data" / "dcs_types.lua"
# Machine-readable copy embedded in the ctld-tools package (used by `validate`
# and bundled into the MM .exe). Generated from the same run to stay in sync.
_JSON_OUT = _REPO_ROOT / "tools" / "ctld-tools" / "ctld_tools" / "data" / "dcs_types.json"


def _run(args: list[str], cwd: Path) -> None:
    # Safe: fixed git argv list (no shell=True), and all dynamic values (ref, sparse
    # paths) are validated against _REF_RE by the callers before reaching here.
    subprocess.run(  # nosemgrep: python.lang.security.audit.dangerous-subprocess-use-audit
        args, cwd=cwd, check=True, stdout=subprocess.DEVNULL
    )


def clone_units(dest: Path, ref: str = DATAMINE_REF) -> Path:
    """Sparse + partial clone of ``_G/db/Units`` at the pinned ref."""
    if not _REF_RE.match(ref):
        raise ValueError(f"Unsafe datamine ref: {ref!r}")
    _run(["git", "init", "-q"], dest)
    _run(["git", "remote", "add", "origin", DATAMINE_REPO], dest)
    _run(["git", "config", "core.sparseCheckout", "true"], dest)
    _run(["git", "config", "extensions.partialClone", "origin"], dest)
    _run(["git", "sparse-checkout", "set", UNITS_PATH], dest)
    _run(["git", "fetch", "-q", "--depth", "1", "--filter=blob:none", "origin", ref], dest)
    _run(["git", "checkout", "-q", "FETCH_HEAD"], dest)
    return dest / UNITS_PATH


def collect_types(units_dir: Path) -> dict[str, str]:
    """Map each spawn type id to its datamine category.

    The unit files are <Category>/<Type>/<TypeName>.lua, so the category is the first path
    component. It used to be discarded; ctld-tools needs it to resolve the `spawnAs: AIR`
    authoring convenience to the AIRPLANE or HELICOPTER the engine expects at spawn.

    Some categories also dump numeric-indexed helper files (0.lua, 1.lua, ...) that are not
    spawn type ids. Drop purely-numeric basenames; keep everything else (inclusive by design — a
    lenient allow-set must not miss real types).
    """
    out: dict[str, str] = {}
    for path in sorted(units_dir.rglob("*.lua")):
        if path.stem.isdigit():
            continue
        parts = path.relative_to(units_dir).parts
        category = parts[0] if len(parts) > 1 else ""
        previous = out.get(path.stem)
        if previous is not None and previous != category:
            # A type id under two categories makes the spawn-category lookup ambiguous.
            print(f"WARNING: {path.stem!r} in both {previous!r} and {category!r}", file=sys.stderr)
        out[path.stem] = category
    return out


def render_lua(names: list[str], ref: str) -> str:
    lines = [
        "-- DCS type-name set (units + statics + heliports).",
        f"-- GENERATED from {DATAMINE_REPO} @ {ref}",
        "-- by tools/dcs-data/gen_dcs_types.py. DO NOT EDIT BY HAND.",
        "-- NOT shipped in CTLD.lua; used only by the offline config linter.",
        f"-- {len(names)} types.",
        "return {",
    ]
    for name in names:
        # Lua long-bracket-safe: names may contain quotes/backslashes; escape for a quoted key.
        key = name.replace("\\", "\\\\").replace('"', '\\"')
        lines.append(f'    ["{key}"] = true,')
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        dest = Path(tmp)
        units_dir = clone_units(dest)
        types = collect_types(units_dir)
    names = sorted(types)
    if not names:
        print("ERROR: no type names collected", file=sys.stderr)
        return 1
    _OUT.parent.mkdir(parents=True, exist_ok=True)
    _OUT.write_text(render_lua(names, DATAMINE_REF), encoding="utf-8", newline="\n")
    print(f"Wrote {_OUT.relative_to(_REPO_ROOT)} ({len(names)} types, ref {DATAMINE_REF[:8]})")
    _JSON_OUT.parent.mkdir(parents=True, exist_ok=True)
    # A mapping, not a list: the category is what resolves the `spawnAs: AIR` authoring
    # convenience to the AIRPLANE or HELICOPTER the engine expects.
    _JSON_OUT.write_text(
        json.dumps(dict(sorted(types.items())), ensure_ascii=False, indent=0),
        encoding="utf-8",
        newline="\n",
    )
    print(
        f"Wrote {_JSON_OUT.relative_to(_REPO_ROOT)} "
        f"({len(names)} types, {len(set(types.values()))} categories)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
