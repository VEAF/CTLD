# 05 — Default or custom, in the interface

**Status:** todo
**Lot:** FEAT-CUSTOM-BEACON-SOUNDS

## Problem

Both sounds render as text boxes, which invites typing a name that puts no file anywhere.

## Change

A component bound to `editor: sound` (ticket 01), never to a setting name — `FEAT-EDITOR-COVERAGE`
banned literals in components:

- two choices, **Default** and **Custom**;
- *Default* restores the bundled name and drops any custom bytes;
- *Custom* opens the native file browser (`.ogg` filter), and once a file is chosen shows **its
  original name** — read from the label setting, so it survives reopening a mission — with the
  reserved name it will carry in the mission stated plainly, and its size;
- the reset arrow and the *changed* marker behave as for any other setting.

Both sounds are independent: one may be custom and the other default.

## Acceptance

- [ ] Neither `radioSound` nor `radioSoundFC3` appears as a literal in any component.
- [ ] Reopening a mission with a custom sound shows *Custom* and the original file name.
- [ ] A component test covers the round trip Default → Custom → Default.
- [ ] EN and FR strings, in step (the interface's own parity test).
