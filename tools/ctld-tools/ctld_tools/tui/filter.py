"""Pure filter for the filter-as-you-type pickers (no textual import).

Large lists — DCS unit types (~1143), catalogue crates/troops — are narrowed by
case-insensitive substring so the MM types a few characters instead of scrolling.
Kept pure so it is unit-tested independently of the widget that drives it.
"""

from __future__ import annotations

from collections.abc import Iterable


def filter_options(options: Iterable[str], query: str) -> list[str]:
    """Return the options containing `query` (case-insensitive substring), order kept.

    An empty or whitespace-only query returns every option.
    """
    items = list(options)
    needle = query.strip().lower()
    if not needle:
        return items
    return [option for option in items if needle in option.lower()]
