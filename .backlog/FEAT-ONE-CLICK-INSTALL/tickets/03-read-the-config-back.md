# 03 — open a `.miz` and edit the configuration it carries

**Status:** todo

Depends on: 02 (it reads what 02 writes).

## Why

A Mission Maker who configured a mission last month has the configuration **in the mission** and
nowhere else. Today the tool cannot read it back: they start from the defaults again and redo their
work, or they keep a `.yaml` beside the `.miz` and remember which is which.

## What changes

- The tool opens a `.miz` the way it opens a `.yaml`: same "Open a config file…" path, extended to
  accept an archive.
- Reading is: open the zip → read `l10n/DEFAULT/CTLD_userConfig.lua` → extract the YAML from its Lua
  long-bracket string → load it as the session catalogue. The extraction is the mirror of the
  wrapping `ctld-tools` already does when generating that file, so **reuse that code, inverted** —
  the long-bracket level is dynamic (`[==[…]==]`), so a hand-rolled regex will get it wrong.
- The tool then knows which `.miz` the config came from, so "Inject into mission…" can default to it.
- A `.miz` with no CTLD configuration is not an error: say so plainly and offer to start from the
  defaults, which is exactly what a first-time install is.

## Watch out

- **An older mission carries the config inline**, in a trigger, not as a file — that is how the tool
  injected until ticket 02. Decide whether to read that shape too. Reading it means deserialising
  the `mission` table and unescaping the string; it is the only way a rc1–rc3 mission can be
  reopened. Worth it, and it is a read-only path — but if it is skipped, the message must tell the
  user to re-inject rather than leave them guessing.
- A configuration read back from a mission may be **older than the current catalogue**. The
  version-gap check already exists for exactly this and must fire on this path too, not only on
  file open.

## Acceptance

- Inject into a `.miz`, close the tool, reopen the `.miz`: the same configuration comes back, with
  every setting the user changed.
- A stock `.miz` gives a clear "no CTLD configuration in this mission" and the defaults.
- A configuration authored against an older CTLD raises the version-gap popup.
- Round-trip: read a `.miz`, inject it again with no edits, and the resulting configuration is
  identical.

## Tests

- pytest: round-trip — a catalogue injected then read back equals the original, key by key.
- pytest: a `.miz` with no CTLD file returns the documented "nothing here" result, not an exception.
- pytest: the long-bracket extraction survives a YAML containing `]]`, `]==]` and a `--` comment
  sequence — the cases a naive regex breaks on.
