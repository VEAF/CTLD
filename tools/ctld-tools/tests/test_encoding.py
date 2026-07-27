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
