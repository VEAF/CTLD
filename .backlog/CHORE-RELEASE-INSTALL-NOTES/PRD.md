# CHORE-RELEASE-INSTALL-NOTES — every release says how to install CTLD

**Status:** open.

Opened 2026-08-01. **Deliberately last** of the three install lots: it documents the journey
`FEAT-ONE-CLICK-INSTALL` builds, and a notice written before the journey exists is a notice that is
wrong on publication day.

## Why

A release page today lists four assets and says nothing about what to do with them. A Mission Maker
arriving from a forum link has to guess which file matters, and the answer is about to change: with
`FEAT-ONE-CLICK-INSTALL`, **`ctld-tools.exe` is the only file they need**, and the other assets exist
for the manual path.

Nothing in the release process says so. `RELEASE_NOTES.md` opens on what the release *contains*,
never on how to install it, and the `release` skill's steps (draft notes → bump → PR → tag) have no
place where installation is stated.

## What changes

`.claude/skills/release/SKILL.md` gains the requirement that every `RELEASE_NOTES.md` opens with a
short **installation** section, before the feature list:

1. download `ctld-tools.exe` from this release;
2. run it — it opens in the browser, locally;
3. open your `.miz`, configure, install.

Plus one line for the manual path, pointing at the documentation rather than repeating it.

The section is short and stable, so the skill can carry the wording as a template to adapt rather
than a question to ask each time. What it must not become is a second copy of the getting-started
page: link, do not duplicate.

## Definition of done

- The skill requires the section, and says where it goes (first, before "Nouveautés").
- The wording is in the skill, so a release cannot ship without it by forgetting to think about it.
- It names the exe as the single file a Mission Maker needs, and does not enumerate the others.
- The next release's notes carry it.

## Out of scope

- Rewriting past release pages.
- The release notes' language. They are French today, matching the VEAF community; this lot follows
  suit and does not reopen the question.
