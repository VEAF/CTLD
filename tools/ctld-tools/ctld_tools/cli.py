"""Typer CLI for ctld-tools — trimmed to what the build/CI need.

ctld-tools embed     --yaml src/CTLD_config.yaml --out src/CTLD_config_default_yaml.lua
ctld-tools gen       --yaml src/CTLD_config.yaml --out tests/ci/data/config_defaults.json
ctld-tools validate  --yaml a-complete-config.yaml [--schema src/CTLD_config_schema.yaml]

No CLI UX investment: the Mission-Maker surface is the lot-3 web app, a thin wrapper over
this package's library (catalog / schema / validate / versiongap / embed / miz).
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
) -> None:
    """Validate a complete config catalogue against the DCS types and schema."""
    from ctld_tools.catalog import Catalog
    from ctld_tools.schema import Schema
    from ctld_tools.validate import has_errors, validate

    catalog = Catalog.load(yaml_path)
    schema = Schema.load(schema_path) if schema_path else Schema({})
    findings = validate(catalog, schema)
    for finding in findings:
        typer.echo(str(finding))
    if not findings:
        typer.echo("validate: OK")
    if has_errors(findings):
        raise typer.Exit(1)


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
    app()


if __name__ == "__main__":
    main()
