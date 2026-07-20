# 06 — `ctld-tools.exe` distribution + docs, CHANGELOG, index

Status: 🧑 planned
Type: AFK
Repo: CTLD

## What to build

Ship the MM tool and close the paperwork.

- **Distribution**: `release.yml` gains a PyInstaller step building `ctld-tools.exe` (Windows, the
  release job is already on `windows-latest`) and attaches it to the GitHub Release. The `.exe` is a
  release artefact only — CI/build keep invoking the Python module (ADR 0009).
- **Docs** (`docs/mission-maker/` + `docs/pilot/` as relevant, EN + FR): describe the YAML authoring
  flow — `gen-user --scaffold` → edit → `validate` → `gen-user` → load in ME. Update any page that
  told MMs to hand-edit `CTLD_userConfig.lua`.
- **Package README**: `validate` / `gen-user` / `--scaffold` usage and the `.exe`.
- **`CHANGELOG.md`** `[Unreleased]`: entry for the MM authoring tool (a `src/`-touching PR if the
  `dist/` template handling changes → `changelog-guard`).
- **`.backlog/README.md`**: set the `CTLD-TOOLS-USERCONFIG` index line to `merged (PR #NN)` in this PR.

## Acceptance criteria

- [ ] `release.yml` builds + attaches `ctld-tools.exe`; verified on a test tag or dry-run.
- [ ] MM docs (EN + FR) describe the YAML flow; no stale "hand-edit `CTLD_userConfig.lua`" guidance.
- [ ] Package README complete; `CHANGELOG.md` `[Unreleased]` entry added.
- [ ] Backlog index line updated in-PR.

## Blocked by

Tickets 04, 05.
