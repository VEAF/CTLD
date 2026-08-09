"""Custom beacon sounds — the reserved-name model of ADR 0012, end to end.

The promise these tests exist to hold: a mission installed with a sound the Mission Maker chose can
be reopened, edited and reinstalled **on another machine, with the original file deleted**. That is
why the bytes travel in the archive and are read at selection time rather than at install time.
"""

import shutil
import zipfile
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from ctld_tools import resources
from ctld_tools.catalog import Catalog
from ctld_tools.install import L10N, custom_sound_name, read_sounds_from_miz, sounds_to_write
from ctld_tools.validate import has_errors, validate
from ctld_tools.web import dialogs
from ctld_tools.web.app import app
from ctld_tools.web.state import session

REPO = Path(__file__).resolve().parents[3]
MIZ = REPO / "missions" / "Test_CTLDNEXT_01.miz"

pytestmark = pytest.mark.skipif(not (REPO / "CTLD.lua").is_file(), reason="CTLD.lua not built in this checkout")

client = TestClient(app)

#: A minimal but genuine Ogg header — enough for the signature check, and not an .mp3 in disguise.
OGG = b"OggS" + b"\x00" * 60
NOT_OGG = b"ID3\x04" + b"\x00" * 60


@pytest.fixture(autouse=True)
def _fresh_session():
    session.reset()
    yield
    session.reset()


@pytest.fixture
def sound_file(tmp_path: Path) -> Path:
    path = tmp_path / "Ma Balise Été.ogg"
    path.write_bytes(OGG)
    return path


def choose(monkeypatch, path: Path | None, setting: str = "radioSound"):
    monkeypatch.setattr(dialogs, "pick_sound", lambda: str(path) if path else None)
    return client.post(f"/api/sounds/{setting}/custom")


def names(miz: Path) -> set[str]:
    with zipfile.ZipFile(miz) as z:
        return set(z.namelist())


# ── the model ──────────────────────────────────────────────────────
def test_a_custom_sound_is_recognised_by_its_reserved_name():
    """Not by "differs from the default": a Mission Maker's own beacon.ogg is the case that breaks."""
    cat = Catalog.loads("mm_facing:\n  radioSound: beacon.ogg\n")
    assert custom_sound_name(cat, "radioSound") is None

    cat = Catalog.loads("mm_facing:\n  radioSound: CTLD_beacon_custom.ogg\n")
    assert custom_sound_name(cat, "radioSound") == "CTLD_beacon_custom.ogg"


def test_a_custom_sound_with_no_bytes_refuses_to_be_written():
    """Silent beacons are discovered in flight; the install must fail here instead."""
    cat = Catalog.loads("mm_facing:\n  radioSound: CTLD_beacon_custom.ogg\n")
    with pytest.raises(FileNotFoundError, match="choose it again"):
        sounds_to_write(cat, {})

    written = sounds_to_write(cat, {"radioSound": OGG})
    assert written["CTLD_beacon_custom.ogg"] == OGG
    # the other sound is untouched and still the bundled one
    assert "beaconsilent.ogg" in written


def test_validation_blocks_a_sound_the_tool_cannot_produce():
    cat = Catalog.loads("mm_facing:\n  radioSound: CTLD_beacon_custom.ogg\n")
    findings = validate(cat, session.schema, types=set(), sounds_available=set())
    assert has_errors(findings)
    assert any(f.key == "validate.sound.missing" for f in findings)

    # …and says nothing once the bytes are available.
    ok = validate(cat, session.schema, types=set(), sounds_available={"radioSound"})
    assert not any(f.key == "validate.sound.missing" for f in ok)


# ── choosing a file ────────────────────────────────────────────────
def test_choosing_a_file_stores_it_and_records_its_original_name(monkeypatch, sound_file):
    client.post("/api/catalog/load-default")
    body = choose(monkeypatch, sound_file).json()

    assert body["file"] == "CTLD_beacon_custom.ogg"
    assert body["originalName"] == "Ma Balise Été.ogg"
    assert body["size"] == len(OGG)

    cat = session.catalog
    assert cat.get("radioSound") == "CTLD_beacon_custom.ogg"
    assert cat.get("radioSoundOriginalName") == "Ma Balise Été.ogg"
    assert session.sound("radioSound") == OGG


def test_a_file_that_is_not_ogg_is_refused(monkeypatch, tmp_path):
    client.post("/api/catalog/load-default")
    fake = tmp_path / "music.ogg"
    fake.write_bytes(NOT_OGG)

    response = choose(monkeypatch, fake)
    assert response.status_code == 422
    assert "OggS" in response.json()["detail"]
    # nothing changed: the configuration must not point at a file that would play nothing
    assert session.catalog.get("radioSound") == "beacon.ogg"
    assert session.sound("radioSound") is None


def test_cancelling_the_dialog_changes_nothing(monkeypatch):
    client.post("/api/catalog/load-default")
    assert choose(monkeypatch, None).json() == {"cancelled": True}
    assert session.catalog.get("radioSound") == "beacon.ogg"


def test_going_back_to_the_default_drops_the_bytes_and_the_label(monkeypatch, sound_file):
    client.post("/api/catalog/load-default")
    choose(monkeypatch, sound_file)

    client.post("/api/sounds/radioSound/default")
    cat = session.catalog
    assert cat.get("radioSound") == "beacon.ogg"
    assert not cat.has("radioSoundOriginalName")
    assert session.sound("radioSound") is None


def test_the_two_sounds_are_independent(monkeypatch, sound_file):
    client.post("/api/catalog/load-default")
    choose(monkeypatch, sound_file, setting="radioSoundFC3")

    cat = session.catalog
    assert cat.get("radioSoundFC3") == "CTLD_beaconsilent_custom.ogg"
    assert cat.get("radioSound") == "beacon.ogg", "the other sound stays the bundled one"


# ── the round trip, which is the whole point ───────────────────────
def test_a_custom_sound_survives_install_reopen_and_reinstall(monkeypatch, sound_file, tmp_path):
    miz = tmp_path / "mission.miz"
    shutil.copy(MIZ, miz)

    client.post("/api/catalog/load-default")
    choose(monkeypatch, sound_file)
    report = client.post("/api/inject", json={"miz": str(miz)}).json()

    assert f"{L10N}/CTLD_beacon_custom.ogg" in names(miz)
    assert {"setting": "radioSound", "file": "CTLD_beacon_custom.ogg", "size": len(OGG), "custom": True} in report[
        "sounds"
    ]

    # The Mission Maker's own file is gone, and so is every trace of this session.
    sound_file.unlink()
    session.reset()

    client.post("/api/catalog/load", json={"path": str(miz)})
    assert session.catalog.get("radioSound") == "CTLD_beacon_custom.ogg"
    assert session.catalog.get("radioSoundOriginalName") == "Ma Balise Été.ogg", "the label came back too"
    assert session.sound("radioSound") == OGG, "the bytes came out of the archive"

    # Reinstalling into a *different* mission still writes it.
    other = tmp_path / "other.miz"
    shutil.copy(MIZ, other)
    assert client.post("/api/inject", json={"miz": str(other)}).status_code == 200
    with zipfile.ZipFile(other) as z:
        assert z.read(f"{L10N}/CTLD_beacon_custom.ogg") == OGG


def test_reading_sounds_back_ignores_a_mission_that_uses_the_defaults(tmp_path):
    miz = tmp_path / "plain.miz"
    shutil.copy(MIZ, miz)
    cat = Catalog.loads("mm_facing:\n  radioSound: beacon.ogg\n")
    assert read_sounds_from_miz(miz, cat) == {}


def test_a_yaml_cannot_carry_the_sound_so_validation_asks_for_it(monkeypatch, sound_file, tmp_path):
    """The accepted limit of the model — and it must be an error, not a surprise in flight."""
    client.post("/api/catalog/load-default")
    choose(monkeypatch, sound_file)

    saved = tmp_path / "config.yaml"
    client.post("/api/catalog/save", json={"path": str(saved)})

    session.reset()
    client.post("/api/catalog/load", json={"path": str(saved)})
    assert session.sound("radioSound") is None

    findings = client.get("/api/validate").json()
    assert findings["hasErrors"]
    assert any(f["key"] == "validate.sound.missing" for f in findings["findings"])

    # Injecting into a mission that already holds the file is fine, though: nothing is missing.
    miz = tmp_path / "has-it.miz"
    shutil.copy(MIZ, miz)
    with zipfile.ZipFile(miz, "a") as z:
        z.writestr(f"{L10N}/CTLD_beacon_custom.ogg", OGG)
    assert client.post("/api/inject", json={"miz": str(miz)}).status_code == 200


def test_the_sound_state_endpoint_describes_both_pickers(monkeypatch, sound_file):
    client.post("/api/catalog/load-default")
    choose(monkeypatch, sound_file)

    sounds = {s["setting"]: s for s in client.get("/api/sounds").json()["sounds"]}
    assert sounds["radioSound"] == {
        "setting": "radioSound",
        "custom": True,
        "file": "CTLD_beacon_custom.ogg",
        "originalName": "Ma Balise Été.ogg",
        "size": len(OGG),
        "available": True,
    }
    assert sounds["radioSoundFC3"]["custom"] is False
    assert sounds["radioSoundFC3"]["originalName"] is None


def test_owned_names_cover_the_four_files_and_nothing_else():
    assert resources.OWNED_SOUND_NAMES == {
        "beacon.ogg",
        "beaconsilent.ogg",
        "CTLD_beacon_custom.ogg",
        "CTLD_beaconsilent_custom.ogg",
    }
