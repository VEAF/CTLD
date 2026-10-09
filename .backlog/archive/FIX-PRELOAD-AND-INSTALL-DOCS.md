# FIX-PRELOAD-AND-INSTALL-DOCS

**Status:** merged (PR #99). Compacted from `FIX-PRELOAD-AND-INSTALL-DOCS/` on 2026-10-09; the ticket files live on in git history.

Follow-up to `FIX-INSTALL-SOUND-ORPHANS`, opened for three documentation asks — and the reading behind them found a defect in the lot merged an hour earlier. **The sound preload was audible**: #96 shipped `a_out_sound`, which plays to everyone, so every player connected at mission start heard a beacon tone. Zip's instruction had been "pour une coalition sans unité" and I had searched the *coalition* predicates, found `coalitionlist` only ever takes `blue` or `red` across 491 missions, concluded it "cannot be expressed generically" and wrote that into the code — wrong axis, and the counter-evidence was in this repo all along: the README's manual-install section says *"pick an unused country like Australia so no player hears them at mission start"*. `a_out_sound_c`, 1274 occurrences in those same missions. The country is now resolved **per mission** among those it does not declare (Peru, the VEAF set's de-facto choice at 363 uses; then Australia; then any free id, from the datamine country table) — hard-coding one is a bet whose downside is the original bug. Plus **Windows unblock instructions** (unsigned exe → SmartScreen hides *Run anyway* behind *More info*) in the README, the mission-maker guide EN+FR and the release skill; and **the README resynced** — it documented `ctld.yamlConfigDatas`, absent from the whole repository, and `_cfg.settings`, the model ADR 0011 replaced, with an installation section predating `ctld-tools`.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-preload-plays-to-an-unused-country` | done | 01 — The sound preload plays to a country the mission does not use |
| `02-windows-unblock-instructions` | done | 02 — Say what to do when Windows blocks the exe |
| `03-readme-back-in-sync` | done | 03 — A README that matches the product |

## PRD

## FIX-PRELOAD-AND-INSTALL-DOCS — a silent preload, and a README that tells the truth

### Why

Follow-up to `FIX-INSTALL-SOUND-ORPHANS`, opened after Zip asked for three documentation additions —
and the reading that produced them turned up a defect in the lot just merged.

1. **The sound preload is audible.** `FIX-INSTALL-SOUND-ORPHANS` shipped `a_out_sound`, which plays
   to *everyone*. Zip had asked for "un trigger qui joue le son au démarrage pour une coalition sans
   unité"; I looked for it among the **coalition** predicates, found `coalitionlist` only ever takes
   `blue` or `red`, and concluded it could not be expressed generically. Wrong axis: the idiom goes
   through the **country**, `a_out_sound_c(<country>, …)`, and this repo's own README has documented
   it all along — *"pick an unused country like Australia so no player hears them at mission start"*.
   1274 such actions across 491 real VEAF missions. Nothing had to be invented, only read.

2. **Windows blocks the exe and nothing says so.** `ctld-tools.exe` is unsigned, so SmartScreen stops
   it on a first run. For a Mission Maker who has never seen that screen, "Windows protected your PC"
   reads as "this download is dangerous", and the release ends there.

3. **The README describes a product that no longer exists.** It documents `ctld.yamlConfigDatas`
   (**absent from the entire repository**) and `_cfg.settings[...]` (23 occurrences, zero in the
   published docs), i.e. the configuration model ADR 0011 replaced with a complete YAML snapshot. Its
   installation section still walks through downloading `CTLD.lua` and wiring triggers by hand. It
   also duplicated whole reference sections — and a duplicate that drifts is worse than a link.

### Scope

- The preload trigger addresses a country the **mission does not declare**, chosen per mission rather
  than fixed: hard-coding one would be a bet, and losing it means every player hears a beacon tone at
  mission start.
- The unblock instructions in three places: the README, the mission-maker guide (EN + FR), and the
  `release` skill so every future release page carries them.
- The README rewritten as an entry point: what CTLD is, how to install it, and links into the
  published documentation — with the stale reference sections removed rather than corrected.

### Out of scope

- Code-signing the executable. It would remove the SmartScreen prompt outright, but it costs money
  and needs an owner; documenting the workaround is what this lot does.
- Re-releasing. rc5 carries the audible preload; whether that warrants an rc6 is Zip's call.

### Acceptance

- The preload plays to a country absent from the mission, verified on the fixture mission and on
  synthetic missions where the preferred countries are taken.
- `ctld.yamlConfigDatas` and `_cfg.settings` no longer appear in the README.
- Every documentation link in the README resolves to a page that exists.
- `pytest`, `ruff format/check`, `mypy` clean.
