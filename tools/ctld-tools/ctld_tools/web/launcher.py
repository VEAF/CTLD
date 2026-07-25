"""Double-click launcher — boot the web app, or fall through to the CLI.

The single console exe (ADR 0011 point 8) is both the CLI and the GUI launcher. A bare
invocation / double-click boots a local uvicorn and opens the browser; an explicit command
(`embed` / `validate` / `gen`) runs headless. Double-click is detected by walking the parent
process tree (explorer.exe vs a terminal), the pattern from VMCT's `_is_double_clicked`.
"""

from __future__ import annotations

# Terminal / shell processes: an ancestor of one of these means we were launched from a
# console, not double-clicked.
_SHELLS = frozenset(
    {
        "cmd.exe",
        "powershell.exe",
        "pwsh.exe",
        "pwsh",
        "wt.exe",
        "bash.exe",
        "bash",
        "sh",
        "zsh",
        "fish",
    }
)
# Skipped while walking up: they sit between a console app and its real launcher.
_TRANSPARENT = frozenset({"conhost.exe", "openconsole.exe"})

_LANG_OPT = "--lang"


def _ancestor_names() -> list[str]:
    try:
        import os

        import psutil

        return [p.name() for p in psutil.Process(os.getpid()).parents()]
    except Exception:
        return []


def is_double_clicked(ancestor_names: list[str] | None = None) -> bool:
    """True if the nearest meaningful ancestor is Explorer (double-click), not a shell."""
    names = _ancestor_names() if ancestor_names is None else ancestor_names
    for name in names:
        n = name.lower()
        if n in _TRANSPARENT:
            continue
        if n in _SHELLS:
            return False
        if n == "explorer.exe":
            return True
    return False


def resolve_action(argv: list[str]) -> str:
    """Route an argv (sans program name) to 'serve' (bare/double-click) or 'cli' (a command)."""
    rest: list[str] = []
    skip = False
    for arg in argv:
        if skip:
            skip = False
            continue
        if arg in ("--help", "-h"):
            return "cli"  # let Typer print help
        if arg == _LANG_OPT:
            skip = True  # drop the value-taking global option + its value
            continue
        if arg.startswith(f"{_LANG_OPT}="):
            continue
        rest.append(arg)
    has_command = any(not token.startswith("-") for token in rest)
    return "cli" if has_command else "serve"


def serve(host: str = "127.0.0.1", port: int | None = None, open_browser: bool = True) -> None:
    """Boot uvicorn on a local port and open the browser; the console is the lifecycle window."""
    import socket
    import webbrowser

    import uvicorn

    if port is None:
        with socket.socket() as probe:
            probe.bind((host, 0))
            port = probe.getsockname()[1]
    url = f"http://{host}:{port}"
    if is_double_clicked():
        print(f"CTLD tools is running at {url} — close this window to quit.")
    else:
        print(f"CTLD tools serving at {url} (Ctrl+C to stop).")
    if open_browser:
        webbrowser.open(url)
    uvicorn.run("ctld_tools.web.app:app", host=host, port=port, log_level="warning")
