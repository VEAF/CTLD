"""Config completion — bring an opened configuration up to date with the default catalogue.

A configuration authored against an older catalogue lacks the settings the catalogue gained since,
and the tool used to write it back as it was. ADR 0011 Addendum 1 already settles the tier that is
never ambiguous: a **scalar parameter** is never a deliberate removal, so an absent one is added with
its catalogue default. Lists and list entries are not touched here: an absent one can be the Mission
Maker's own removal.

A value the configuration already carries is never changed.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from ctld_tools.catalog import Catalog

_VERSION_KEY = "configVersion"


@dataclass(frozen=True)
class Addition:
    """A scalar parameter `complete()` added: its key, the default it received and the section it went to."""

    key: str
    value: Any
    section: str | None


def _is_scalar(value: Any) -> bool:
    return not isinstance(value, (dict, list, tuple))


def complete(user: Catalog, default: Catalog) -> list[Addition]:
    """Add to `user` every scalar parameter of `default` it lacks; return what was added.

    The tier is derived from the shape of the default value (a scalar is a parameter), the same rule
    the engine applies, so tool and engine cannot disagree about what an absent key means.
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
    return added
