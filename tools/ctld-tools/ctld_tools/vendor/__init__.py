"""Vendored third-party code.

``luadata`` — a Lua-table (de)serializer (MIT). Vendored (rather than pip-installed)
because we use the comment/index-preserving variant maintained by the VEAF VMCT
project (``keep_as_dict``), which the upstream PyPI package does not expose. Excluded
from lint/type/coverage.
"""
