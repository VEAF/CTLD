"""Inject the generated CTLD_userConfig.lua into a .miz as a MISSION START trigger.

A .miz is a zip; its `mission` file is a Lua table. DCS triggers live as parallel
per-category tables (`actions`, `conditions`, `funcStartup`, `flag`, …) indexed by
the same key, mirrored in `trigrules` (editor form). The index appears **inside** the
compiled action/func strings, so shifting triggers means rewriting those `[idx]`
references — the approach used by VMCT's mission builder, recreated here.

We insert a single inline `a_do_script` trigger at rank 1 (so it runs before other
triggers), idempotently (re-injection replaces the previous one, matched by comment).
"""

from __future__ import annotations

import re
import zipfile
from pathlib import Path

from ctld_tools.vendor import luadata

MARKER = "CTLD userConfig (ctld-tools)"
_TRIG_CATEGORIES = (
    "actions",
    "conditions",
    "func",
    "funcStartup",
    "custom",
    "customStartup",
    "events",
    "flag",
)


def read_mission(miz_path: str | Path) -> dict:
    with zipfile.ZipFile(miz_path) as z:
        text = z.read("mission").decode("utf-8")
    data = luadata.unserialize(text, keep_as_dict=["trig", "trigrules"])
    if not isinstance(data, dict):
        raise ValueError("mission file did not parse to a table")
    return data


def write_miz(mission: dict, in_path: str | Path, out_path: str | Path) -> None:
    """Rewrite `out_path` = `in_path` with the `mission` entry replaced.

    Writes to a temp file then replaces, so `in_path == out_path` (overwrite) is safe.
    """
    body = "mission = \n" + luadata.serialize(mission, indent="\t")
    out_path = Path(out_path)
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    with zipfile.ZipFile(in_path) as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            if item.filename != "mission":
                zout.writestr(item, zin.read(item.filename))
        zout.writestr("mission", body.encode("utf-8"))
    tmp.replace(out_path)


def _escape_lua_string(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")


def _pivot(trig: dict) -> dict:
    """{category: {id: value}} -> {id: {category: value}} (ids from `actions`, the complete one)."""
    ids = sorted(int(k) for k in trig.get("actions", {}))
    out: dict[int, dict] = {}
    for tid in ids:
        out[tid] = {cat: trig.get(cat, {}).get(tid) for cat in _TRIG_CATEGORIES if cat in trig}
    return out


def _unpivot(pivoted: dict) -> dict:
    trig: dict[str, dict] = {}
    for tid, cats in pivoted.items():
        for cat, val in cats.items():
            if val is not None:
                trig.setdefault(cat, {})[tid] = val
    return trig


def _rewrite_indices(cats: dict, old_id: int, new_id: int) -> dict:
    """Rewrite `[old_id]` -> `[new_id]` inside the string-valued categories (compiled code)."""
    if old_id == new_id:
        return cats
    return {
        cat: (re.sub(rf"\[{old_id}\]", f"[{new_id}]", val) if isinstance(val, str) else val)
        for cat, val in cats.items()
    }


def inject_userconfig(miz_path: str | Path, userconfig_lua: str, out_path: str | Path) -> None:
    """Inject `userconfig_lua` as a MISSION START inline-script trigger at rank 1.

    Idempotent: a previously injected trigger (matched by comment == MARKER) is removed
    first, so re-running updates rather than duplicates.
    """
    mission = read_mission(miz_path)
    trig = mission.get("trig") or {}
    trigrules = mission.get("trigrules") or {}

    # 1. Drop any previously injected trigger (idempotence), by its trigrules comment.
    stale_ids = {int(k) for k, r in trigrules.items() if isinstance(r, dict) and r.get("comment") == MARKER}

    # 2. Pivot trig, drop stale, renumber survivors starting at 2 (rank 1 is ours),
    #    rewriting the in-code [idx] references.
    pivoted = {tid: cats for tid, cats in _pivot(trig).items() if tid not in stale_ids}
    renumbered: dict[int, dict] = {}
    for new_id, old_id in enumerate(sorted(pivoted), start=2):
        renumbered[new_id] = _rewrite_indices(pivoted[old_id].copy(), old_id, new_id)

    # 3. Our new trigger at id 1.
    escaped = _escape_lua_string(userconfig_lua)
    renumbered[1] = {
        "actions": f'a_do_script("{escaped}");',
        "conditions": "return(true)",
        "funcStartup": "if mission.trig.conditions[1]() then mission.trig.actions[1]() end",
        "flag": True,
    }
    mission["trig"] = _unpivot(dict(sorted(renumbered.items())))

    # 4. trigrules: drop stale, renumber survivors from 2, insert ours at 1.
    survivors = [r for k, r in sorted(trigrules.items(), key=lambda kv: int(kv[0])) if int(k) not in stale_ids]
    new_rules: dict[int, dict] = {
        1: {
            "rules": [],
            "eventlist": "",
            "actions": [{"predicate": "a_do_script", "text": userconfig_lua}],
            "predicate": "triggerStart",
            "comment": MARKER,
        }
    }
    for i, rule in enumerate(survivors, start=2):
        new_rules[i] = rule
    mission["trigrules"] = new_rules

    write_miz(mission, miz_path, out_path)
