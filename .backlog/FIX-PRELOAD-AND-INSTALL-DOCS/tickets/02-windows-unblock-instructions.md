# 02 — Say what to do when Windows blocks the exe

**Status:** done
**Lot:** FIX-PRELOAD-AND-INSTALL-DOCS

## Problem

`ctld-tools.exe` is not code-signed, so Windows SmartScreen stops it on a first run with "Windows
protected your PC" and no obvious way forward — the **Run anyway** button is hidden behind **More
info**. A Mission Maker meeting that screen reasonably concludes the download is unsafe, and the
whole one-click install journey ends there. Nothing in the project said a word about it.

Requested by Zip, who pointed at the Walker project as the model. The text was not there to reuse —
neither the repository, its `docs-site/self-hosting/standalone-exe.md`, nor any of its 20 release
pages mention it — so this is written fresh.

## Change

Three placements, shortest first:

- **`release` skill** — three lines inside the installation section template, so every future release
  page carries them where a newcomer arriving from a forum link will read them.
- **README** — the fuller version, next to the download step.
- **Mission-maker guide** (EN + FR) — same, plus a pointer from step 1 of the getting-started list.

All three cover the same three cases: SmartScreen (**More info** → **Run anyway**), the downloaded-file
tag (**Properties** → **Unblock**), and an antivirus quarantining it (a known PyInstaller false
positive). Each says *why* — an unsigned binary from an unknown publisher — rather than only what to
click, and points at the public build workflow for anyone who wants to check the provenance first.
