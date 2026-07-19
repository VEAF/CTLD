# 02 — Dev-setup checklist + realign the dcs-runtime-debug skill

Status: ✅ done
Type: AFK (doc)
Repo: CTLD
GitHub: —

## What to build

Document the martyr `CTLD_DEV_ROOT` setup in the (already-existing) live-DCS testing page, and fix
the now-false claim in the `dcs-runtime-debug` skill.

> Discovery mid-lot: the live-DCS testing doc **already existed** as `docs/integration-testing.md`
> (root of `docs/`, "Release Testing Procedure", L1–L6) — it already documents how to run the tests.
> It was missing only the martyr build-loading step. It also sat outside `docs/developer/` despite
> being developer content (L3–L6 are "developer, before push"). So this ticket **moves** it into the
> developer section and adds the one missing section, instead of creating a new page.

1. **Move** `docs/integration-testing.md` + `.fr.md` → `docs/developer/integration-testing.md` +
   `.fr.md` (`git mv`). Update `mkdocs.yml` (drop the top-level `Integration Testing` nav entry, add
   it under the Developer section after "Building & testing"), the `developer/index.md` + `.fr.md`
   page tables, and the relative links (the page's own `developer/building-and-testing.md` link
   becomes `building-and-testing.md`; `building-and-testing`'s "later lot" mention becomes a link to
   this page).
2. **Add** a "Loading your build into the test mission (martyr)" section to that page (EN+FR): the
   three ordered prerequisites —
   1. **De-sanitized DCS** (`MissionScripting.lua` — `os`/`io`/`lfs` re-enabled); without it
      `os.getenv` is absent and the martyr trigger fails with its on-screen `[CTLD dev]` message.
   2. **`setx CTLD_DEV_ROOT "<repo root>"`**, then **restart DCS** — emphasise the restart: a running
      DCS does not inherit the new variable (`setx` persists it in `HKCU\Environment`; the pitfall is
      process-inheritance timing, not persistence).
   3. The martyr loads `CTLD.lua` via that variable; **no developer edits the `.miz`**.
   Mirror the final trigger snippet as the copyable reference.
3. **`.claude/skills/dcs-runtime-debug/SKILL.md`** — the "CTLD log" section stated *"Requires a
   `ctldLogPath` set in the test `.miz` (MISSION START trigger)"*, which DEV-LOCAL-MIZ makes false
   (line deleted). Re-align it: enabling `CTLD.log` is done **on demand** by injecting
   `tests/dcs/dev/diag/diag_enable_ctld_log.lua` (sets `ctldLogPath` to `ctld.path.."live_tests/"`, no
   machine value), not by a miz trigger. Keep the `dcs.log` section (the primary, still-valid path).

No `src/` change, no rebuild, no tests. Documentation only.

## Acceptance criteria

- [ ] `docs/developer/integration-testing.md` + `.fr.md` exist (moved from `docs/` root); no dangling
      links; `mkdocs.yml` + `developer/index.md`/`.fr.md` updated; the old top-level nav entry removed.
- [ ] That page has a "Loading your build (martyr)" section: de-sanitize → `setx CTLD_DEV_ROOT` +
      restart DCS → martyr loads via the var, no per-dev miz edit — with the trigger snippet mirrored.
- [ ] The restart-DCS caveat is called out (inheritance timing, not persistence).
- [ ] `dcs-runtime-debug` no longer claims `ctldLogPath` comes from the `.miz`; it points to
      `diag_enable_ctld_log.lua` for on-demand activation.
- [ ] Wording is English (EN page) / French (FR page), no FR/EN mixing within a sentence.

## Blocked by

None. Independent of ticket 01 (describes the mechanism; does not require the miz edit to be done first).
