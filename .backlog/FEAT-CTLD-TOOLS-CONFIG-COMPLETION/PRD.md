# FEAT-CTLD-TOOLS-CONFIG-COMPLETION — ctld-tools completes a mission's configuration with the keys it lacks

**Status:** ✅ done

Follows the discovery, while delivering `FEAT-NATIVE-CRATE-SPAWN-NEAR` (PR #221), that re-saving a mission's
configuration with ctld-tools does not add the keys the catalogue gained since it was written, and a
`grill-with-docs` session held 2026-10-01. See **ADR 0011** (complete-YAML model, Addendum 1 on the two config
tiers) which this lot extends with an Addendum 2, and the **Config completion** and **Config version tag**
glossary terms in `CONTEXT.md`.

## Problem Statement

A Mission Maker who opens a mission that already carries a CTLD configuration, then saves it back, expects the
tool to bring it up to date. It does not. The tool opens the configuration exactly as stored and writes it back
unchanged, so every setting and every field the catalogue added since the mission was exported stays absent:

- A setting that the engine needs (a scalar parameter such as `crateSpawnGap` or `enableParachuteDrop`) is absent,
  so at mission start the engine falls back to its default and shows a notice on screen. The Mission Maker did
  everything the documentation suggested and still sees the notice, with no way to tell why.
- A field added inside a list entry (the aircraft capabilities `crateSpawnSector` and `crateSpawnDistance`, the
  crate model `size`) is absent for good, so the feature that depends on it silently does not apply to that
  mission. The only remedy today is to type each field by hand.
- Nothing tells the Mission Maker, the tool or the engine that the configuration is out of date: the catalogue
  version tag is `2.0.0` on both sides, so the version-gap detection that exists for this very purpose reports an
  empty gap. A stale `ctld-tools.exe` that predates a setting goes undetected the same way, and the cause of a
  missing key had to be found by comparing file dates.

## Solution

When ctld-tools opens an existing configuration (a mission, or a YAML file) it brings it up to date on its own and
says so:

- Every scalar parameter the configuration lacks is added with its catalogue default. A parameter is never a
  deliberate removal (ADR 0011 Addendum 1), so this is always safe.
- A field a list entry lacks is added with its catalogue default when the configuration was authored against an
  older catalogue version, and only for entries whose key the catalogue knows: an aircraft type or a crate the
  Mission Maker added is left alone. When the version is current, a missing field is the Mission Maker's own
  removal and is respected.
- A value the Mission Maker already entered is never changed. Where the catalogue's own default changed since, the
  new default is shown for information and not applied.
- A non-blocking summary lists what was added (per aircraft type for the list fields), so nothing happens
  silently and the Mission Maker can undo an addition.
- The catalogue version moves to `2.1.0`, is independent of the CTLD release number, and is written back at every
  save, so a later removal is respected.
- The version is visible where the Mission Maker looks: the tool's header (the opened configuration against the
  tool's catalogue), the engine's start-up notice, and the output of `validate`.
- A CI guard fails when the catalogue gains a key or a field without a version increment, so the mechanism cannot
  silently stop working again.
- The documentation describes the real behaviour, and the warning added by PR #221 that tells Mission Makers to type
  the crate spawn fields by hand is replaced.

## User Stories

1. As a Mission Maker, I want the tool to add the settings my mission's configuration lacks when I open it, so that
   a configuration exported with an older CTLD works with the current one without my editing each new setting.
2. As a Mission Maker, I want the missing scalar parameters added with their catalogue defaults, so that the
   engine stops showing the "settings absent from the mission config" notice for my mission.
3. As a Mission Maker, I want the new fields of an aircraft type (crate spawn sector and distance) added to the
   types I already have, so that crates spawn next to my helicopters without my typing each field.
4. As a Mission Maker, I want the crate model `size` added to the default models, so that crates in a row are
   spaced correctly.
5. As a Mission Maker, I want an aircraft type or a crate I added myself to be left untouched, so that the tool
   never invents values for something the catalogue does not describe.
6. As a Mission Maker, I want every value I already entered kept as it is, so that opening a mission never
   changes a decision I made.
7. As a Mission Maker, I want to see the catalogue's new default when it differs from mine, without it being
   applied, so that I can choose to adopt it.
8. As a Mission Maker, I want a summary of what was added when I open a configuration, so that nothing changes
   silently.
9. As a Mission Maker, I want the summary to name the aircraft type for each field added to a list entry, so that
   I can check the values that matter to my mission.
10. As a Mission Maker, I want to undo an addition I do not want, so that the completion never forces a setting.
11. As a Mission Maker, I want a field I removed on purpose to stay removed once I saved the configuration with the
    current tool, so that my removal is not undone at the next opening.
12. As a Mission Maker, I want the configuration saved with the current catalogue version, so that the next
    opening knows what it is up to date with.
13. As a Mission Maker, I want to see in the tool's header which version my opened configuration was written
    against and which version the tool carries, so that I can tell at a glance when they differ.
14. As a Mission Maker, I want the engine's start-up notice to give the configuration's version and the CTLD
    catalogue version, so that a screenshot of the notice is enough to understand why settings are absent.
15. As a Mission Maker, I want `validate` to print both versions when they differ, so that a check from the command
    line points at the cause.
16. As a Mission Maker, I want a YAML file opened from disk completed the same way as a mission, so that the
    behaviour does not depend on how I open the configuration.
17. As a Mission Maker working by hand, I want the engine to keep defaulting a missing parameter and showing the
    notice, so that a configuration that never meets the tool still works and still warns.
18. As a Mission Maker, I want a mission that has never had a CTLD configuration to behave as before, so that
    this change does not alter the first-time flow.
19. As a Mission Maker, I want the tool to refuse to inject a configuration that is still incomplete, as it
    already does, so that a half-updated configuration never reaches the mission.
20. As a CTLD maintainer, I want a CI test that fails when the catalogue changes without a version increment, so
    that the completion mechanism cannot be skipped by an oversight.
21. As a CTLD maintainer, I want the rule "adding a key or a field to the catalogue increments the version"
    written in the contributor instructions and the developer page, so that a contributor learns it before CI
    tells them.
22. As a CTLD maintainer, I want the catalogue version independent of the CTLD release number, so that a mission
    stays current across several CTLD releases while the catalogue does not move.
23. As a CTLD maintainer, I want the completion to reuse the existing version-gap detection, so that there is one
    definition of what changed between two catalogue versions.
24. As a CTLD maintainer, I want the completion logic in the tool's core, not in the web layer, so that the
    command line and the web app share it and it can be tested without a browser.
25. As a documentation reader (Mission Maker or developer), I want the pages to describe what the tool actually
    does on opening a configuration, so that I am not told to do by hand what the tool now does.
26. As a Mission Maker who read the PR #221 warning, I want it replaced by the real behaviour, so that I know a
    re-saved mission now gets the crate spawn fields.
27. As a CTLD maintainer, I want the new engine notice text translated through the usual dictionaries, so that
    the build keeps the i18n guard green.

## Implementation Decisions

- **Config completion** is a new tool-core operation applied when a configuration is opened (mission or YAML
  file), producing the completed catalogue plus a report of what it added. It lives in the core, next to the
  version-gap detection, and the web layer and the command line only call it.
- **Two tiers, derived from the shape of the default value** (ADR 0011 Addendum 1, unchanged): a scalar is a
  parameter and is always completed; a list or a map is data and is completed only as described next.
- **List entries** (aircraft capabilities, crate models, and the like) gain the fields the catalogue's entry of
  the same key has and the stored entry lacks, only when the configuration's version is older than the
  catalogue's. An entry whose key the catalogue does not know is never touched. Missing list entries and missing
  lists stay intentional removals, as ADR 0011 point 1 says.
- **Never overwrite.** A present value is kept whatever the catalogue default is. A default that changed is
  reported as information (the existing "changed" part of the version gap), not applied.
- **The version-gap detection is extended** to compare the fields of list entries, not only the flat top-level
  keys, since the fields that motivated this lot live inside entries. Equal versions still yield an empty gap.
- **Catalogue version `2.1.0`**, independent of the CTLD release number, stamped on the default catalogue and its
  schema, and written into the configuration at every save and injection.
- **Visibility.** The web app's header shows the opened configuration's version and the tool's catalogue version;
  the opening summary repeats both and lists additions, grouped by aircraft type for list fields, with a way to
  undo an addition. The engine's start-up notice for absent parameters adds the configuration's version and the
  CTLD catalogue version (a new translated text; the build regenerates the dictionaries). `validate` prints both
  versions when they differ.
- **Validation unchanged in strength.** A missing scalar remains an error and injection of an incomplete
  configuration remains refused; completion makes that state unreachable through the tool but a hand-written
  configuration still meets it.
- **Engine behaviour unchanged** apart from the notice text: a missing parameter still resolves to the default,
  and no list is ever merged at runtime.
- **CI guard.** A reference snapshot of the catalogue's keys and list-entry fields is kept per version. A test
  compares it with the current catalogue and fails, with an explanatory message, when they differ and the version
  was not incremented. The rule is written in the contributor instructions and in the developer page.
- **ADR 0011 gets an Addendum 2**: completion on opening is automatic but always shown, which refines point 5's
  "surface the diffs to review before re-injecting" for additions, and keeps the runtime a straight `or`. The
  glossary gets a **Config completion** term and an updated **Config version tag**.
- **Documentation**, English and French: the Mission Maker pages for ctld-tools and for the crate catalogue (the
  PR #221 warning is replaced by the real behaviour), the developer pages (completion, version rule, guard), and
  the changelog.

## Testing Decisions

- A good test drives the behaviour a Mission Maker or the engine can observe: a configuration goes in, a
  completed configuration and a report come out; nothing is asserted about how the diff is computed.
- **Highest seam, tool core:** open a stored configuration (YAML text and a mission archive) and check the
  completed catalogue and the report. Cases: a missing scalar is added; a missing list field is added when the
  version is older and not when it is current; an entry the catalogue does not know is untouched; a present value
  is kept even when its default changed; the version is stamped on save; an unchanged-version configuration is not
  altered. Prior art: the existing version-gap, catalogue and install tests of the tool.
- **Web API seam:** opening a mission through the API returns the completion report and both versions; saving
  returns the stamped version. Prior art: the existing API tests of the web app.
- **Frontend:** the header and the summary render both versions and the additions; undo removes an addition.
  Prior art: the existing component tests (vitest).
- **Engine seam:** the start-up notice for absent parameters carries both versions. Prior art: the busted tests
  of the start-up report and of the configuration defaults.
- **CI guard:** the test that fails on a catalogue change without a version increment, proven by a
  deliberately failing fixture in its own test.
- **Build:** the i18n guard stays green with the new notice text.

## Out of Scope

- Rebuilding or distributing `ctld-tools.exe`: a completion only helps once an exe containing it is built; the
  release process is unchanged.
- An alert when the tool is older than the engine it targets: in a release the exe embeds both and they always
  agree; the mismatch exists only in development.
- Changing which list entries or lists a configuration contains; a missing entry stays a deliberate removal.
- Changing the runtime to merge defaults into a configuration.
- Back-filling past catalogue versions that were never tagged: configurations written before `2.1.0` all read as
  `2.0.0` and are completed against the current catalogue.
- The crate spawn feature itself (delivered by `FEAT-NATIVE-CRATE-SPAWN-NEAR`).

## Further Notes

- Cause found on 2026-10-01: the mission's embedded configuration lacked `crateSpawnGap`, `enableParachuteDrop`,
  `crateSpawnSector`, `crateSpawnDistance` and the model `size`, and the `ctld-tools.exe` used (dated 2026-09-24)
  predated two of those settings, so its own validation could not flag them. The current tool already reports the
  absent scalars as errors and refuses to inject.
- A mission exported with the new tool after this lot carries `2.1.0`; the first opening of an older mission shows
  the summary once.
- `missions/Test_CTLDNEXT_01.miz` and `tests/dcs/dev/diag/diag_bbox_draw.lua` must not be committed.
