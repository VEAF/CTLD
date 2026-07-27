"""Guard against mojibake in the authored YAML sources.

Eleven French descriptions in `CTLD_config_schema.yaml` shipped double-encoded — UTF-8 bytes written
out as if they were cp1252, so "référence" became "rÃ©fÃ©rence". It survived a review and two lots
because nothing rendered those strings until the FR UI arrived, and by then the corruption looked
like data rather than a bug. A human spotted it in the running app.

The signature is unmistakable and cheap to test for, so it gets a test instead of another review pass:
any `Ã`/`Â`/`â€` sequence in a file that is supposed to hold clean UTF-8 French.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

# Repo root: tools/ctld-tools/tests/ -> ../../..
ROOT = Path(__file__).resolve().parents[3]

# Files whose text reaches the user and is authored in French.
AUTHORED_SOURCES = [
    ROOT / "src" / "CTLD_config_schema.yaml",
    ROOT / "src" / "CTLD_config.yaml",
    ROOT / "tools" / "ctld-tools" / "ctld_tools" / "data" / "locales" / "fr.json",
    ROOT / "tools" / "ctld-tools" / "ctld_tools" / "data" / "locales" / "en.json",
]

# `Ã` followed by anything, `Â` before a punctuation/space, and the classic `â€` of a mangled
# quote — all impossible in correctly encoded French, all typical of a cp1252 round-trip.
MOJIBAKE = re.compile(r"Ã.|Â[\s«»\xa0!-/:-@]|â€")


def _offenders(path: Path) -> list[tuple[int, str]]:
    if not path.is_file():
        return []
    lines = path.read_text(encoding="utf-8").splitlines()
    return [(n, line.strip()) for n, line in enumerate(lines, 1) if MOJIBAKE.search(line)]


@pytest.mark.parametrize("path", AUTHORED_SOURCES, ids=lambda p: p.name)
def test_no_mojibake_in_authored_sources(path: Path) -> None:
    offenders = _offenders(path)
    assert not offenders, "double-encoded text in {}:\n{}".format(
        path.relative_to(ROOT),
        "\n".join(f"  line {n}: {text[:100]}" for n, text in offenders[:15]),
    )


def test_sources_are_valid_utf8() -> None:
    """A file that is not valid UTF-8 at all would slip past the regex above."""
    for path in AUTHORED_SOURCES:
        if path.is_file():
            path.read_bytes().decode("utf-8")  # raises UnicodeDecodeError on failure


def test_the_detector_actually_detects(tmp_path: Path) -> None:
    """Guard the guard: a test that never fires is worse than no test."""
    corrupted = tmp_path / "sample.yaml"
    # "référence" and "« quoted »" as they look after a cp1252 round-trip.
    corrupted.write_text("fr: le point de rÃ©fÃ©rence\nfr: l'action Â« Retirer Â»\n", encoding="utf-8")
    assert len(_offenders(corrupted)) == 2

    clean = tmp_path / "clean.yaml"
    clean.write_text("fr: le point de référence\nfr: l'action « Retirer »\n", encoding="utf-8")
    assert _offenders(clean) == []


# ── in-code fallbacks vs the catalogue ──────────────────────────────
# Several `ctld.gs("x") or <default>` fallbacks in the Lua disagreed with the catalogue, so the same
# setting had two defaults depending on whether a config was loaded. Reviewing `maxSlingloadSpeed`
# turned that up, so the setting that prompted it gets pinned here.
FALLBACK_PATTERN = r'ctld\.gs\("{key}"\)\s*or\s+([\d.]+)'


def _catalogue_value(key: str):
    from ruamel.yaml import YAML

    cfg = YAML(typ="safe").load((ROOT / "src" / "CTLD_config.yaml").read_text(encoding="utf-8"))
    flat: dict = {}
    for section, value in cfg.items():
        if section in ("mm_facing", "advanced") and isinstance(value, dict):
            flat.update(value)
        else:
            flat[section] = value
    return flat[key]


def test_max_slingload_speed_fallback_matches_the_catalogue() -> None:
    """The Lua fallback and the catalogue must not drift.

    The value is in m/s (the engine compares it to `Unit:getVelocity()`), and the original default of
    50 read like knots — 50 m/s is ~180 km/h. Corrected to 26 (~50 kt) in both places; this test is
    what keeps them together.
    """
    lua = (ROOT / "src" / "CTLD_crate.lua").read_text(encoding="utf-8")
    match = re.search(FALLBACK_PATTERN.format(key="maxSlingloadSpeed"), lua)
    assert match, "the maxSlingloadSpeed fallback disappeared — update this test with it"
    assert float(match.group(1)) == float(_catalogue_value("maxSlingloadSpeed"))
