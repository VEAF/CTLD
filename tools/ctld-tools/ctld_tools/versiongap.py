"""Version-gap detection — diff an authored catalogue against the current default.

When a `configUser` is opened, its `configVersion` may lag the current catalogue's.
This pure function surfaces the *default* diff between the two so a caller (lot-3 UI)
can present a re-migration popup (ADR 0011 point 5): settings the new default adds,
settings it drops, and settings whose default value changed. No runtime behaviour and
no UI — just structured data.

The diff is taken over the `Catalog` flat namespace (`Catalog.keys()`): the settings
and data keys across the readability sections and top level. `configVersion` itself is
excluded — it is the discriminator, not a default to review.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from ctld_tools.catalog import Catalog

_VERSION_KEY = "configVersion"


@dataclass(frozen=True)
class Change:
    """A key present in both catalogues whose default value changed."""

    key: str
    old: Any
    new: Any


@dataclass(frozen=True)
class VersionGap:
    """The structured diff between an authored catalogue and the current default."""

    from_version: str | None
    to_version: str | None
    added: list[str] = field(default_factory=list)
    removed: list[str] = field(default_factory=list)
    changed: list[Change] = field(default_factory=list)

    @property
    def is_empty(self) -> bool:
        return not (self.added or self.removed or self.changed)


def _version(catalog: Catalog) -> str | None:
    v = catalog.get(_VERSION_KEY)
    return None if v is None else str(v)


def _diff_keys(catalog: Catalog) -> list[str]:
    return [k for k in catalog.keys() if k != _VERSION_KEY]


def version_gap(user: Catalog, current: Catalog) -> VersionGap:
    """Diff an authored catalogue (`user`) against the current default (`current`).

    Equal versions yield an empty gap. Otherwise, keys are compared over the flat
    namespace: `added` = in `current` only, `removed` = in `user` only, `changed` =
    in both with a differing value. Order follows `current` (then `user` for removals).
    """
    from_version = _version(user)
    to_version = _version(current)
    if from_version == to_version:
        return VersionGap(from_version, to_version)

    user_keys = _diff_keys(user)
    current_keys = _diff_keys(current)
    user_set = set(user_keys)
    current_set = set(current_keys)

    added = [k for k in current_keys if k not in user_set]
    removed = [k for k in user_keys if k not in current_set]
    changed = [
        Change(k, user.get(k), current.get(k)) for k in current_keys if k in user_set and user.get(k) != current.get(k)
    ]
    return VersionGap(from_version, to_version, added, removed, changed)
