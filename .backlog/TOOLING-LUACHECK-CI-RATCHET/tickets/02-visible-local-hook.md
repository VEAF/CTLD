# 02 — Local hook: one-time visible notice instead of a silent no-op

**Status:** ✅ done

**Blocked by:** none — can start immediately, independent of ticket 01.

## What to build

In `tools/hooks/luacheck-on-edit.sh`, when `command -v luacheck` fails (the existing no-op
branch): check for a marker file at `$CLAUDE_PROJECT_DIR/.git/ctld-luacheck-notice-shown`. If
absent, print a one-line notice to stderr (e.g. "luacheck not installed — local check skipped for
this session; CI enforces this on your PR.") and create the marker (empty file is enough — its
mere presence is the signal). If present, stay silent exactly as today.

Update `tools/hooks/README.md`'s `luacheck-on-edit.sh` row: it currently says "Best-effort and
non-blocking — no-op if `luacheck` is absent," which becomes inaccurate once this ships — describe
the new one-time notice behavior instead.

## Watch out

- The marker lives under `.git/` specifically (never git-tracked, local to the clone) — not a repo
  path that would need a `.gitignore` entry.
- Never auto-reset or expire the marker — no daily/session logic, per the grill decision. It
  persists until a human deletes it by hand.
- Still fully non-blocking: the hook must still `exit 0` in every case, notice or not — this ticket
  only changes whether something is printed, never the hook's blocking behavior.
- When `luacheck` **is** installed, behavior is completely unchanged (runs it, reports issues,
  same as today) — this ticket only touches the "not installed" branch.
- Keep the notice to one line, consistent with the hook's existing terse stderr style.

## Acceptance

- First edit of a `src/*.lua` file with `luacheck` absent from `PATH`: the notice appears on
  stderr, and the marker file is created.
- A second such edit in the same clone: no notice (marker already present).
- Deleting the marker and editing again: notice reappears once.
- `luacheck` present: unchanged behavior, no notice ever (this path doesn't touch the marker).
- `tools/hooks/README.md` accurately describes the new behavior.

## Tests

None — no test file exists for any `tools/hooks/*.sh` script in this repo (checked); this ticket
follows the same precedent. Verified manually per the Acceptance criteria above.
