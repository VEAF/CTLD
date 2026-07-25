# 08 — docs rewrite for the web app

Status: ✅ done
Type: docs

Rewrite the Mission-Maker tool docs for the web app and update the glossary.

- `docs/mission-maker/ctld-tools.md` + `.fr.md`: rewritten for the web app — double-click the exe,
  the Parameters/Data screens + families, editing, live validate, `.miz` inject, the version-gap
  popup. Drop the retired TUI/ops instructions.
- `CONTEXT.md`: update the `ctld-tools` glossary entry (web app, not TUI).
- CHANGELOG `[Unreleased]`; ADR 0011 referenced. Confirm no stale references to the TUI/gen-user
  remain in `docs/`.

Files: `docs/mission-maker/ctld-tools.{md,fr.md}`, `CONTEXT.md`, `CHANGELOG.md`. Depends on: 01–07.
