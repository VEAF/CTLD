# 04 — AIZ_ orphan removal + confirmation recap + automatic re-scan

**Status:** ⬜ ready

**Blocked by:** ticket 03 (needs the parser + reconciliation base to extend).

## What to build

Extend the reconciliation from ticket 03 with the removal half: after a re-scan, an existing
`aiZones` entry is proposed for removal only if BOTH its `dcsZoneName` matches the `AIZ_` pattern
AND that exact zone no longer exists in the freshly scanned `.miz`. Show a confirmation recap
("N zones will be removed because they no longer exist", listing them) before applying any
removal — never silent, since this can discard a Mission Maker's own already-filled-in stock
configuration if the wrong `.miz` was scanned by mistake. After a confirmed re-scan, the
`aiZones` list in `ctld-tools` must exactly match the set of `AIZ_`-pattern zones present in the
`.miz` (no stale entries left behind).

Also add automatic detection: compare the tracked mission's file mtime against the last-scanned
value whenever the AI-zones editor tab becomes active, and trigger the same re-scan (additions +
removal recap) automatically when it changed — in addition to the existing manual button from
ticket 03. No persistent file watcher; a point-in-time mtime check on tab activation is enough
for this local single-user desktop app.

## Watch out

- Never remove or flag an entry whose `dcsZoneName` does not match the `AIZ_` pattern, regardless
  of whether its zone still exists in the `.miz` — that stays the responsibility of the existing
  `ctld-tools validate` command, untouched by this lot.
- Never remove an entry silently — the confirmation recap is mandatory even when the automatic
  mtime-triggered path is what detected the change.
- The automatic check only decides *whether* to re-scan (has the file changed since last scan) —
  it must not change what a re-scan does once triggered; additions/removals follow the same rules
  whether triggered manually or automatically.

## Acceptance

- An `aiZones` entry with an `AIZ_`-pattern `dcsZoneName` whose zone was deleted from the `.miz`
  is proposed for removal, with a recap shown before it's applied; declining the recap leaves the
  entry untouched.
- An entry with a non-matching `dcsZoneName` is never proposed for removal, even if its zone is
  gone from the `.miz`.
- After a confirmed re-scan, the `AIZ_`-pattern entries in `ctld-tools` exactly match the `.miz`'s
  current `AIZ_`-pattern zones.
- Activating the AI-zones editor tab after the tracked mission's file mtime changed triggers the
  same re-scan flow automatically; activating it with no mtime change does nothing.

## Tests

`web/src/lib/AiZonesEditor.test.ts` (vitest + testing-library/svelte): removal-candidate
detection (matching-pattern + gone-from-miz vs. either condition false), recap-then-confirm flow,
post-re-scan exact-match invariant, and mtime-triggered auto-re-scan on tab activation — same
style as the file's existing tests.
