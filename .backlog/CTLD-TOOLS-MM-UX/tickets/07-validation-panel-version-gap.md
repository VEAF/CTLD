# 07 — Plain-language validation panel + version-gap rewrite

**Status:** done

## Goal

Turn the validation output from a technical dump on one screen into a persistent, readable answer to
"is my config good to ship?" (finding 9).

## Work

**Validation panel**, always mounted (not only on the old Data screen):

- Collapsed to a single status line when clean: an ok lamp + "Configuration is valid — ready to
  inject into a mission."
- When there are findings: grouped by severity, error count first, each finding rendered as the
  human label of the setting it concerns + the message, with the raw key kept small. Clicking a
  finding navigates to the family that owns it and reveals the setting (opening the advanced
  disclosure if needed).
- The header status lamp reflects the same state, so it is visible from anywhere.
- Errors block injection — say so on the panel, next to the count, since the backend rejects with
  422 anyway. The user should learn this from the UI, not from a failed action.

**Version-gap dialog** — currently a wall of key lists ending in a `Review & continue` button that
does nothing actionable. Rewrite as: what happened (this config was authored for an older CTLD),
what it means for the MM, and the three groups as counts that expand on demand. The action becomes
`Continue` (explicitly: nothing was merged, the config is untouched), which is the honest
description of the current behaviour — no silent merge, per ADR 0011 point 5.

## Done when

- The panel is present on every family.
- A component test asserts a finding renders with its human label and that clicking it selects the
  owning family.
- The clean state renders the ok line and no list.
