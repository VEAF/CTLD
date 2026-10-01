"""`.github/dependabot.yml` declares every dependency place of the repository under one policy.

Dependabot's own behaviour (grouping, cap, cadence) can only be seen on GitHub; this pins what the file says.
"""

from pathlib import Path

import pytest
from ruamel.yaml import YAML

REPO = Path(__file__).resolve().parents[3]
CONFIG = REPO / ".github" / "dependabot.yml"

EXPECTED = {
    ("github-actions", "/"),
    ("npm", "/tools/ctld-tools/web"),
    ("pip", "/tools/ctld-tools"),
    ("pip", "/docs"),
    ("pip", "/tools/build"),
}


def _load() -> dict:
    return YAML(typ="safe").load(CONFIG.read_text(encoding="utf-8"))


def _entries() -> dict[tuple[str, str], dict]:
    return {(e["package-ecosystem"], e["directory"]): e for e in _load()["updates"]}


def _managed() -> list[dict]:
    return [e for key, e in _entries().items() if key[0] in ("npm", "pip")]


def test_the_file_is_dependabot_version_2():
    assert _load()["version"] == 2


def test_the_five_dependency_places_are_declared():
    assert set(_entries()) == EXPECTED


def test_every_entry_has_what_dependabot_requires():
    for entry in _load()["updates"]:
        assert {"package-ecosystem", "directory", "schedule"} <= set(entry)
        assert "interval" in entry["schedule"]


def test_the_actions_entry_is_unchanged():
    actions = _entries()[("github-actions", "/")]
    assert actions["schedule"]["interval"] == "weekly"
    assert actions["commit-message"]["prefix"] == "ci"


@pytest.mark.parametrize("entry", _managed(), ids=lambda e: f"{e['package-ecosystem']}:{e['directory']}")
def test_npm_and_pip_are_monthly_and_capped(entry):
    assert entry["schedule"]["interval"] == "monthly"
    assert entry["open-pull-requests-limit"] == 3


@pytest.mark.parametrize("entry", _managed(), ids=lambda e: f"{e['package-ecosystem']}:{e['directory']}")
def test_npm_and_pip_commits_follow_conventional_commits(entry):
    assert entry["commit-message"]["prefix"] == "chore"
    assert entry["commit-message"]["include"] == "scope"


@pytest.mark.parametrize("entry", _managed(), ids=lambda e: f"{e['package-ecosystem']}:{e['directory']}")
def test_minor_and_patch_are_grouped_and_a_major_is_not(entry):
    groups = entry["groups"]
    version_groups = [g for g in groups.values() if g.get("applies-to", "version-updates") == "version-updates"]
    assert len(version_groups) == 1
    assert sorted(version_groups[0]["update-types"]) == ["minor", "patch"]
    assert "major" not in version_groups[0]["update-types"]


@pytest.mark.parametrize("entry", _managed(), ids=lambda e: f"{e['package-ecosystem']}:{e['directory']}")
def test_security_updates_follow_a_group_too(entry):
    security = [g for g in entry["groups"].values() if g.get("applies-to") == "security-updates"]
    assert len(security) == 1
    assert security[0]["patterns"] == ["*"]
