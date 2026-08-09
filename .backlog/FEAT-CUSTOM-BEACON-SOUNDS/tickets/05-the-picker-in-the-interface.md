# 05 — Default or custom, in the interface

**Status:** done
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

- [x] Neither setting name appears in any component: the picker is bound to `meta.editor === 'sound'`.
- [x] Reopening a mission with a custom sound shows *Custom*, the original file name, the size and
      the reserved name; an unavailable file gets its own warning line.
- [x] `SoundPicker.test.ts` covers Default → Custom → Default, cancellation, and a refusal from the
      backend (7 tests). The hidden labels are excluded from the families and from search.
- [x] EN and FR strings in step — `i18n.parity.test.ts` passes.
