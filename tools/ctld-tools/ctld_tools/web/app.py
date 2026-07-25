"""FastAPI app — thin endpoints wrapping the ctld-tools core.

Load / read / edit / save a complete catalogue, validate it, and diff its version against the
current default. No business logic: each route delegates to the lot-2 library.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from ctld_tools.validate import has_errors, validate
from ctld_tools.versiongap import version_gap
from ctld_tools.web.state import session

app = FastAPI(title="ctld-tools", version="2.0")


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


def _snapshot() -> dict[str, Any]:
    cat = session.catalog
    return {
        "path": str(session.path) if session.path else None,
        "keys": cat.keys(),
        "values": {k: _plain(cat.get(k)) for k in cat.keys()},
    }


# ── routes ─────────────────────────────────────────────────────────
@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/api/schema")
def get_schema() -> dict[str, Any]:
    """Authoring metadata for the frontend nav: families + per-key group/standard/choices/desc."""
    schema = session.schema
    keys = {
        k: {
            "group": schema.group(k),
            "standard": schema.standard(k),
            "choices": schema.choices(k),
            "description": schema.description(k),
        }
        for k in schema.keys()
    }
    tables = {
        table: {field: (meta or {}).get("en") for field, meta in fields.items()}
        for table, fields in schema.table_fields().items()
    }
    from ctld_tools.web.zones import ZONE_FIELD_SCHEMAS

    return {"families": schema.families(), "keys": keys, "tableFields": tables, "zoneFields": ZONE_FIELD_SCHEMAS}


@app.get("/api/dcs-types")
def dcs_types() -> dict[str, list[str]]:
    """The datamine DCS type-name set — source for the aircraft/unit pickers."""
    from ctld_tools.datamine import known_dcs_types

    return {"types": sorted(known_dcs_types())}


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
        try:
            cat.add_setting(req.key, req.value, section=req.section)
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
    findings = validate(cat, session.schema)
    return {
        "hasErrors": has_errors(findings),
        "findings": [{"severity": f.severity, "where": f.where, "key": f.key, "message": f.message} for f in findings],
    }


@app.get("/api/dialog/{kind}")
def dialog(kind: str) -> dict[str, str | None]:
    """Open a native OS file dialog (open / save / miz) and return the chosen path (or null)."""
    from ctld_tools.web import dialogs

    picker = {"open": dialogs.open_config, "save": dialogs.save_config, "miz": dialogs.pick_miz}.get(kind)
    if picker is None:
        raise HTTPException(status_code=404, detail=f"unknown dialog: {kind}")
    return {"path": picker()}


@app.post("/api/inject")
def inject(req: InjectRequest) -> dict[str, str]:
    """Export the current catalogue as ctld.configUser and inject it into a .miz (idempotent)."""
    from ctld_tools.embed import wrap
    from ctld_tools.miz import inject_userconfig

    try:
        cat = session.catalog
    except LookupError as exc:
        raise HTTPException(status_code=409, detail="no catalogue loaded") from exc
    if has_errors(validate(cat, session.schema)):
        raise HTTPException(status_code=422, detail="fix validation errors before injecting")
    inject_userconfig(req.miz, wrap(cat.dumps(), "configUser"), req.miz)
    return {"injected": req.miz}


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
