"""Version-gap detection — diff an authored catalogue against the current default.

When a `configUser` is opened, its `configVersion` may lag the current catalogue's.
This pure function surfaces the *default* diff between the two so a caller (lot-3 UI)
can present a re-migration popup (ADR 0011 point 5): settings the new default adds,
settings it drops, and settings whose default value changed. No runtime behaviour and
no UI — just structured data.

The diff is taken over the `Catalog` flat namespace (`Catalog.keys()`): the settings
and data keys across the readability sections and top level. `configVersion` itself is
excluded — it is the discriminator, not a default to review.

The fields of list entries are compared too: a table keyed by name (`capabilitiesByType`,
`spawnableCratesModels`) is a map of maps, and a field the catalogue gave an entry since the
configuration was written is invisible to the flat comparison. Only entries the catalogue
knows are compared, and only their scalar fields.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from ctld_tools.catalog import Catalog

_VERSION_KEY = "configVersion"


def parse_version(value: Any) -> tuple[int, ...]:
    """`"2.1.0"` -> `(2, 1, 0)`; a missing or unreadable tag is `(0,)`, older than any real version."""
    try:
        return tuple(int(part) for part in str(value).strip().split("."))
    except (TypeError, ValueError):
        return (0,)


@dataclass(frozen=True)
class Change:
    """A key present in both catalogues whose default value changed."""

    key: str
    old: Any
    new: Any


@dataclass(frozen=True)
class EntryField:
    """A field of a list entry that the catalogue has and the configuration's entry lacks."""

    container: str
    entry: str
    field: str
    value: Any


@dataclass(frozen=True)
class EntryFieldChange:
    """A field present in both whose default value changed."""

    container: str
    entry: str
    field: str
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
    added_fields: list[EntryField] = field(default_factory=list)
    changed_fields: list[EntryFieldChange] = field(default_factory=list)

    @property
    def is_empty(self) -> bool:
        return not (self.added or self.removed or self.changed or self.added_fields or self.changed_fields)


def _version(catalog: Catalog) -> str | None:
    v = catalog.get(_VERSION_KEY)
    return None if v is None else str(v)


def _is_scalar(value: Any) -> bool:
    return not isinstance(value, (dict, list, tuple))


def _entry_tables(catalog: Catalog):
    """The maps of maps of the catalogue: `(key, {entry name: {field: value}})`."""
    for key in catalog.keys():
        value = catalog.get(key)
        if isinstance(value, dict) and value and all(isinstance(v, dict) for v in value.values()):
            yield key, value


def entry_field_gap(user: Catalog, current: Catalog) -> tuple[list[EntryField], list[EntryFieldChange]]:
    """The scalar fields of known list entries that `current` has and `user` lacks, and those whose default changed.

    An entry the catalogue does not know (a type or a crate the Mission Maker added), an entry or a list the
    configuration removed, and non-scalar fields are all left out: absent there can be a deliberate removal.
    """
    added: list[EntryField] = []
    changed: list[EntryFieldChange] = []
    for container, entries in _entry_tables(current):
        mine = user.get(container)
        if not isinstance(mine, dict):
            continue
        for name, wanted in entries.items():
            have = mine.get(name)
            if not isinstance(have, dict):
                continue
            for fld, value in wanted.items():
                if not _is_scalar(value):
                    continue
                if fld not in have:
                    added.append(EntryField(container, name, fld, value))
                elif _is_scalar(have[fld]) and have[fld] != value:
                    changed.append(EntryFieldChange(container, name, fld, have[fld], value))
    return added, changed


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
    added_fields, changed_fields = entry_field_gap(user, current)
    return VersionGap(from_version, to_version, added, removed, changed, added_fields, changed_fields)
