"""Typer CLI for ctld-tools.

ctld-tools extract     --config-lua src/CTLD_config.lua --out src/CTLD_config.yaml
ctld-tools gen-config  --yaml src/CTLD_config.yaml --out src/CTLD_config_defaults.lua
"""

from __future__ import annotations

from pathlib import Path

import typer

app = typer.Typer(
    help="CTLD configuration authoring & generation.",
    no_args_is_help=True,
    add_completion=False,
)


@app.command("extract")
def extract_cmd(
    config_lua: Path = typer.Option(..., "--config-lua", help="path to src/CTLD_config.lua"),
    out: Path = typer.Option(..., "--out", help="path to the ctld-config.yaml to write"),
) -> None:
    """One-shot: extract the current CTLD_config.lua defaults to a sectioned YAML."""
    from ctld_tools.extract import extract_file

    extract_file(config_lua, out)
    typer.echo(f"extract: wrote {out}")


@app.command("gen-config")
def gen_config_cmd(
    yaml_path: Path = typer.Option(..., "--yaml", help="path to ctld-config.yaml (source of truth)"),
    out: Path = typer.Option(..., "--out", help="path to the generated Lua defaults module"),
) -> None:
    """Render the Lua defaults module from ctld-config.yaml (build step)."""
    from ctld_tools.genconfig import generate_file

    generate_file(yaml_path, out)
    typer.echo(f"gen-config: wrote {out}")


def main() -> None:
    app()


if __name__ == "__main__":
    main()
