# 01 — the release skill requires an installation section

**Status:** todo

Depends on: `FEAT-ONE-CLICK-INSTALL` (the journey it describes must exist).

## What changes

In `.claude/skills/release/SKILL.md`, step 3 (drafting `RELEASE_NOTES.md`) gains a hard requirement:
the notes **open** with an installation section, before the feature list, with the three-step journey
and a pointer to the documentation for the manual path.

Carry the wording in the skill as a template, in French, matching the notes' language:

```markdown
## Installation

1. Téléchargez **`ctld-tools.exe`** ci-dessous — c'est le seul fichier dont vous avez besoin.
2. Lancez-le : l'outil s'ouvre dans votre navigateur, en local, sans installation.
3. Ouvrez votre `.miz`, réglez ce que vous voulez, puis **« Installer dans la mission »** : l'outil
   y écrit CTLD, les sons des balises et votre configuration.

Vous préférez tout faire à la main ? Les fichiers du script sont aussi attachés à cette release —
voir la [documentation](https://veaf.github.io/CTLD/).
```

Two rules for whoever maintains it:

- **The exe is named as the only file needed.** Do not enumerate the other assets in this section;
  they belong to the manual path, one sentence lower.
- **Link, never duplicate.** The getting-started page is the long form. If this section grows past a
  handful of lines, it is drifting into a second copy that will contradict the first.

## Acceptance

- The skill states the requirement, its position (first section) and the template.
- Following the skill produces notes carrying it, without the operator having to remember.
- The documentation link uses the released version once
  `FEAT-TOOL-VERSION-AND-DOCS` ticket 02 publishes versioned pages; until then the site root, which
  is honest rather than broken.

## Tests

None — it is a skill, not code. The check is the next release: its notes must open with the section.
