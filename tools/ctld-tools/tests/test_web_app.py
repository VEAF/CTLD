"""The FastAPI backend: thin endpoints over the core (load/edit/save/validate/version-gap)."""

import pytest
from fastapi.testclient import TestClient

from ctld_tools.web.app import app
from ctld_tools.web.state import session

client = TestClient(app)

SAMPLE = """\
configVersion: "1.0.0"
mm_facing:
  numberOfTroops: 10
  spawnableCrates:
    Support:
    - unit: Ural-375
      desc: Ural Ammo
      weight: 1001.01
advanced:
  hoverTime: 10
"""

BAD_UNIT = SAMPLE.replace("unit: Ural-375", "unit: NotARealUnit")


@pytest.fixture(autouse=True)
def _reset():
    session.reset()
    yield
    session.reset()


def _load(text=SAMPLE):
    return client.post("/api/catalog/load", json={"text": text})


def test_health():
    assert client.get("/api/health").json() == {"status": "ok"}


def test_schema_endpoint_exposes_families_and_keys():
    body = client.get("/api/schema").json()
    assert isinstance(body["families"], list)
    assert isinstance(body["keys"], dict) and body["keys"]  # schema is non-empty
    assert "tableFields" not in body["keys"]  # the reserved section is not a setting


def test_schema_endpoint_exposes_table_fields():
    body = client.get("/api/schema").json()
    crates = body["tableFields"]["spawnableCrates"]
    assert crates["desc"]["tip"] and crates["weight_kg"]["tip"]  # field descriptions present
    # A closed vocabulary reaches the UI as `choices`, so a select cannot invent a value.
    assert crates["spawnAs"]["choices"] == ["GROUND", "AIR"]
    assert crates["desc"]["choices"] is None  # free text stays free


def test_resources_frozen_path(monkeypatch, tmp_path):
    import sys

    from ctld_tools import resources

    monkeypatch.delenv("CTLD_TOOLS_SRC", raising=False)
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "_MEIPASS", str(tmp_path), raising=False)
    assert resources.src_dir() == tmp_path / "ctld_data"


def test_schema_endpoint_exposes_family_metadata():
    # Explicit lang: without it the endpoint follows the OS locale, which differs between a
    # developer's machine and CI — the assertions below would then be non-deterministic.
    body = client.get("/api/schema?lang=en").json()
    crates = body["familyMeta"]["crates"]
    assert crates["label"] == "Crates"
    assert "crate" in crates["description"].lower()
    assert isinstance(crates["order"], int)
    # Every family a setting declares must be described, or the nav shows a bare key.
    assert set(body["families"]) <= set(body["familyMeta"])


def test_schema_endpoint_translates_with_lang():
    fr = client.get("/api/schema?lang=fr").json()
    assert fr["familyMeta"]["crates"]["label"] == "Caisses"
    assert "caisses" in fr["familyMeta"]["crates"]["description"].lower()
    # Setting descriptions and table field headings follow the same language.
    en = client.get("/api/schema?lang=en").json()
    assert fr["keys"]["enableCrates"]["description"] != en["keys"]["enableCrates"]["description"]
    assert "DCS" in fr["tableFields"]["spawnableCrates"]["unit"]["tip"]


def test_schema_endpoint_labels_every_setting():
    # Setting names are what a Mission Maker reads first; an unlabelled setting falls back to a
    # name derived from its key, which is always English.
    keys = client.get("/api/schema?lang=en").json()["keys"]
    unlabelled = [k for k, meta in keys.items() if not meta["label"]]
    assert unlabelled == []


def test_schema_endpoint_translates_setting_labels():
    en = client.get("/api/schema?lang=en").json()["keys"]
    fr = client.get("/api/schema?lang=fr").json()["keys"]
    assert en["enableCrates"]["label"] == "Enable crates"
    assert fr["enableCrates"]["label"] == "Activer les caisses"
    assert fr["aaRearmDistance"]["label"] == "Distance de réapprovisionnement AA"
    # Every label is translated, not just a handful.
    assert not [k for k in en if en[k]["label"] == fr[k]["label"] and k not in _SAME_IN_BOTH]


# Labels that are legitimately identical in EN and FR (acronyms, proper nouns).
_SAME_IN_BOTH = {"JTAC_lock", "modTypes"}


def test_schema_endpoint_exposes_units():
    keys = client.get("/api/schema?lang=en").json()["keys"]
    # Each of these was traced to the code that consumes the value.
    assert keys["maxSlingloadSpeed"]["unit"] == "m/s"  # vs the magnitude of Unit:getVelocity()
    assert keys["deployedBeaconBattery"]["unit"] == "min"  # the engine multiplies it by 60
    assert keys["hoverTime"]["unit"] == "s"  # counted down on a 1s tick
    assert keys["maxDistanceFromCrate"]["unit"] == "m"  # a 2D distance over getPoint() coords
    assert keys["maxTransportWeight"]["unit"] == "kg"  # summed into setUnitInternalCargo()


def test_units_are_not_translated():
    # Unit symbols are language-independent; only labels and descriptions are translated.
    en = client.get("/api/schema?lang=en").json()["keys"]
    fr = client.get("/api/schema?lang=fr").json()["keys"]
    assert {k: v["unit"] for k, v in en.items()} == {k: v["unit"] for k, v in fr.items()}


def test_settings_that_are_not_measurements_have_no_unit():
    # Counters, colour codes, laser codes, fractions and multipliers must stay bare: showing a
    # unit there would invent one.
    keys = client.get("/api/schema?lang=en").json()["keys"]
    for key in (
        "numberOfTroops",
        "aaLaunchers",
        "JTAC_smokeColour_BLUE",
        "jtacLaserCodeMin",
        "fobDestructionThreshold",
        "parachuteInertiaFactor",
        "reconIconScale",
        "beaconTextSize",
    ):
        assert keys[key]["unit"] is None, key


def test_labels_never_use_the_banned_repack_wording():
    # Project convention: "repack" is banned, "pack" everywhere — including user-facing labels.
    for lang in ("en", "fr"):
        keys = client.get(f"/api/schema?lang={lang}").json()["keys"]
        assert not [k for k, meta in keys.items() if "repack" in (meta["label"] or "").lower()]


def test_schema_endpoint_falls_back_to_en_for_an_unknown_lang():
    body = client.get("/api/schema?lang=zz").json()
    assert body["familyMeta"]["crates"]["label"] == "Crates"
    assert body["keys"]["enableCrates"]["description"]


def test_reserved_sections_are_not_settings():
    keys = client.get("/api/schema?lang=en").json()["keys"]
    assert "tableFields" not in keys
    assert "families" not in keys


def test_i18n_endpoint_serves_the_web_catalog():
    body = client.get("/api/i18n?lang=en").json()
    assert body["lang"] == "en"
    assert "en" in body["available"] and "fr" in body["available"]
    assert body["strings"]["web.action.inject"] == "Install into mission…"
    # The retired TUI's strings are not the web app's business.
    assert not [k for k in body["strings"] if not k.startswith("web.")]


def test_i18n_endpoint_translates():
    fr = client.get("/api/i18n?lang=fr").json()
    assert fr["lang"] == "fr"
    assert fr["strings"]["web.action.inject"] == "Installer dans la mission…"


def test_i18n_endpoint_covers_the_same_keys_in_every_language():
    en = client.get("/api/i18n?lang=en").json()["strings"]
    fr = client.get("/api/i18n?lang=fr").json()["strings"]
    assert set(en) == set(fr)


def test_i18n_endpoint_unknown_lang_falls_back_to_en():
    body = client.get("/api/i18n?lang=zz").json()
    assert body["strings"]["web.action.inject"] == "Install into mission…"


def test_defaults_endpoint_mirrors_the_default_catalogue():
    # Powers the UI's "changed from default" markers and per-setting reset. It must not need a
    # loaded catalogue — the UI fetches it while booting.
    defaults = client.get("/api/defaults").json()["values"]
    loaded = client.post("/api/catalog/load-default").json()["values"]
    assert defaults == loaded


def test_defaults_endpoint_coerces_to_plain_json():
    values = client.get("/api/defaults").json()["values"]
    assert values["configVersion"] == "2.0.0"
    assert isinstance(values["spawnableCrates"], dict)
    assert isinstance(values["numberOfTroops"], int)


def test_defaults_endpoint_leaves_the_session_untouched():
    client.get("/api/defaults")
    # Reading the defaults is not "opening" a config.
    assert client.get("/api/catalog").status_code == 409


def test_dcs_types_endpoint():
    body = client.get("/api/dcs-types").json()
    assert isinstance(body["types"], list) and body["types"]  # datamine set is non-empty
    assert body["types"] == sorted(body["types"])  # sorted for the picker


def test_load_text_then_get_catalog():
    snap = _load().json()
    assert snap["values"]["numberOfTroops"] == 10
    assert snap["values"]["configVersion"] == "1.0.0"
    # persisted in the session
    again = client.get("/api/catalog").json()
    assert again["values"]["hoverTime"] == 10


def test_load_default():
    snap = client.post("/api/catalog/load-default").json()
    assert snap["values"]["configVersion"] == "2.0.0"
    assert "spawnableCrates" in snap["values"]


def test_get_catalog_without_load_is_409():
    assert client.get("/api/catalog").status_code == 409


def test_load_requires_path_or_text():
    assert client.post("/api/catalog/load", json={}).status_code == 400


def test_load_malformed_yaml_is_422():
    r = client.post("/api/catalog/load", json={"text": "a:\n  - b\n c: bad"})
    assert r.status_code == 422


def test_set_existing_setting():
    _load()
    r = client.put("/api/catalog/setting", json={"key": "numberOfTroops", "value": 25})
    assert r.json() == {"key": "numberOfTroops", "value": 25}
    assert client.get("/api/catalog").json()["values"]["numberOfTroops"] == 25


def test_add_new_setting():
    _load()
    r = client.put("/api/catalog/setting", json={"key": "brandNew", "value": 7})
    assert r.json()["value"] == 7
    assert client.get("/api/catalog").json()["values"]["brandNew"] == 7


def test_delete_setting():
    _load()
    assert client.request("DELETE", "/api/catalog/setting/hoverTime").json() == {"removed": "hoverTime"}
    assert "hoverTime" not in client.get("/api/catalog").json()["values"]


def test_delete_unknown_is_404():
    _load()
    assert client.request("DELETE", "/api/catalog/setting/nope").status_code == 404


def test_save_and_yaml_roundtrip(tmp_path):
    _load()
    client.put("/api/catalog/setting", json={"key": "numberOfTroops", "value": 42})
    out = tmp_path / "saved.yaml"
    assert client.post("/api/catalog/save", json={"path": str(out)}).json() == {"saved": str(out)}
    assert "numberOfTroops: 42" in out.read_text(encoding="utf-8")
    assert "numberOfTroops: 42" in client.get("/api/catalog/yaml").json()["yaml"]


def test_validate_clean_and_bad_unit():
    # The default catalogue is complete by definition, so it is the only clean subject: SAMPLE is a
    # 3-setting snapshot and now reports every parameter it omits (ADR 0011 Addendum 1).
    client.post("/api/catalog/load-default")
    assert client.get("/api/validate").json()["hasErrors"] is False
    _load(BAD_UNIT)
    bad = client.get("/api/validate").json()
    assert bad["hasErrors"] is True
    assert any("NotARealUnit" in f["message"] for f in bad["findings"])


def test_validate_reports_an_incomplete_catalogue():
    """A parameter cannot be removed by omission — an incomplete snapshot must not export.

    ADR 0011 Addendum 1. The engine survives such a config (it falls back to the default and says so
    on screen), but the tool refuses to bless it, because a Mission Maker who *does* use the tool
    should be told before the mission ever runs.
    """
    _load()  # SAMPLE: configVersion + 3 settings, so most of the catalogue is absent
    body = client.get("/api/validate").json()
    assert body["hasErrors"] is True
    missing = [f for f in body["findings"] if f["key"] == "validate.parameter.missing"]
    assert len(missing) > 50, "a 3-setting snapshot omits most of the catalogue's parameters"
    assert all(f["severity"] == "error" for f in missing)


def test_dialog_returns_picked_path(monkeypatch):
    from ctld_tools.web import dialogs

    monkeypatch.setattr(dialogs, "open_config", lambda: "C:/some/config.yaml")
    assert client.get("/api/dialog/open").json() == {"path": "C:/some/config.yaml"}


def test_dialog_unknown_kind_is_404():
    assert client.get("/api/dialog/nope").status_code == 404


def test_inject_into_miz(tmp_path):
    import shutil
    from pathlib import Path

    from ctld_tools.miz import MARKER, read_mission

    src_miz = Path(__file__).resolve().parents[3] / "missions" / "Test_CTLDNEXT_01.miz"
    miz = tmp_path / "out.miz"
    shutil.copy(src_miz, miz)
    client.post("/api/catalog/load-default")  # clean catalogue, no validation errors
    result = client.post("/api/inject", json={"miz": str(miz)}).json()
    assert result["injected"] == str(miz)
    # The install writes more than the configuration now (FEAT-ONE-CLICK-INSTALL): the report is
    # what the UI shows, so it is part of the contract.
    assert result["files"] == ["CTLD.lua", "CTLD_userConfig.lua", "beacon.ogg", "beaconsilent.ogg"]
    assert result["triggers"] == ["configuration", "engine"]
    assert result["engineVersion"] and result["engineVersion"][0].isdigit()
    assert result["replacedPrevious"] is False
    mission = read_mission(miz)
    # The configuration is a *file* now, loaded by resource key — not a Lua string inside the
    # trigger. What the trigger carries is the key; the YAML is in the archive.
    assert "getValueResourceByKey" in mission["trig"]["actions"][1]
    assert mission["trigrules"][1]["comment"] == MARKER

    import zipfile

    with zipfile.ZipFile(miz) as z:
        assert "ctld.configUser" in z.read("l10n/DEFAULT/CTLD_userConfig.lua").decode("utf-8")


def test_inject_blocked_by_validation_errors():
    _load(BAD_UNIT)
    assert client.post("/api/inject", json={"miz": "unused.miz"}).status_code == 422


def test_version_gap_against_default():
    _load()  # SAMPLE is configVersion 1.0.0; default is 2.0.0
    gap = client.get("/api/version-gap").json()
    assert gap["fromVersion"] == "1.0.0"
    assert gap["toVersion"] == "2.0.0"
    assert gap["isEmpty"] is False


def test_troop_groups_hold_counts_not_flags():
    """The web editor types every troop-group field from this shape.

    `jtac` was typed as a boolean in the frontend while the catalogue ships `jtac: 1` / `jtac: 2`,
    which rendered an always-unchecked box and — worse — wrote `true`/`false` over the count when
    touched. If a field here ever legitimately becomes a boolean, this test should fail so the
    frontend is updated deliberately rather than silently corrupting a user's file.
    """
    groups = client.post("/api/catalog/load-default").json()["values"]["loadableGroups"]
    assert groups, "the default catalogue should ship troop groups"
    for group in groups:
        for field, value in group.items():
            if field == "name":
                assert isinstance(value, str), group
            else:
                assert isinstance(value, int) and not isinstance(value, bool), (field, value, group)


# ── i18n_lang: settable, but not in the catalogue (FIX-TOOL-I18N-LANG) ───────────────
# FullGas reported it: the CTLD interface language could not be set from the tool. The engine reads
# it through ctld.gs with a fallback, and the schema declares it with a default and four choices —
# but the app lists *catalogue* keys, and this one is deliberately not in the catalogue. The TUI
# listed schema keys and offered it; the web app lost it in the move.


def test_the_ctld_interface_language_is_offered():
    client.post("/api/catalog/load-default")
    snap = client.get("/api/catalog").json()

    assert "i18n_lang" in snap["keys"]
    assert snap["values"]["i18n_lang"] == "en"


def test_it_is_not_marked_as_changed_before_it_is_touched():
    """Its default has to come back from /api/defaults too, or the UI flags it permanently."""
    client.post("/api/catalog/load-default")
    snap = client.get("/api/catalog").json()
    defaults = client.get("/api/defaults").json()["values"]

    assert defaults["i18n_lang"] == snap["values"]["i18n_lang"]


def test_the_schema_offers_the_four_languages():
    schema = client.get("/api/schema").json()
    assert schema["keys"]["i18n_lang"]["choices"] == ["en", "fr", "es", "ko"]
    assert schema["keys"]["i18n_lang"]["standard"] is True


def test_setting_it_writes_it_into_the_mission_facing_section():
    """`standard:` settings belong in mm_facing; the interface language is not an internal."""
    client.post("/api/catalog/load-default")
    client.put("/api/catalog/setting", json={"key": "i18n_lang", "value": "fr"})

    snap = client.get("/api/catalog").json()
    assert snap["values"]["i18n_lang"] == "fr"
    assert snap["keys"].count("i18n_lang") == 1, "must not appear twice once catalogued"

    yaml_text = client.get("/api/catalog/yaml").json()["yaml"]
    mm_facing = yaml_text.split("advanced:")[0]
    assert "i18n_lang: fr" in mm_facing


def test_it_stays_out_of_the_completeness_check():
    """Adding it to the catalogue would demand it of every rc1–rc3 config. It must not be demanded."""
    client.post("/api/catalog/load-default")
    findings = client.get("/api/validate").json()["findings"]
    assert not [f for f in findings if "i18n_lang" in str(f)]


# ── /api/version (FEAT-TOOL-VERSION-AND-DOCS) ────────────────────────────────────────


def test_version_endpoint_reports_ctld_and_its_docs_version():
    body = client.get("/api/version").json()
    from ctld_tools import resources

    assert body["ctld"] == resources.ctld_version()
    assert body["docs"] == resources.docs_version()


def test_version_endpoint_needs_no_catalogue():
    """The frontend reads it while booting, before anything is loaded."""
    session._catalog = None
    assert client.get("/api/version").status_code == 200


def test_the_api_declares_the_ctld_version_not_a_literal():
    from ctld_tools import resources
    from ctld_tools.web.app import app as fastapi_app

    assert fastapi_app.version == resources.ctld_version()
