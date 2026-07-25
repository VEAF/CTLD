"""The JSON defaults oracle: flat merge of the config YAML + committed-file drift guard."""

import json
from pathlib import Path

from ctld_tools.oracle import flat_defaults, write_json

REPO = Path(__file__).resolve().parents[3]
SRC_YAML = REPO / "src" / "CTLD_config.yaml"
ORACLE = REPO / "tests" / "ci" / "data" / "config_defaults.json"

SAMPLE = """\
configVersion: "2.0.0"
mm_facing:
  numberOfTroops: 10
advanced:
  hoverTime: 15
"""


def test_flat_merge_across_sections_and_top_level(tmp_path):
    p = tmp_path / "c.yaml"
    p.write_text(SAMPLE, encoding="utf-8")
    flat = flat_defaults(p)
    assert flat == {"configVersion": "2.0.0", "numberOfTroops": 10, "hoverTime": 15}
    # The readability sections themselves are merged away, not kept as keys.
    assert "mm_facing" not in flat and "advanced" not in flat


def test_committed_oracle_is_in_sync_with_the_yaml(tmp_path):
    """Drift guard: the committed oracle must equal a fresh emit from the source YAML.

    If this fails, regenerate: `ctld-tools gen --yaml src/CTLD_config.yaml
    --out tests/ci/data/config_defaults.json`.
    """
    fresh = tmp_path / "config_defaults.json"
    write_json(SRC_YAML, fresh)
    assert fresh.read_text(encoding="utf-8") == ORACLE.read_text(encoding="utf-8")


def test_oracle_is_valid_json_with_config_version():
    data = json.loads(ORACLE.read_text(encoding="utf-8"))
    assert data["configVersion"] == "2.0.0"
    assert "spawnableCrates" in data
