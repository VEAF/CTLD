# 01 — Translate the four native-crate player messages

**Status:** ⬜ ready · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CRATE-MESSAGES-I18N](../PRD.md). Stories 1-12.

## What to build

Route the four native-crate player messages (loaded parachute-ready, loaded DCS native, falling DCS native
parachute, unloaded DCS native) through `ctld.tr` with the crate label as `%1`, add their keys to the four
dictionaries and translate FR, ES and KO.

Tests first, in the existing native-cargo functional spec: with the language set to French, a native load, a
conversion, a ground release and an in-flight release each show the exact French text with the crate label; an
English control keeps the English text. Watch them fail, then fix.

Finish the lot: rebuild `CTLD.lua` (the build adds the keys), fill the translations, remove the roadmap entry,
add the CHANGELOG entry, set the index line to `merged (PR #NN)` and the statuses to done, open the PR.

## Acceptance criteria

- [ ] The French cases fail before the change and pass after it (test committed first); English unchanged.
- [ ] Four keys present and translated in EN, FR, ES and KO; CI dictionary guard green.
- [ ] Roadmap entry removed, CHANGELOG entry added, index line `merged (PR #NN)`.
- [ ] luacheck clean; `busted` green.

## Blocked by

None - can start immediately.
