"""Typer CLI for ctld-tools.

ctld-tools extract     --config-lua src/CTLD_config.lua --out src/CTLD_config.yaml
ctld-tools gen-config  --yaml src/CTLD_config.yaml --out src/CTLD_config_defaults.lua
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


@app.command("gen-reference")
def gen_reference_cmd(
    src: Path = typer.Option(..., "--src", help="path to the CTLD src/ directory (the reference source)"),
    out: Path = typer.Option(..., "--out", help="path to the reference bundle JSON to write"),
) -> None:
    """Freeze the embedded reference bundle from src/ (build step, lupa)."""
    from ctld_tools.genreference import write_reference

    write_reference(src, out)
    typer.echo(f"gen-reference: wrote {out}")


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


def _bridge_target(args: list[str], is_tty: bool) -> list[str] | None:
    """Route a command-less invocation into the TUI (VMCT approach).

    When the tool is double-clicked from Explorer it runs with no command in a fresh
    console (a tty), so an interactive terminal with no command → launch `tui`, carrying
    any global options already given (e.g. --lang). Returns the rewritten args, or None
    to let Typer run as-is (a real command, `--help`, or a non-interactive stdout).
    """
    if not is_tty:
        return None
    if any(a in ("--help", "-h") for a in args):
        return None
    # Drop the only value-taking global option (--lang) so its value isn't mistaken
    # for a command, then: any remaining bare token means an explicit command was given.
    rest, skip = [], False
    for arg in args:
        if skip:
            skip = False
        elif arg == "--lang":
            skip = True
        elif not arg.startswith("--lang="):
            rest.append(arg)
    if any(not token.startswith("-") for token in rest):
        return None
    return ["tui", *args]


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
    # Double-click from Explorer (no command, fresh console) → launch the TUI.
    is_tty = bool(sys.stdout) and sys.stdout.isatty()
    target = _bridge_target(argv, is_tty)
    if target is not None:
        sys.argv = sys.argv[:1] + target
    app()


if __name__ == "__main__":
    main()
