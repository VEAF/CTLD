# 03 — Document the `@tier` taxonomy

Status: ✅ done
Type: AFK

## What to build

Add a short section to the `integration-testing` skill (`.claude/skills/integration-testing/SKILL.md`)
documenting the `@tier` taxonomy frozen in this lot's PRD: the three values, the operative test
for each (single-call vs. polling vs. requires AI/human), and where new scenarios should default
(new `noPlayer/` scenarios default `auto` unless they genuinely need polling or human
confirmation; anything under `pilotActive/`/`pilotPassive/` is `ia`).

Update the template guidance (ticket 03 of `DCS-BRIDGE-MCP` already documents which of the four
templates to use per scenario shape) to also mention the tier each template defaults to.

## Acceptance criteria

- [ ] `integration-testing` skill documents the 3 tiers with the operative distinction (not just
      the abstract definition).
- [ ] Template table cross-references the default tier per template.
- [ ] No contradiction with `CLAUDE.md`'s existing one-line mention of `@tier`.

## Blocked by

Ticket 02 (tags must exist before documenting the applied convention).
