"""Resolve the default catalogue YAML + schema the backend edits against.

In development these live in the repo's `src/`; the packaged exe (ticket 07) will bundle
them and point here via the `CTLD_TOOLS_SRC` environment override.
"""

from __future__ import annotations

import os
from pathlib import Path

_ENV = "CTLD_TOOLS_SRC"


def src_dir() -> Path:
    """The directory holding CTLD_config.yaml + CTLD_config_schema.yaml."""
    override = os.environ.get(_ENV)
    if override:
        return Path(override)
    # dev layout: tools/ctld-tools/ctld_tools/web/resources.py → repo root is parents[4].
    return Path(__file__).resolve().parents[4] / "src"


def default_catalog_path() -> Path:
    return src_dir() / "CTLD_config.yaml"


def schema_path() -> Path:
    return src_dir() / "CTLD_config_schema.yaml"
