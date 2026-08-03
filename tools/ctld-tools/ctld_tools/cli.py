"""Typer CLI for ctld-tools — trimmed to what the build/CI need.

ctld-tools embed     --yaml src/CTLD_config.yaml --out src/CTLD_config_default_yaml.lua
ctld-tools gen       --yaml src/CTLD_config.yaml --out tests/ci/data/config_defaults.json
ctld-tools validate  --yaml a-complete-config.yaml [--schema src/CTLD_config_schema.yaml]
                     [--default src/CTLD_config.yaml]   # completeness; bundled one by default

A bare invocation / double-click (no command) boots the local web app instead — the
Mission-Maker surface, a thin wrapper over this package's library (catalog / schema /
validate / versiongap / embed / miz).
"""

from __future__ import annotations

import sys
from pathlib import Path

import typer

from ctld_tools.i18n import set_language, t

app = typer.Typer(
    no_args_is_help=True,
    add_completion=False,
)


@app.callback(help=t("app.description"))
def _root(
    lang: str = typer.Option(None, "--lang", help=t("help.lang")),
) -> None:
    # Root options shared by every command; --lang forces the output language.
    if lang:
        set_language(lang)


@app.command("embed")
def embed_cmd(
    yaml_path: Path = typer.Option(..., "--yaml", help="path to the config YAML to embed"),
    out: Path = typer.Option(..., "--out", help="path to the Lua string module to write"),
    var: str = typer.Option("configDefault", "--var", help="ctld.<var> to assign (configDefault / configUser)"),
) -> None:
    """Wrap a config YAML verbatim into a ctld.<var> Lua string module (build step)."""
    from ctld_tools.embed import wrap_file

    wrap_file(yaml_path, out, var)
    typer.echo(f"embed: wrote {out} (ctld.{var})")


@app.command("gen")
def gen_cmd(
    yaml_path: Path = typer.Option(..., "--yaml", help="path to the config YAML (source of truth)"),
    out: Path = typer.Option(..., "--out", help="path to the JSON defaults oracle to write"),
) -> None:
    """Emit the flat engine defaults as the JSON parity oracle (busted round-trip test)."""
    from ctld_tools.oracle import write_json

    write_json(yaml_path, out)
    typer.echo(f"gen: wrote {out}")


@app.command("validate")
def validate_cmd(
    yaml_path: Path = typer.Option(..., "--yaml", help="path to a complete config YAML to validate"),
    schema_path: Path = typer.Option(None, "--schema", help="path to CTLD_config_schema.yaml (enables choices checks)"),
    default_path: Path = typer.Option(
        None,
        "--default",
        help="path to the reference CTLD_config.yaml (enables the completeness check; bundled one by default)",
    ),
) -> None:
    """Validate a complete config catalogue against the DCS types and schema."""
    from ctld_tools import resources
    from ctld_tools.catalog import Catalog
    from ctld_tools.schema import Schema
    from ctld_tools.validate import has_errors, validate

    catalog = Catalog.load(yaml_path)
    schema = Schema.load(schema_path) if schema_path else Schema({})
    # The completeness check needs a reference catalogue (ADR 0011 Addendum 1). Fall back to the
    # bundled default so `validate --yaml x.yaml` checks completeness without extra ceremony.
    reference = Path(default_path) if default_path else resources.default_catalog_path()
    default = Catalog.load(reference) if reference.exists() else None
    findings = validate(catalog, schema, default=default)
    for finding in findings:
        typer.echo(str(finding))
    if not findings:
        typer.echo("validate: OK")
    if has_errors(findings):
        raise typer.Exit(1)


@app.command("payloads")
def payloads_cmd() -> None:
    """List the payloads this build carries: the catalogue, the schema, the engine, the sounds.

    A diagnostic, and the release's guard: the exe installs these into a mission, so a bundle that
    lost an `--add-data` entry must fail here rather than in DCS. Exits non-zero if any is missing.
    """
    from ctld_tools import resources

    entries = [
        ("catalogue", resources.default_catalog_path()),
        ("schema", resources.schema_path()),
        ("engine", resources.engine_path()),
        *[("sound", p) for p in resources.sound_paths()],
    ]
    missing = False
    for label, path in entries:
        if path.is_file():
            typer.echo(f"{label:10} {path.name:28} {path.stat().st_size:>9} bytes")
        else:
            typer.echo(f"{label:10} {path.name:28} MISSING ({path})")
            missing = True
    if missing:
        raise typer.Exit(1)


@app.command("serve")
def serve_cmd(
    port: int = typer.Option(None, "--port", help="port to serve on (default: an ephemeral free port)"),
    no_browser: bool = typer.Option(False, "--no-browser", help="do not open the browser"),
) -> None:
    """Start the local web app (also the default on a bare invocation / double-click)."""
    from ctld_tools.web.launcher import serve

    serve(port=port, open_browser=not no_browser)


def main() -> None:
    # Typer builds the (already-translated) help= strings before the callback runs, so
    # parse --lang manually and early — that way even `--help` prints in the right language.
    argv = sys.argv[1:]
    for i, arg in enumerate(argv):
        if arg == "--lang" and i + 1 < len(argv):
            set_language(argv[i + 1])
            break
        if arg.startswith("--lang="):
            set_language(arg.split("=", 1)[1])
            break
    # No command (bare invocation / double-click) → boot the web app; else run the CLI.
    from ctld_tools.web.launcher import resolve_action, serve

    if resolve_action(argv) == "serve":
        serve()
        return
    app()


if __name__ == "__main__":
    main()
