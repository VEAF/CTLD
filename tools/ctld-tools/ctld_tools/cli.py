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


@app.command("validate")
def validate_cmd(
    yaml_path: Path = typer.Option(..., "--yaml", help="path to the user-config.yaml"),
    src: Path = typer.Option(..., "--src", help="path to the CTLD src/ directory (the reference)"),
) -> None:
    """Validate a user-config.yaml against the reference catalogue and DCS types."""
    from ctld_tools.reference import Reference
    from ctld_tools.validate import has_errors, load_user_config, validate

    findings = validate(load_user_config(yaml_path), Reference.from_src(src))
    for finding in findings:
        typer.echo(str(finding))
    if not findings:
        typer.echo("validate: OK")
    if has_errors(findings):
        raise typer.Exit(1)


@app.command("gen-user")
def gen_user_cmd(
    out: Path = typer.Option(..., "--out", help="path to the CTLD_userConfig.lua (or scaffold) to write"),
    yaml_path: Path = typer.Option(None, "--yaml", help="path to the user-config.yaml (omit with --scaffold)"),
    src: Path = typer.Option(None, "--src", help="path to the CTLD src/ directory (the reference)"),
    scaffold: bool = typer.Option(False, "--scaffold", help="write a commented starter user-config.yaml instead"),
) -> None:
    """Compile a user-config.yaml into CTLD_userConfig.lua (or write a scaffold)."""
    if scaffold:
        from ctld_tools.scaffold import write_scaffold

        write_scaffold(out)
        typer.echo(f"gen-user: wrote scaffold {out}")
        return
    if yaml_path is None or src is None:
        raise typer.BadParameter("--yaml and --src are required (unless --scaffold)")
    from ctld_tools.genuser import UserConfigError, generate_user_file

    try:
        generate_user_file(yaml_path, src, out)
    except UserConfigError as exc:
        for finding in exc.findings:
            typer.echo(str(finding))
        raise typer.Exit(1) from exc
    typer.echo(f"gen-user: wrote {out}")


@app.command("inject")
def inject_cmd(
    miz: Path = typer.Option(..., "--miz", help="the .miz mission to modify"),
    userconfig: Path = typer.Option(..., "--userconfig", help="the generated CTLD_userConfig.lua"),
    out: Path = typer.Option(None, "--out", help="output .miz (default: overwrite --miz)"),
) -> None:
    """Inject a generated CTLD_userConfig.lua into a .miz as a MISSION START trigger (idempotent)."""
    from ctld_tools.miz import inject_userconfig

    target = out or miz
    inject_userconfig(miz, userconfig.read_text(encoding="utf-8"), target)
    typer.echo(f"inject: wrote {target}")


def main() -> None:
    app()


if __name__ == "__main__":
    main()
