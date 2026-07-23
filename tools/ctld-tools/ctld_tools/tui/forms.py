"""Form helpers for the GUI — value coercion and field utilities.

The Textual modal forms have been removed in v2 (UX-CTLD-TOOLS-V2). This module now
contains only the pure-Python helpers that are shared across the editor forms built in
later tickets.
"""

from __future__ import annotations


def coerce(text: str):
    """Best-effort scalar from a form input: bool, int, float, str, or None if blank."""
    stripped = text.strip()
    if not stripped:
        return None
    low = stripped.lower()
    if low in ("true", "false"):
        return low == "true"
    try:
        return int(stripped)
    except ValueError:
        pass
    try:
        return float(stripped)
    except ValueError:
        return stripped
