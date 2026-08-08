# 02 — The session holds the sound, not a path

**Status:** todo
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Problem

A path rots: the file moves, the drive is unplugged, the configuration is reopened on another
machine. And a mission reopened from a `.miz` has no path to offer at all — the sound is inside the
archive. Storing a path would force a temporary file just to have one, and would break the round
trip the whole lot exists for.

## Change

`Session` gains one notion — **the current bytes of each sound** — filled from either source:

- **choosing a file** (native dialog, as `dialogs.py` already does for configs and missions) reads
  it immediately, keeps the bytes and records the original name into the label setting;
- **opening a `.miz`** whose configuration names a reserved sound extracts those bytes from the
  archive in the same move as `install.read_config`.

Lifecycle, mirroring the open configuration: *Start from CTLD defaults* and opening a `.yaml` drop
the bytes; `reset()` drops them. *Save as…* writes the YAML alone — the sound does not travel with
it, which ticket 04 turns into a blocking error rather than a surprise.

## Acceptance

- [ ] Choosing a file then installing writes those bytes, with the source file deleted in between.
- [ ] Opening a `.miz` with custom sounds, then installing into a **different** mission, reproduces
      them — no access to the original file.
- [ ] Loading the defaults after a custom choice leaves no bytes behind.
