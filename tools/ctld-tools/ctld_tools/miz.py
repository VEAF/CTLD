"""Inject the generated CTLD_userConfig.lua into a .miz as a MISSION START trigger.

A .miz is a zip; its `mission` file is a Lua table. DCS triggers live as parallel
per-category tables (`actions`, `conditions`, `funcStartup`, `flag`, …) indexed by
the same key, mirrored in `trigrules` (editor form). The index appears **inside** the
compiled action/func strings, so shifting triggers means rewriting those `[idx]`
references — the approach used by VMCT's mission builder, recreated here.

`rebuild_triggers` is the shared machinery: it puts n triggers at ranks 1..n, renumbers
everything else after them, and drops what a previous run of ours left (matched by the
trigrules comment) so re-running replaces rather than accumulates.

Two callers: `inject_userconfig` here — configuration only, inline, the shape rc1–rc3
missions carry — and `ctld_tools.install`, which writes the engine, the sounds and the
configuration as files and loads them by resource key.
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


def rebuild_triggers(mission: dict, ours: list[tuple[dict, dict]], markers: set[str]) -> bool:
    """Put `ours` at ranks 1..n and renumber every other trigger after them.

    `ours` is a list of `(trig_categories, trigrule)` pairs, in the order they must run — DCS
    executes by rank, so the caller's order is the mission's order. `markers` are the trigrules
    comments a previous run of ours would have left: those triggers are dropped first, which is what
    makes re-installing replace instead of accumulate.

    The `funcStartup` of our own triggers is written here, because it names its own index and only
    this function knows what that index will be.

    Returns True when a previous injection was found and replaced.
    """
    trig = mission.get("trig") or {}
    trigrules = mission.get("trigrules") or {}
    n = len(ours)

    stale_ids = {int(k) for k, r in trigrules.items() if isinstance(r, dict) and r.get("comment") in markers}

    # Pivot trig, drop stale, renumber survivors after our block, rewriting in-code [idx] refs.
    pivoted = {tid: cats for tid, cats in _pivot(trig).items() if tid not in stale_ids}
    renumbered: dict[int, dict] = {}
    for new_id, old_id in enumerate(sorted(pivoted), start=n + 1):
        renumbered[new_id] = _rewrite_indices(pivoted[old_id].copy(), old_id, new_id)

    for rank, (cats, _rule) in enumerate(ours, start=1):
        entry = dict(cats)
        entry["funcStartup"] = f"if mission.trig.conditions[{rank}]() then mission.trig.actions[{rank}]() end"
        renumbered[rank] = entry
    mission["trig"] = _unpivot(dict(sorted(renumbered.items())))

    survivors = [r for k, r in sorted(trigrules.items(), key=lambda kv: int(kv[0])) if int(k) not in stale_ids]
    new_rules: dict[int, dict] = {rank: rule for rank, (_cats, rule) in enumerate(ours, start=1)}
    for i, rule in enumerate(survivors, start=n + 1):
        new_rules[i] = rule
    mission["trigrules"] = new_rules

    return bool(stale_ids)


def inject_userconfig(miz_path: str | Path, userconfig_lua: str, out_path: str | Path) -> None:
    """Inject `userconfig_lua` as a MISSION START inline-script trigger at rank 1.

    The pre-FEAT-ONE-CLICK-INSTALL path: configuration only, inline. Kept because missions injected
    by rc1–rc3 carry this shape and `install()` must be able to recognise it. New installs go
    through `ctld_tools.install.install()`, which writes files instead.
    """
    mission = read_mission(miz_path)
    escaped = _escape_lua_string(userconfig_lua)
    rebuild_triggers(
        mission,
        ours=[
            (
                {"actions": f'a_do_script("{escaped}");', "conditions": "return(true)", "flag": True},
                {
                    "rules": [],
                    "eventlist": "",
                    "actions": [{"predicate": "a_do_script", "text": userconfig_lua}],
                    "predicate": "triggerStart",
                    "comment": MARKER,
                },
            )
        ],
        markers={MARKER},
    )
    write_miz(mission, miz_path, out_path)
