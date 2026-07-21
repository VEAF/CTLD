"""Pure filter for the filter-as-you-type pickers (no textual import).

Large lists — DCS unit types (~1143), catalogue crates/troops — are narrowed by
case-insensitive substring so the MM types a few characters instead of scrolling.
Kept pure so it is unit-tested independently of the widget that drives it.
"""

from __future__ import annotations

from collections.abc import Iterable


def matches(text: str, query: str) -> bool:
    """True if `query` is a case-insensitive substring of `text` (empty query matches)."""
    needle = query.strip().lower()
    return not needle or needle in text.lower()


def filter_options(options: Iterable[str], query: str) -> list[str]:
    """Return the options matching `query` (case-insensitive substring), order kept.

    An empty or whitespace-only query returns every option.
    """
    return [option for option in options if matches(option, query)]
