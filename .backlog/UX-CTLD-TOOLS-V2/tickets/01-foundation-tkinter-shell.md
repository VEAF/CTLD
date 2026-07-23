# 01 — Foundation: tkinter shell + sv-ttk + tooltip helper

Status: ready

## What to build

Replace the Textual stack with a tkinter/sv-ttk application shell. This slice delivers
the empty container that all subsequent editor slices build inside: a two-panel window
(catalogue tree left, form right) with a pinned footer, wired to the `tui` CLI command,
styled with the Sun Valley theme, and equipped with a reusable tooltip helper. Textual
is removed as a runtime dependency.

End-to-end behaviour: running `ctld-tools tui` (or double-clicking the `.exe`) opens a
native Windows GUI window with the correct layout, the sv-ttk dark/light theme applied,
and the footer visible. No tree data, no form yet — just the skeleton that proves the
stack works.

The tooltip helper (`<Enter>`/`<Leave>` binding that shows a `tk.Toplevel` label near
the cursor) is implemented and unit-tested in isolation; it will be wired to real content
in later slices.

## Acceptance criteria

- [ ] `sv-ttk` declared as a runtime dependency in `pyproject.toml` and pinned.
- [ ] `textual` removed from runtime dependencies (may stay as optional/dev if test
  fixtures need it during transition, but must not be required to run `ctld-tools tui`).
- [ ] `ctld-tools tui` (and double-click via `__main__.py`) opens a tkinter window with
  sv-ttk Sun Valley theme applied; window has a two-panel `PanedWindow` (tree left,
  form right) and a fixed-height footer frame.
- [ ] `--lang en` / `--lang fr` flags propagate to the new app's i18n layer.
- [ ] Tooltip helper implemented: given any `tk.Widget` and a text string, binds
  `<Enter>`/`<Leave>` to show/hide a near-cursor label; dismisses on `<Leave>`.
- [ ] PyInstaller spec updated to include `sv-ttk` data files (theme assets); `.exe`
  builds without error.
- [ ] `test_app.py` rewritten: asserts the window is created, the two-panel layout
  exists, and the footer frame is present (headless / no display required via
  `Tk.withdraw()` or similar).
- [ ] `test_widgets.py` rewritten: asserts tooltip helper shows/hides correctly.

## Blocked by

None — can start immediately.
