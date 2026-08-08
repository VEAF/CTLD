# FEAT-DEV-BUILD-CHANNEL — an exe to hand out before a release

## Why

FullGas asked how a new CTLD reaches a mission, and the honest answer (documented in
`DOCS-RELEASE-LIFECYCLE`) is: only through a published release, because `ctld-tools.exe` bundles the
engine of its own release. Which leaves nothing to hand a tester between two releases — and FullGas
has never published one.

Zip's first idea was a special mode: the exe copies itself and grafts an arbitrary `CTLD.lua` into
the copy. **It works** — verified, not assumed: `ctld-tools.exe` from `2.0.0-rc6` with 1.17 MB
appended past its archive still runs (`--version` → `2.0.0-rc6`), because the PyInstaller bootloader
locates its cookie regardless of trailing bytes, the same property that lets a signed exe carry its
signature at the end.

It was dropped anyway, for reasons the CI answers better:

- a grafted exe pairs a **new engine with the old schema, catalogue and interface** — a config the
  tool cannot edit, or an engine reading a setting the tool never wrote;
- an unsigned exe altered after the build is the profile of a tampered file, on a download already
  fighting SmartScreen (`FIX-PRELOAD-AND-INSTALL-DOCS`);
- `--version` would keep saying `2.0.0-rc6` while carrying something else — untraceable bug reports.

The `build-exe` job already produces a complete exe from a commit in **2 min 06 s** (measured on the
last release run) and the repository is public, so runner minutes are free. It only lacks a
trigger.

## Decisions (grilled 2026-08-08)

1. **Built on every PR merge into `develop`**, in a job that blocks nothing.
2. **Published twice**: as an action artifact (traceable per run) *and* as a floating `dev`
   pre-release. The second exists because an artifact **cannot be downloaded anonymously** —
   verified: the archive URL answers `401` on a public repository — and comes as a `.zip` to
   unpack, on top of the unblock dance a tester already has to do.
3. **Version = `<ctld version>-<commit hash>`**, stamped by the workflow, never by a local build.
   Checked against the two version-like values that already exist: `ctld.VERSION`
   (`src/CTLD_config.lua:5`) is what `--version` reports, while `configVersion`
   (`src/CTLD_config.yaml:5`) drives version-gap detection — they are separate, so a hash suffix
   raises no false "your configuration is from another version". `docs_version()` already maps any
   version containing a dash to the `dev` documentation, so the help link needs no change.

## Scope

The trigger, the two publication paths, the stamped version, and the developer documentation of the
channel.

## Out of scope

- **Grafting an engine into the exe** (see above), and the advanced setting that would have pointed
  the installer at a `CTLD.lua` on disk. Same reason: a complete exe beats a hybrid.
- **A manual trigger on any branch** (`workflow_dispatch`). Worth adding the day a `feature/*` needs
  testing before merge; three lines, and no reason to speculate now.
- **Code-signing.** It would end the SmartScreen prompt for every download, dev build or release,
  but it costs money and needs an owner.
