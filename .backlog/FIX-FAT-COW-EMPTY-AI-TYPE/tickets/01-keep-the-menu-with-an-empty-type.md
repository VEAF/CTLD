# 01 — The Fat Cow menu stays when `fatCowAIType` is empty

**Status:** ✅ done (PR #318) · **Type:** AFK

## Parent

[PRD — FIX-FAT-COW-EMPTY-AI-TYPE](../PRD.md). Stories 1 to 15. GitHub issue #297.

## What to build

An empty `fatCowAIType` removes only **Request a Fat Cow**, as the guide and the editor already say, and the rest of the Fat Cow menu stays for the pilots a cow serves.

- **The menu.** The guard that returns when the type is empty no longer sits at the top of the AI cow menu. The **Fat Cow** submenu and every command are built as before, and only the **Request a Fat Cow** submenu, with the loadout commands under it, is left out when the type is empty. Land here, Take off, Hold here, Join us, Fat Cow status, FARP status, RTB, Release the Fat Cow and, when a cow can be taken over, Take over a Fat Cow stay, with their labels and order unchanged. A flight with no cow still gets "Your flight has no Fat Cow." from the commands that need one.
- **The texts.** Four places say what an empty value does, and are made complete: the mission maker's guide in English and in French, and the description of the setting in the `ctld-tools` schema in English and in French. They say that **Request a Fat Cow** alone disappears and that the other commands stay, because a cow placed in the mission (`fatCowAICows`) needs no type and **FARP status** needs no AI cow; the exact words are those of the PRD. The pilot guide (English and French) is read, and adjusted only if it claims something this contradicts.
- **No configuration change.** No new key, no `configVersion` change, no catalogue shape (a schema description is not part of it), and no dictionary change (the menu labels are untouched). The build is run before the pull request to confirm there is no drift.
- **The CHANGELOG** records it under *Fixed*.

## Acceptance criteria

- [x] With an empty `fatCowAIType`, a helicopter flight with no cow sees the Fat Cow submenu with FARP status, Land here, Take off, Hold here, Join us, Fat Cow status, RTB and Release the Fat Cow, and neither **Request a Fat Cow** nor its loadout commands.
- [x] With the default type the menu is unchanged, **Request a Fat Cow** included.
- [x] With an empty type, **Take over a Fat Cow** still appears when a cow can be taken over.
- [x] With an empty type and a cow placed by the mission, the pilot's **Land here** reaches the cow, which lands.
- [x] With an empty type and no cow, **Fat Cow status** and **Land here** answer "Your flight has no Fat Cow.".
- [x] The new cases fail before the change, for the right reason (the whole menu is absent), and pass after it; the other Fat Cow specs pass unchanged.
- [x] The mission maker's guide (English and French) and the description of the setting in the schema (English and French) say that only **Request a Fat Cow** disappears and why the other commands stay; the pilot guide is consistent with them.
- [x] No catalogue shape or dictionary changes after the build; the `CHANGELOG` entry is there.
- [x] `busted tests/ci/` green; luacheck clean.

## Blocked by

None - can start immediately.
