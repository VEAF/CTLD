# 04 — Textual TUI app (the console)

Status: ✅ done
Type: AFK
Repo: CTLD

## What to build

The **textual** app: the MM console over the edit model (ticket 02) and pickers (ticket 03).

- Structured layout showing the config by section (settings / crates / troops / arrays) with the
  current entries.
- Guided forms to add / remove / edit one entry at a time (filterable pickers for unit / crate /
  troop; labelled inputs for scalars).
- **Live validation** surfaced inline (errors + suggestions) as edits happen.
- Actions: save (`user-config.yaml`), generate (`render_user_config` → `CTLD_userConfig.lua`), inject
  (`inject_userconfig` into a picked `.miz`). Generation refused while errors exist.
- The 4 sections covered in V1.

## Acceptance criteria

- [ ] App opens with the embedded reference (no `--src`); optional `--yaml` opens a file.
- [ ] Add/remove/edit for all 4 sections drive the model; inline validation shown.
- [ ] Save / generate / inject work from the UI; generate blocked on errors.
- [ ] Smoke test via `app.run_test()` + Pilot (pytest-asyncio): scripted add-a-crate reaches the
      expected model state / save.

## Blocked by

Tickets 02, 03.
