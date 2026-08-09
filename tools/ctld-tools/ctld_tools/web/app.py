"""FastAPI app — thin endpoints wrapping the ctld-tools core.

Load / read / edit / save a complete catalogue, validate it, and diff its version against the
current default. No business logic: each route delegates to the lot-2 library.
"""

from __future__ import annotations

import zipfile
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from ctld_tools import resources
from ctld_tools.validate import has_errors, validate
from ctld_tools.versiongap import version_gap
from ctld_tools.web.state import session

# The API's version is CTLD's — one source of truth (ctld.VERSION), never a literal here.
app = FastAPI(title="ctld-tools", version=resources.ctld_version())

# The web UI's slice of the i18n catalog (`tui.*` belongs to the retired TUI).
_WEB_PREFIX = "web."


# ── request bodies ─────────────────────────────────────────────────
class LoadRequest(BaseModel):
    path: str | None = None
    text: str | None = None


class SettingRequest(BaseModel):
    key: str
    value: Any = None
    section: str = "advanced"


class SaveRequest(BaseModel):
    path: str


class InjectRequest(BaseModel):
    miz: str


# ── helpers ────────────────────────────────────────────────────────
def _plain(v: Any) -> Any:
    """Coerce ruamel round-trip types (dict/list/scalar subclasses) to plain JSON types."""
    if isinstance(v, dict):
        return {k: _plain(x) for k, x in v.items()}
    if isinstance(v, (list, tuple)):
        return [_plain(x) for x in v]
    if isinstance(v, bool):
        return v
    if isinstance(v, str):
        return str(v)
    if isinstance(v, int):
        return int(v)
    if isinstance(v, float):
        return float(v)
    return v


def _settable_but_uncatalogued() -> dict[str, Any]:
    """Settings the schema declares with a default that the **engine catalogue** does not carry.

    Exactly one today, `i18n_lang`: the engine reads it through `ctld.gs("i18n_lang")` with a
    fallback, so setting it works — but it is deliberately absent from the catalogue, and the app
    lists *catalogue* keys. The TUI listed schema keys and offered it; the web app lost it in the
    move. Surfaced here rather than added to the catalogue, which would make it a **parameter**
    under ADR 0011 Addendum 1: the completeness rule would then demand it of every snapshot, and
    every configuration written for rc1–rc3 would report a missing setting at mission start.

    Keyed off the **default** catalogue, never the open one, for two reasons: it is a property of the
    engine rather than of the document being edited, and `/api/defaults` must answer before anything
    is loaded — the UI fetches it while booting.
    """
    reference = session.default_catalog()
    schema = session.schema
    out: dict[str, Any] = {}
    for key in schema.keys():
        if reference.has(key):
            continue
        default = schema.default(key)
        if default is not None:
            out[key] = default
    return out


def _snapshot() -> dict[str, Any]:
    cat = session.catalog
    # Offer the uncatalogued settings the open document has not set yet; once the Mission Maker sets
    # one it lives in their catalogue, and adding it here again would list it twice.
    extra = {k: v for k, v in _settable_but_uncatalogued().items() if not cat.has(k)}
    values = {k: _plain(cat.get(k)) for k in cat.keys()}
    values.update(extra)
    return {
        "path": str(session.path) if session.path else None,
        "keys": [*cat.keys(), *extra],
        "values": values,
    }


# ── routes ─────────────────────────────────────────────────────────
@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/version")
def get_version() -> dict[str, str]:
    """The CTLD version this build belongs to, and the documentation version to link to.

    `docs` is resolved here rather than in the frontend so the rule — a pre-release points at `dev`,
    a stable at itself — exists once, next to the version it derives from.
    """
    return {"ctld": resources.ctld_version(), "docs": resources.docs_version()}


@app.get("/api/i18n")
def get_i18n(lang: str | None = None) -> dict[str, Any]:
    """The web UI's translated strings (the `web.*` catalog keys) for `lang`.

    The frontend owns the active language (the user can switch it); this returns the catalog for
    whichever one it asks for, defaulting to the language resolved from the OS locale.
    """
    from ctld_tools import i18n

    requested = (lang or i18n.current_language()).strip().lower()[:2]
    with i18n.language(requested):
        strings = {key: i18n.t(key) for key in i18n.catalog_keys(prefix=_WEB_PREFIX)}
    return {"lang": requested, "available": i18n.available_languages(), "strings": strings}


@app.get("/api/schema")
def get_schema(lang: str | None = None) -> dict[str, Any]:
    """Authoring metadata for the frontend: families + per-key group/standard/choices/description.

    Descriptions, family labels and field headings follow `lang` (the schema stores them bilingually),
    so switching language in the UI translates the settings themselves, not just the chrome.
    """
    from ctld_tools import i18n

    language = (lang or i18n.current_language()).strip().lower()[:2]
    schema = session.schema
    keys = {
        k: {
            "group": schema.group(k),
            "standard": schema.standard(k),
            "choices": schema.choices(k),
            "editor": schema.editor(k),
            "hidden": schema.hidden(k),
            "label": schema.label(k, language),
            "unit": schema.unit(k),
            "description": schema.description(k, language) or schema.description(k),
        }
        for k in schema.keys()
    }
    # A table field carries its help text and, when the value set is closed, its `choices`.
    # The vocabulary lives in the schema so a Mission Maker editing the YAML by hand reads the
    # same list the app offers — a literal in a Svelte component would help neither them nor a
    # reviewer checking the UI against the engine.
    tables = {
        table: {
            field: {
                "tip": (meta or {}).get(language) or (meta or {}).get("en"),
                "choices": (meta or {}).get("choices"),
            }
            for field, meta in fields.items()
        }
        for table, fields in schema.table_fields().items()
    }
    families = {
        family: {
            "label": schema.family_label(family, language),
            "description": schema.family_description(family, language),
            "order": schema.family_order(family),
        }
        for family in schema.family_meta()
    }
    from ctld_tools.web.zones import ZONE_FIELD_SCHEMAS

    return {
        "families": schema.families(),
        "familyMeta": families,
        "keys": keys,
        "tableFields": tables,
        "zoneFields": ZONE_FIELD_SCHEMAS,
    }


@app.get("/api/defaults")
def get_defaults() -> dict[str, Any]:
    """The CTLD default values, flat.

    Lets the UI mark a setting as changed from the default and offer a one-click reset — editing is
    otherwise a one-way door, which makes a non-technical MM afraid to touch anything.

    Includes the schema-declared defaults of settings the catalogue does not carry (see
    `_settable_but_uncatalogued`): without them the UI compares a value against nothing and marks the
    setting permanently modified.
    """
    cat = session.default_catalog()
    values = {k: _plain(cat.get(k)) for k in cat.keys()}
    values.update(_settable_but_uncatalogued())
    return {"values": values}


@app.get("/api/dcs-types")
def dcs_types() -> dict[str, Any]:
    """The datamine DCS type-name set, plus how each type must be spawned.

    `spawnAs` resolves the authoring convenience `AIR` to the `AIRPLANE` or `HELICOPTER` the
    engine hands DCS. It is computed here rather than in the frontend so the datamine-category
    mapping exists once, in Python, next to the data it reads.
    """
    from ctld_tools.datamine import known_dcs_types, spawn_category

    types = sorted(known_dcs_types())
    return {"types": types, "spawnAs": {name: spawn_category(name) for name in types}}


@app.post("/api/catalog/load")
def load_catalog(req: LoadRequest) -> dict[str, Any]:
    if req.text is not None:
        try:
            session.load_text(req.text)
        except Exception as exc:  # malformed YAML
            raise HTTPException(status_code=422, detail=f"malformed YAML: {exc}") from exc
    elif req.path is not None:
        try:
            session.load_path(req.path)
        except FileNotFoundError as exc:
            raise HTTPException(status_code=404, detail=f"file not found: {req.path}") from exc
        except Exception as exc:
            raise HTTPException(status_code=422, detail=f"could not load: {exc}") from exc
    else:
        raise HTTPException(status_code=400, detail="provide 'path' or 'text'")
    return _snapshot()


@app.post("/api/catalog/load-default")
def load_default() -> dict[str, Any]:
    session.load_default()
    return _snapshot()


@app.get("/api/catalog")
def get_catalog() -> dict[str, Any]:
    try:
        return _snapshot()
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc


@app.get("/api/catalog/yaml")
def get_catalog_yaml() -> dict[str, str]:
    try:
        return {"yaml": session.catalog.dumps()}
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc


@app.put("/api/catalog/setting")
def put_setting(req: SettingRequest) -> dict[str, Any]:
    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    if cat.has(req.key):
        cat.set(req.key, req.value)
    else:
        # A setting the schema marks `standard:` is Mission-Maker-facing, so it belongs in
        # mm_facing — the sections are a readability split, and putting `i18n_lang` under
        # `advanced` would file the interface language with the internals.
        section = req.section
        if section == "advanced" and session.schema.standard(req.key):
            section = "mm_facing"
        try:
            cat.add_setting(req.key, req.value, section=section)
        except ValueError as exc:  # bad section
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"key": req.key, "value": _plain(cat.get(req.key))}


@app.delete("/api/catalog/setting/{key}")
def delete_setting(key: str) -> dict[str, Any]:
    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    try:
        cat.remove(key)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=f"unknown key: {key}") from exc
    return {"removed": key}


@app.post("/api/catalog/save")
def save_catalog(req: SaveRequest) -> dict[str, str]:
    try:
        session.catalog.save(req.path)
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    return {"saved": req.path}


@app.get("/api/validate")
def run_validate() -> dict[str, Any]:
    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    findings = validate(
        cat,
        session.schema,
        default=session.default_catalog(),
        sounds_available=_sounds_available(session.mission_path),
    )
    return {
        "hasErrors": has_errors(findings),
        "findings": [{"severity": f.severity, "where": f.where, "key": f.key, "message": f.message} for f in findings],
    }


def _sounds_available(target: str | Path | None = None) -> set[str]:
    """Which beacon sounds an install could actually write right now.

    A customised sound is writable when the session holds its bytes — picked from disk, or read out
    of the mission that was opened — **or** when the target mission already carries a file of that
    name. The second case is the Mission Maker reinstalling over the same mission, or one who put
    the file there through the Mission Editor: nothing is missing, so nothing should be reported.
    """
    from ctld_tools.install import L10N, custom_sound_name

    cat = session.catalog
    out = set(session.sounds())
    if target is None:
        return out
    path = Path(target)
    if not path.is_file():
        return out
    try:
        with zipfile.ZipFile(path) as z:
            members = set(z.namelist())
    except (zipfile.BadZipFile, OSError):
        return out
    for setting in resources.SOUND_SETTINGS:
        name = custom_sound_name(cat, setting)
        if name and f"{L10N}/{name}" in members:
            out.add(setting)
    return out


def _target_sounds(target: str | Path, catalog: Any) -> dict[str, bytes]:
    """Customised sounds the target mission already carries, so a reinstall can rewrite them."""
    from ctld_tools.install import read_sounds_from_miz

    path = Path(target)
    if not path.is_file():
        return {}
    try:
        return read_sounds_from_miz(path, catalog)
    except (zipfile.BadZipFile, OSError):
        return {}


def _sound_state() -> list[dict[str, Any]]:
    """What the UI needs to render the two pickers: source, name, size, availability."""
    cat = session.catalog
    state: list[dict[str, Any]] = []
    for setting, spec in resources.SOUND_SETTINGS.items():
        value = cat.get(setting)
        custom = value == spec["custom"]
        held = session.sound(setting)
        state.append(
            {
                "setting": setting,
                "custom": custom,
                "file": value,
                "originalName": cat.get(spec["label"]) if custom else None,
                "size": len(held) if held is not None else None,
                "available": (not custom) or setting in _sounds_available(session.mission_path),
            }
        )
    return state


@app.get("/api/sounds")
def get_sounds() -> dict[str, Any]:
    try:
        session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    return {"sounds": _sound_state()}


@app.post("/api/sounds/{setting}/custom")
def choose_sound(setting: str) -> dict[str, Any]:
    """Pick a beacon sound from disk: read it now, keep the bytes, point the setting at them.

    The bytes are read **here**, not at install time, so the choice survives the file being moved,
    the drive being unplugged, or the configuration being carried to another machine — the whole
    point of ADR 0012's model.
    """
    spec = resources.SOUND_SETTINGS.get(setting)
    if spec is None:
        raise HTTPException(status_code=404, detail=f"not a beacon sound setting: {setting}")
    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc

    from ctld_tools.web import dialogs

    chosen = dialogs.pick_sound()
    if not chosen:
        return {"cancelled": True}
    path = Path(chosen)
    data = path.read_bytes()
    if not resources.is_ogg(data):
        raise HTTPException(
            status_code=422,
            detail=f"{path.name} is not an Ogg file (no OggS signature) — DCS would play nothing",
        )

    session.set_sound(setting, data)
    cat.set(setting, spec["custom"])
    if cat.has(spec["label"]):
        cat.set(spec["label"], path.name)
    else:
        cat.add_setting(spec["label"], path.name)
    return {"setting": setting, "file": spec["custom"], "originalName": path.name, "size": len(data)}


@app.post("/api/sounds/{setting}/default")
def reset_sound(setting: str) -> dict[str, Any]:
    """Go back to the bundled sound: drop the bytes, the reserved name and the label."""
    spec = resources.SOUND_SETTINGS.get(setting)
    if spec is None:
        raise HTTPException(status_code=404, detail=f"not a beacon sound setting: {setting}")
    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc

    session.drop_sound(setting)
    cat.set(setting, spec["default"])
    if cat.has(spec["label"]):
        cat.remove(spec["label"])
    return {"setting": setting, "file": spec["default"]}


@app.get("/api/dialog/{kind}")
def dialog(kind: str) -> dict[str, str | None]:
    """Open a native OS file dialog (open / save / miz) and return the chosen path (or null)."""
    from ctld_tools.web import dialogs

    picker = {"open": dialogs.open_config, "save": dialogs.save_config, "miz": dialogs.pick_miz}.get(kind)
    if picker is None:
        raise HTTPException(status_code=404, detail=f"unknown dialog: {kind}")
    return {"path": picker()}


@app.post("/api/inject")
def inject(req: InjectRequest) -> dict[str, Any]:
    """Install CTLD into a `.miz`: the engine, the beacon sounds, the configuration, the triggers.

    Named `/api/inject` for continuity, but it stopped being configuration-only with
    FEAT-ONE-CLICK-INSTALL — a Mission Maker now needs nothing but this tool. Returns what was
    written so the UI can say so without reopening the archive: claiming "installed" and leaving the
    user to verify in the Mission Editor is how the old five-step journey started.
    """
    from ctld_tools.embed import wrap
    from ctld_tools.install import install

    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    # Validated against the **target** mission, not the open one: a customised sound already sitting
    # in the mission being written to is not missing, wherever the configuration came from.
    findings = validate(
        cat,
        session.schema,
        default=session.default_catalog(),
        sounds_available=_sounds_available(req.miz),
    )
    if has_errors(findings):
        raise HTTPException(status_code=422, detail="fix validation errors before injecting")
    try:
        report = install(
            req.miz,
            wrap(cat.dumps(), "configUser"),
            req.miz,
            catalog=cat,
            # The session wins where it has something; the target mission fills the rest, which is
            # the "already there" case validation just allowed. Merged, not `or`-ed: one sound may
            # come from each side.
            held_sounds={**_target_sounds(req.miz, cat), **session.sounds()},
        )
    except FileNotFoundError as exc:  # a checkout with no built engine, or a missing .miz
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    changed = sum(1 for k in cat.keys() if cat.get(k) != session.default_catalog().get(k))
    return {
        "injected": req.miz,
        "mission": report.miz,
        "engineVersion": report.engine_version,
        "files": report.files,
        "triggers": report.triggers,
        "replacedPrevious": report.replaced_previous,
        "changedSettings": changed,
        "sounds": report.sounds,
    }


@app.get("/api/version-gap")
def get_version_gap() -> dict[str, Any]:
    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    gap = version_gap(cat, session.default_catalog())
    return {
        "fromVersion": gap.from_version,
        "toVersion": gap.to_version,
        "isEmpty": gap.is_empty,
        "added": gap.added,
        "removed": gap.removed,
        "changed": [{"key": c.key, "old": _plain(c.old), "new": _plain(c.new)} for c in gap.changed],
    }


# The built frontend (Vite → ctld_tools/web/static, bundled into the exe). Mounted last so
# every /api route wins; absent in a bare dev checkout (run the Vite dev server instead).
_STATIC = Path(__file__).parent / "static"
if _STATIC.is_dir():
    app.mount("/", StaticFiles(directory=str(_STATIC), html=True), name="static")
