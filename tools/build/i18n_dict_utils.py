"""i18n_dict_utils.py — shared parsing helpers for src/CTLD_i18n_*.lua dictionary files.

Used by translate_i18n.py and check_i18n_diff.py so both tools parse dict-file content the
same way instead of maintaining their own copy that can drift.
"""

import re

_ENTRY_RE = re.compile(r'ctld\.i18n\["[^"]+"\]\["([^"]+)"\]\s*=\s*"((?:[^"\\]|\\.)*)"\s*')
_KEEP_EN_RE = re.compile(r'\["([^"]+)"\]\s*=\s*true')


def parse_dict(text: str) -> dict[str, str]:
    """Parse a CTLD_i18n_XX.lua dict file's content into {key: value} (excludes translation_version).

    A line commented out (e.g. generate_i18n_dicts.ps1's "-- STALE: " marker for a key no longer
    referenced in src/) is not a live entry and is skipped.
    """
    result: dict[str, str] = {}
    for line in text.splitlines():
        if line.strip().startswith("--"):
            continue
        m = _ENTRY_RE.search(line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        if key != "translation_version":
            result[key] = val
    return result


def parse_keep_en(text: str) -> set[str]:
    """Parse the keys listed in a dict file's `__keep_en = { ["key"] = true, ... }` block.

    A commented-out entry inside the block is not live and is skipped (see parse_dict).
    """
    keep_en: set[str] = set()
    in_block = False
    for line in text.splitlines():
        if line.strip().startswith("--"):
            continue
        if "__keep_en" in line and "=" in line and "{" in line:
            in_block = True
        if in_block:
            m = _KEEP_EN_RE.search(line)
            if m:
                keep_en.add(m.group(1))
            if "}" in line and "__keep_en" not in line:
                in_block = False
    return keep_en
