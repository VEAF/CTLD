Status: open

# PRD — FIX-I18N-DICT-SYNC

> Fix the `$repoRoot` path bug in `generate_i18n_dicts.ps1` that silently prevented all
> dictionary synchronisation, then fill in the FR translations for the 60+ keys added since
> the script last ran correctly.
> Cadré via grill-with-docs (2026-07-22).

## Problem Statement

`tools/build/generate_i18n_dicts.ps1` is meant to be called during the build to keep the four
i18n dictionary files (`CTLD_i18n_en/fr/es/ko.lua`) in sync with the `ctld.tr()` keys found in
`src/`. It has never run correctly because of a one-line path bug:

```powershell
# Line 36 — WRONG
$repoRoot  = Split-Path -Parent $scriptDir
```

`$scriptDir` resolves to `…/tools/build`. One `Split-Path -Parent` gives `…/tools` — not the
repository root. The script then looks for `src/` inside `tools/src/` (does not exist), finds zero
keys, and exits with "0 keys, OK" — writing nothing.

Compare with `merge_CTLD.ps1` line 9, which uses the correct two-level ascent:

```powershell
$repoRoot  = Resolve-Path (Join-Path $scriptDir "..\..")
```

Consequence: every `ctld.tr()` key added since the dictionaries were last hand-edited has no entry
in FR/ES/KO. The French menu is entirely in English (60+ missing keys including all primary menu
labels: "Troop Commands", "Request Equipment", etc.), even though `i18n_lang: fr` is set correctly
in the user config and `ctld.tr()` itself works correctly (fixed in PR #55).

## Solution

1. Fix the one-line `$repoRoot` calculation in `generate_i18n_dicts.ps1` to match the
   `merge_CTLD.ps1` pattern.
2. Run `generate_i18n_dicts.ps1 -Apply` once to append all missing keys to the four dicts.
3. Fill in the FR translations for those missing keys (the EN keys already use human-readable
   English so the EN dict needs no translation work — the script fills it automatically from the
   key itself).
4. ES and KO receive empty stubs (same policy as existing keys in those files — human translators
   own those dicts).

## Implementation Decisions

- **Path fix**: `$repoRoot = Split-Path -Parent $scriptDir` →
  `$repoRoot = Resolve-Path (Join-Path $scriptDir "..\..")` (one line, no other changes to the
  script logic or dry-run/apply modes).

- **Scope**: FR translations only for missing keys. ES and KO remain empty stubs (policy
  unchanged). No new tooling, no merge_CTLD.ps1 integration (grill decision: the call to
  `generate_i18n_dicts.ps1` during build is already present in `merge_CTLD.ps1` — verifying that
  vs adding it is out of scope; the fix only targets the repoRoot bug).

- **No CONTEXT.md changes**: the bug and its fix are pure tooling, no domain model changes.

- **No ADR needed**: path fix — not an architectural trade-off.

## Testing Decisions

- Dry-run after the fix must report ≥ 1 missing key (verifying the path now resolves correctly).
- After `-Apply`, no missing keys must be reported in a second dry-run.
- Existing busted suite (`busted tests/ci/unit`) must still pass (no regression in Lua).
- No new busted spec needed — the script is PowerShell tooling, not Lua.
- No DCS integration scenario needed — this is a build-tool fix, not in-game behavior.

## Out of Scope

- Integrating `generate_i18n_dicts.ps1` into `merge_CTLD.ps1` auto-run (separate concern).
- ES / KO translations.
- Any new `ctld.tr()` keys beyond syncing what already exists.
- `merge_CTLD.ps1` changes.
