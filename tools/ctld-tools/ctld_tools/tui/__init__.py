"""Interactive TUI for ctld-tools (the MM console).

Kept import-light: importing this package must not pull in textual, so the pure
filter logic (`filter.py`) stays usable on its own. The textual widgets/app live in
`widgets.py` / `app.py` and are imported only when the TUI actually runs.
"""
