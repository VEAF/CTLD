# POST-FULLGAS-FIXES

**Status:** delivered. Compacted from `POST-FULLGAS-FIXES/` on 2026-08-01; the ticket files live on in git history.

Applied FullGas's review answers: Feature Q whole-vehicle spawn regression, AI-zone stock validation rewrite, U-108 heliport probe fixes, F-117/F-118 recon fixes, `coord_farp-1` mission static, README doc touch-ups. First full live run against real DCS (27/45) surfaced 18 failures, 8 fixed here as a side effect — remaining 10 → `FIX-LIVE-DCS-FAILURES`. PR #22.

## Tickets

| Ticket | Status | Title |
|---|---|---|
| `01-fq-regression` | ✅ done | 01 — F-Q whole-vehicle regression (Feature Q) |
| `02-u108-runonce` | ✅ done | 02 — U-108 ProbeOffMap + ProbeLifeCheck |
| `03-u108-warnandskip` | ✅ done | 03-u108-warnandskip |
| `04-recon-f117-f118` | ✅ done | 04-recon-f117-f118 |
| `05-fr-ai-zones` | ✅ done | 05-fr-ai-zones |
| `06-coord-farp-miz` | ✅ done | 06-coord-farp-miz |
| `07-readme-doc` | ⏸ deferred | 07 — README doc touch-ups |

## PRD

## Lot POST-FULLGAS-FIXES — apply FullGas's review answers

Status: 🚧 in progress
Branch: fix/post-fullgas-corrections → PR → develop
Program: re-tooling CTLD on the VMCT model (see `.backlog/README.md`). Follows
`REINTEGRATE-ORPHAN-TESTS`; sibling to the (still-open) `CLEANUP-LEGACY-DCS-TESTS`.

### Problem Statement

FullGas reviewed our `dev/fullgas-report.md` findings and answered each one. Several are not
"design questions to defer" but concrete corrections we can now apply — one is a real product
regression, the rest are stale tests to rewrite against the current design, plus a mission-content
gap and doc touch-ups.

### Tickets

| # | Scope | Nature |
|---|-------|--------|
| 01 | F-Q whole-vehicle regression: restore Feature Q `loadableList` in `refreshRequestEquipmentSection` (dropped by commit 0a15814, ref b1ddfe4) | **src** + rebuild |
| 02 | U-108 ProbeOffMap + ProbeLifeCheck: run-once guard (FullGas option A) | test |
| 03 | U-108 WarnAndSkip: rewrite — assert `Farp_FG_Petit_Helipad` (probeSkip) excluded, 3 stock heliports present as HELIPORT, INFO "skipped" emitted | test |
| 04 | F-117/F-118 recon: `reconEnabled`→`reconF10Menu` + keyword; `nil`→`~=nil` (scan stays active) + targets empty | test |
| 05 | fr_ai_zones: impl `pickMaxStock = entry.isPickup and 0 or nil` + G3 extended (WARN on scalar/empty-table troopStock, incl. -1 legacy) + rewrite the 7 checks | src + test |
| 06 | Re-add static `coord_farp-1` (group "coord_farp", M92 barrel) to `Test_CTLDNEXT_01.miz` | mission |
| 07 | README doc: title "DCS-CTLD Next"→"CTLD"; "Pack Equipt" under "Crate Operations"; "Developer documentation"→"Guides" (link to the guides site) | doc |

### Decisions

- **F-R-3** (ticket 05): `troopStock = -1` legacy scalar → emit the G3 WARN "invalid format" (guide
  the mission-maker to `{All=-1}`), rather than tolerate silently. Confirmed by David.

### Non-goals

- Porting/purging the 194 relics — that's `CLEANUP-LEGACY-DCS-TESTS` (port-to-VEAF then delete all).
- Any commit reference from FullGas's fork (0a15814, b1ddfe4): those objects exist in our repo but
  are NOT in develop's lineage — used as read-only parity references, never cherry-picked.
