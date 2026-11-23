# 07 — Backlog housekeeping

**Status:** 🟡 ready · **Type:** AFK, no `src/` change

## Parent
[PRD](../PRD.md).

## What to build
- Archive every lot of the `Active lots` table of `.backlog/README.md` merged before 2026-11-20 into `.backlog/archive/<LOT-ID>.md`, following the format of the existing archive files, and move its line to the `Delivered` table. Leave `FIX-VMCT-REVIEW-FINDINGS` and `FEAT-VMCT-V1-PARITY` active.
- In `CHANGELOG.md` `[Unreleased]`, FIX-CREATE-BEFORE-DESTROY, AA systems paragraph: drop "to be confirmed on the live check". That live check passed on 2026-11-09 (ticket 06 of that lot).

## Acceptance criteria
- [ ] `Active lots` holds only the lots merged on or after 2026-11-20 and this pair; every archived lot has its file and its `Delivered` line; no link broken.
