"""Internationalisation for ctld-tools (EN + FR), following the VMCT approach.

A tiny stdlib i18n layer: flat JSON catalogs (`data/locales/<lang>.json`), a `t(key,
**kwargs)` lookup with `str.format` placeholders, and language resolution from the OS
locale with an explicit override. No gettext, no .po/.mo, no external dependency.

Language resolution order:
1. `set_language(lang)` — explicit (e.g. the `--lang` CLI option or the TUI toggle)
2. `CTLD_LANG` environment variable
3. OS locale (never calls `setlocale`, which is process-wide; reads the Windows registry)
4. `"en"` (hard fallback)

`en.json` is authoritative: any missing key falls back to EN, then to the key itself.
"""

from __future__ import annotations

import json
import locale
import os
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from importlib.resources import files

_LOCALES = files("ctld_tools").joinpath("data", "locales")

_lang: str = "en"
_catalog: dict[str, str] = {}
_en_catalog: dict[str, str] = {}


def _detect_lang() -> str:
    """Detect the active language from the environment / OS locale (see module docstring)."""
    env = os.environ.get("CTLD_LANG", "").strip()
    if env:
        return env[:2].lower()
    # OS locale; avoid the deprecated getdefaultlocale() (removed in 3.15) and never
    # call setlocale() (process-wide side effect).
    try:
        loc = locale.getlocale(locale.LC_CTYPE)[0]
        if loc:
            return loc[:2].lower()
    except Exception:
        pass
    # On Windows getlocale() returns None until setlocale() is called; read the registry.
    if sys.platform == "win32":
        try:
            import winreg

            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\International") as key:
                locale_name = winreg.QueryValueEx(key, "LocaleName")[0]  # e.g. "fr-FR"
                if locale_name:
                    return locale_name[:2].lower()
        except Exception:
            pass
    # Last resort (Linux/macOS): parse the locale env vars directly.
    for var in ("LC_ALL", "LC_CTYPE", "LANG"):
        val = os.environ.get(var, "").strip()
        if val and val not in ("C", "POSIX"):
            return val[:2].lower()
    return "en"


def _load_catalog(lang: str) -> dict[str, str]:
    resource = _LOCALES.joinpath(f"{lang}.json")
    if not resource.is_file():
        return {}
    try:
        return json.loads(resource.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        import logging

        logging.getLogger(__name__).warning("Failed to load locale catalog '%s.json': invalid JSON", lang)
        return {}


def _init() -> None:
    global _lang, _catalog, _en_catalog
    _en_catalog = _load_catalog("en")
    _lang = _detect_lang()
    _catalog = _en_catalog if _lang == "en" else _load_catalog(_lang)


def set_language(lang: str) -> None:
    """Override the active language at runtime; reloads the catalog."""
    global _lang, _catalog
    _lang = lang.strip().lower()[:2]
    _catalog = _en_catalog if _lang == "en" else _load_catalog(_lang)


def current_language() -> str:
    return _lang


@contextmanager
def language(lang: str) -> Iterator[None]:
    """Temporarily switch language, restoring the previous one on exit (handy in tests)."""
    previous = current_language()
    set_language(lang)
    try:
        yield
    finally:
        set_language(previous)


def t(key: str, **kwargs: object) -> str:
    """Translate a key, falling back to EN then to the key itself; formats with kwargs."""
    text = _catalog.get(key) or _en_catalog.get(key, key)
    if kwargs:
        try:
            return text.format_map(kwargs)
        except (KeyError, ValueError):
            return text
    return text


# Initialise at import time so module-level t() calls (e.g. Typer help= strings) resolve.
_init()
