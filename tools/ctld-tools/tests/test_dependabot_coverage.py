"""Every dependency manifest of the repository is covered by an entry of `.github/dependabot.yml`.

An unlisted manifest is invisible to the Dependabot policy (grouping, cadence, cap) and its updates arrive through
GitHub's defaults instead, ungrouped and duplicated. This is the guard that keeps the file complete.
"""

import fnmatch
import subprocess
from pathlib import Path, PurePosixPath

from ruamel.yaml import YAML

REPO = Path(__file__).resolve().parents[3]
CONFIG = REPO / ".github" / "dependabot.yml"

#: Tracked paths that are never a manifest of ours: vendored or legacy trees, installed packages.
_IGNORED_PARTS = {"node_modules", "migration"}


def find_manifests(paths: list[str]) -> list[tuple[str, str, str]]:
    """`(ecosystem, directory, file)` for every dependency manifest among the tracked `paths`.

    `directory` is written the way `dependabot.yml` writes it: rooted at the repository, with a leading slash.
    """
    found: list[tuple[str, str, str]] = []
    workflows = False
    for raw in paths:
        path = PurePosixPath(raw)
        if _IGNORED_PARTS & set(path.parts):
            continue
        directory = "/" + "/".join(path.parent.parts) if path.parent.parts else "/"
        if path.name == "package.json":
            found.append(("npm", directory, raw))
        elif path.name == "pyproject.toml" or fnmatch.fnmatch(path.name, "requirements*.txt"):
            found.append(("pip", directory, raw))
        elif path.parts[:2] == (".github", "workflows") and path.suffix in (".yml", ".yaml"):
            workflows = True
    if workflows:
        found.append(("github-actions", "/", ".github/workflows"))
    return found


def uncovered(config: dict, manifests: list[tuple[str, str, str]]) -> list[str]:
    """One message per manifest that no entry of `config` covers, naming the entry to add."""
    out = []
    for ecosystem, directory, file in manifests:
        covered = any(
            entry["package-ecosystem"] == ecosystem
            and (entry.get("directory") == directory or directory in entry.get("directories", []))
            for entry in config.get("updates", [])
        )
        if not covered:
            out.append(
                f'{file}: no entry in .github/dependabot.yml covers it. Add one with package-ecosystem: "{ecosystem}"'
                f' and directory: "{directory}" (see the other entries for the cadence, groups and cap).'
            )
    return out


def _load() -> dict:
    return YAML(typ="safe").load(CONFIG.read_text(encoding="utf-8"))


def _tracked() -> list[str]:
    out = subprocess.run(["git", "-C", str(REPO), "ls-files"], capture_output=True, text=True, check=True).stdout
    return out.splitlines()


#: What a repository carrying all five places looks like, used by the fixtures below.
PATHS = [
    "docs/requirements.txt",
    "tools/build/requirements-translate.txt",
    "tools/ctld-tools/pyproject.toml",
    "tools/ctld-tools/web/package.json",
    ".github/workflows/ci.yml",
    "src/CTLD_crate.lua",
]


def test_every_manifest_of_the_repository_is_covered():
    assert uncovered(_load(), find_manifests(_tracked())) == []


def test_the_real_repository_has_the_five_expected_places():
    found = {(eco, directory) for eco, directory, _ in find_manifests(_tracked())}
    assert found == {
        ("github-actions", "/"),
        ("npm", "/tools/ctld-tools/web"),
        ("pip", "/tools/ctld-tools"),
        ("pip", "/docs"),
        ("pip", "/tools/build"),
    }


def test_a_new_manifest_with_no_entry_fails_and_says_what_to_add():
    messages = uncovered(_load(), find_manifests([*PATHS, "tools/newtool/requirements.txt"]))
    assert len(messages) == 1
    assert "tools/newtool/requirements.txt" in messages[0]
    assert 'package-ecosystem: "pip"' in messages[0]
    assert 'directory: "/tools/newtool"' in messages[0]


def test_a_new_npm_package_with_no_entry_fails():
    messages = uncovered(_load(), find_manifests([*PATHS, "site/package.json"]))
    assert len(messages) == 1 and 'package-ecosystem: "npm"' in messages[0]


def test_a_removed_entry_fails():
    config = _load()
    config["updates"] = [e for e in config["updates"] if e["package-ecosystem"] != "npm"]
    messages = uncovered(config, find_manifests(PATHS))
    assert len(messages) == 1 and "tools/ctld-tools/web/package.json" in messages[0]


def test_the_actions_are_covered_by_their_entry_alone():
    config = _load()
    config["updates"] = [e for e in config["updates"] if e["package-ecosystem"] != "github-actions"]
    messages = uncovered(config, find_manifests(PATHS))
    assert len(messages) == 1 and 'package-ecosystem: "github-actions"' in messages[0]


def test_an_entry_whose_directory_no_longer_matches_fails():
    config = _load()
    for entry in config["updates"]:
        if entry["package-ecosystem"] == "npm":
            entry["directory"] = "/tools/ctld-tools/webapp"
    assert len(uncovered(config, find_manifests(PATHS))) == 1


def test_an_entry_listing_several_directories_covers_them_all():
    config = {"updates": [{"package-ecosystem": "pip", "directories": ["/docs", "/tools/build", "/tools/ctld-tools"]}]}
    pip_only = [p for p in PATHS if not p.endswith("package.json") and not p.startswith(".github")]
    assert uncovered(config, find_manifests(pip_only)) == []


def test_installed_packages_and_the_legacy_tree_are_not_manifests():
    paths = [
        "tools/ctld-tools/web/node_modules/left-pad/package.json",
        "migration/source/package.json",
        "src/CTLD_crate.lua",
    ]
    assert find_manifests(paths) == []
