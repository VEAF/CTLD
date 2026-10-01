"""Config completion — bring an opened configuration up to date with the default catalogue.

A configuration authored against an older catalogue lacks the settings the catalogue gained since,
and the tool used to write it back as it was.

- A **scalar parameter** is never a deliberate removal (ADR 0011 Addendum 1), so an absent one is
  always added with its catalogue default.
- A **field of a list entry** (the crate spawn fields of an aircraft type, the size of a crate model)
  can be absent because the Mission Maker removed it or because the configuration predates it. The
  version tag tells the two apart: only a configuration older than the catalogue is completed, and
  only for entries the catalogue knows. Saving stamps the current version, so a later removal is
  respected.

Lists and entries that are absent altogether are never re-created.

A value the configuration already carries is never changed.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from ctld_tools.catalog import Catalog
from ctld_tools.versiongap import entry_field_gap, parse_version

_VERSION_KEY = "configVersion"


@dataclass(frozen=True)
class Addition:
    """Something `complete()` added: a scalar parameter, or a field of a list entry.

    `key` is the parameter or the field name; `container` and `entry` are set only for a field of a list entry
    (`capabilitiesByType` and `Mi-8MT`); `section` is where the parameter (or the container) lives.
    """

    key: str
    value: Any
    section: str | None
    container: str | None = None
    entry: str | None = None


def _is_scalar(value: Any) -> bool:
    return not isinstance(value, (dict, list, tuple))


def complete(user: Catalog, default: Catalog) -> list[Addition]:
    """Add to `user` what `default` has and it lacks; return what was added.

    Scalar parameters are always added. The tier is derived from the shape of the default value (a
    scalar is a parameter), the same rule the engine applies, so tool and engine cannot disagree about
    what an absent key means. Fields of list entries are added only when `user` predates `default`.
    """
    added: list[Addition] = []
    for key in default.keys():
        if key == _VERSION_KEY:
            continue
        value = default.get(key)
        if not _is_scalar(value) or user.has(key):
            continue
        section = default.section_of(key)
        user.add_setting(key, value, section=section)
        added.append(Addition(key, value, section))

    if parse_version(user.get(_VERSION_KEY)) < parse_version(default.get(_VERSION_KEY)):
        for f in entry_field_gap(user, default)[0]:
            user.get(f.container)[f.entry][f.field] = f.value
            added.append(Addition(f.field, f.value, user.section_of(f.container), f.container, f.entry))
    return added
