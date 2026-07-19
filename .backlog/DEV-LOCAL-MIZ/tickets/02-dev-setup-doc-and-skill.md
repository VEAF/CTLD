# 02 — Dev-setup checklist + realign the dcs-runtime-debug skill

Status: ⬜ ready
Type: AFK (doc)
Repo: CTLD
GitHub: —

## What to build

Document the `CTLD_DEV_ROOT` setup as a developer checklist, and fix the now-false claim in the
`dcs-runtime-debug` skill.

1. **`docs/developer/building-and-testing.md` + `.fr.md`** — add a "dev environment setup" checklist,
   three ordered prerequisites:
   1. **De-sanitized DCS** (`MissionScripting.lua` — `os`/`io`/`lfs` re-enabled). Without it,
      `os.getenv` is absent and the martyr trigger fails with its on-screen `[CTLD dev]` message.
   2. **`setx CTLD_DEV_ROOT "<repo root>"`**, then **restart DCS** — emphasise the restart: a running
      DCS does not inherit the new variable (`setx` persists it in `HKCU\Environment`; the pitfall is
      process inheritance timing, not persistence).
   3. The martyr loads `CTLD.lua` via that variable; **no developer edits the `.miz`**.
   - Mirror the final trigger snippet here as the copyable reference (per the inline-snippet decision).

2. **`.claude/skills/dcs-runtime-debug/SKILL.md`** — the "CTLD log" section states *"Requires a
   `ctldLogPath` set in the test `.miz` (MISSION START trigger)"*, which DEV-LOCAL-MIZ makes false
   (line deleted). Re-align it: enabling `CTLD.log` is done **on demand** by injecting
   `tests/dcs/dev/diag/diag_enable_ctld_log.lua` (sets `ctldLogPath` to `ctld.path.."live_tests/"`, no
   machine value), not by a miz trigger. Keep the `dcs.log` section (the primary, still-valid path).

No `src/` change, no rebuild, no tests. Documentation only.

## Acceptance criteria

- [ ] `building-and-testing` (EN+FR) has a dev-setup checklist: de-sanitize → `setx CTLD_DEV_ROOT` +
      restart DCS → martyr loads via the var, no per-dev miz edit.
- [ ] The restart-DCS caveat is called out (inheritance timing, not persistence).
- [ ] The final trigger snippet is mirrored in the doc as the copyable reference.
- [ ] `dcs-runtime-debug` no longer claims `ctldLogPath` comes from the `.miz`; it points to
      `diag_enable_ctld_log.lua` for on-demand activation.
- [ ] Wording is English (EN page) / French (FR page), no FR/EN mixing within a sentence.

## Blocked by

None. Independent of ticket 01 (describes the mechanism; does not require the miz edit to be done first).
