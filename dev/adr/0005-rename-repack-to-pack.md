# 5. Rename "repack" to "pack"

Status: Accepted (retroactive — documents a v2.0.0 decision)
Date: 2026-07-07

## Context

Legacy CTLD used "repack" for the action of packing a whole vehicle back into a transportable
crate (config `enablePackingVehicles`, menus, i18n like FR "Ré-emballer véhicules"). The "re-"
prefix was misleading — the action is packing, not re-packing — and inconsistent across symbols.

## Decision

Standardize on **"pack"** everywhere: methods, config, menus, i18n. The term "repack" is banned in
`src/`. The historical symbol/label mapping is recorded in
`migration/history/repack_to_pack_mapping.md`. i18n values were updated (e.g. FR
"Ré-emballer véhicules" → "Emballer véhicules") with a translation-version bump enforced by the
i18n audit.

## Consequences

- Consistent, clearer vocabulary in code, menus, and docs.
- A one-time i18n version bump across all languages was required (audit enforces version parity).
- Reviewers must grep for any `repack`/`re-emballer` regression before committing.
