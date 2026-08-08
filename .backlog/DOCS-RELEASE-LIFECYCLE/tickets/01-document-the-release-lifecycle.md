# 01 — Say that the tool carries its own CTLD

**Status:** done
**Lot:** DOCS-RELEASE-LIFECYCLE

## Problem

Nothing user-facing states how a new CTLD gets into a mission. The README's installation section says
the tool "carries CTLD and its beacon sounds" — true, but silent on *which* CTLD and on what makes it
change. The mission-maker guide's *Get the tool* section lists what is embedded and stops there. Its
*When CTLD is updated* section is about the **configuration** version gap, which reads like an answer
to this question and is not one.

## Change

The same three facts, in the README (entry point) and in the guide (where the download is described):

- the exe embeds the `CTLD.lua` built from the commit its release was tagged on — it downloads
  nothing and never updates itself;
- a new engine ships only when a **release is published**; a merge changes nothing for a Mission
  Maker, who moves version by downloading the exe again and re-installing;
- release candidates publish as pre-releases and carry no *Latest* badge — take the topmost entry.

The FR page gets the anchor of its EN counterpart (`{ #the-tool-carries-its-own-ctld }`), as the rest
of the file does.

## Acceptance

- [x] README has the subsection, inside *Installation*.
- [x] `docs/mission-maker/ctld-tools.md` and `.fr.md` say the same thing, EN/FR in step.
- [x] No source change, so no `CHANGELOG.md` entry and no rebuild.
