"""The `aiZones` example in the v1→v2 migration guide must be a config `validate` accepts.

FIX-DROPOFFZONES-PARITY ticket 03: a documented example that does not validate is worse than no
example at all, and this one is the whole answer given to a mission maker whose `dropOffZones`
stopped working. The test reads the guide itself, so the doc cannot drift away from the engine.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from ruamel.yaml import YAML

from ctld_tools.catalog import Catalog
from ctld_tools.schema import Schema
from ctld_tools.validate import validate

REPO = Path(__file__).resolve().parents[3]
SRC = REPO / "src"
GUIDES = {
    "en": REPO / "docs" / "developer" / "migration-v1-v2.md",
    "fr": REPO / "docs" / "developer" / "migration-v1-v2.fr.md",
}
ANCHOR = "dropOffZones"


def _example_after_anchor(guide: Path) -> str:
    """The first ```yaml block after the dropOffZones heading."""
    text = guide.read_text(encoding="utf-8")
    start = text.index(ANCHOR)
    block = re.search(r"```yaml\n(.*?)```", text[start:], re.S)
    assert block, f"no yaml example after the {ANCHOR} heading in {guide.name}"
    return block.group(1)


@pytest.mark.parametrize("lang", sorted(GUIDES))
def test_migration_example_validates(lang: str):
    snippet = _example_after_anchor(GUIDES[lang])
    doc = YAML(typ="safe").load(snippet)

    assert "aiZones" in doc, "the example must show the aiZones replacement"
    assert all(z.get("isDropoff") for z in doc["aiZones"]), "every zone in the example is a drop-off"

    catalog = Catalog.load(SRC / "CTLD_config.yaml")
    catalog.set("aiZones", doc["aiZones"])
    findings = validate(catalog, Schema.load(SRC / "CTLD_config_schema.yaml"))

    errors = [str(f) for f in findings if f.severity == "error"]
    assert errors == [], f"the {lang} example does not validate: {errors}"
