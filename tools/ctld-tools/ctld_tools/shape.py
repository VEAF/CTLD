"""The shape of the catalogue: its keys, and the scalar fields of its list entries.

`complete()` decides from the version tag whether a missing list-entry field is a removal or an
omission, so the tag must move whenever the catalogue gains or loses a key or such a field. The shape
is pinned per version under `tests/ci/data/catalogue_shapes/`, and a test fails when the catalogue no
longer matches the snapshot of its own version. A *value* changing is not a change of shape.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from ctld_tools.catalog import Catalog
from ctld_tools.versiongap import entry_tables

_VERSION_KEY = "configVersion"

#: What a contributor does when the guard fires.
GUIDANCE = (
    "A key or a list-entry field was added to (or removed from) src/CTLD_config.yaml: increment configVersion "
    "there, add the snapshot of the new version with `ctld-tools shape --yaml src/CTLD_config.yaml "
    "--out tests/ci/data/catalogue_shapes/<version>.json`, and regenerate tests/ci/data/config_defaults.json."
)


def _is_scalar(value: Any) -> bool:
    return not isinstance(value, (dict, list, tuple))


def catalogue_shape(catalog: Catalog) -> dict[str, Any]:
    """`{version, keys, entryFields}`, both lists sorted: the flat settings/data keys and `table/entry/field`."""
    keys = sorted(k for k in catalog.keys() if k != _VERSION_KEY)
    fields = sorted(
        f"{container}/{entry}/{field}"
        for container, entries in entry_tables(catalog)
        for entry, body in entries.items()
        for field, value in body.items()
        if _is_scalar(value)
    )
    return {"version": str(catalog.get(_VERSION_KEY)), "keys": keys, "entryFields": fields}


def shape_diff(snapshot: dict[str, Any], current: dict[str, Any]) -> list[str]:
    """Human-readable differences between a pinned shape and the current one (empty when identical)."""
    out: list[str] = []
    for label, field in (("key", "keys"), ("entry field", "entryFields")):
        before, after = set(snapshot.get(field, [])), set(current.get(field, []))
        out.extend(f"added {label}: {name}" for name in sorted(after - before))
        out.extend(f"removed {label}: {name}" for name in sorted(before - after))
    return out


def write_shape(catalog: Catalog, out: str | Path) -> None:
    Path(out).write_text(json.dumps(catalogue_shape(catalog), indent=2) + "\n", encoding="utf-8", newline="\n")
