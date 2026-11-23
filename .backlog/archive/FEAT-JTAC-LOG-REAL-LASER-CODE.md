# FEAT-JTAC-LOG-REAL-LASER-CODE

**Status:** merged (PR #287) — 01 ✅ verified in game (Zip, 2026-11-05). Compacted from `FEAT-JTAC-LOG-REAL-LASER-CODE/` on 2026-11-23; the ticket files live on in git history.

Reported by VMCT from the Sinai Open Training v6 (2026-10-12): Reaper 1 (imposed 1511) claimed nine targets in an hour, yet an A-10C's TGP LSS on 1511 at 15 nm found no spot. The log holds only claim and release, never the code or the spot, so the report cannot be settled. Log both, then test the hypotheses (code, LSS range, line of sight, shared code).

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-log-the-code-then-measure-the-lss` | — | 01 — Log the real code and the spot, then find why the LSS saw nothing |

## PRD

## FEAT-JTAC-LOG-REAL-LASER-CODE — the JTAC never logs its laser code or its spot, so a "no laser" report cannot be settled

Status: ✅ done — the log lines are in (2026-11-04); verified in game by Zip, 2026-11-05

### Found

David and Claude, 2026-10-12, Sinai Open Training v6 on dcs.veaf.org (Privé 1, VMCT 6.29.0).
Reaper 1 is an ASSETS drone with `jtac: 1511`.
The log shows it claiming nine targets one after the other between 19:59 and 20:58 UTC (`[JTAC] claim` / `release claim`), yet David, in an A-10C_2 with the TGP LSS on 1511 for about a minute at 15 nm, found no spot. His own TGP laser was on 1681, so the kills that coincided with a claim release were his own.
The log cannot say which code the drone's spot actually carried, nor whether `Spot.createLaser` returned a spot at all: `_claimTarget` and `_releaseTarget` are the only JTAC lines.

### Tickets

| # | Ticket | Status |
|---|---|---|
| 01 (`01-log-the-code-then-measure-the-lss`) | Log the real code and the spot, then find why the LSS saw nothing | ✅ logging done, verified in game by Zip, 2026-11-05 |

### Definition of done

- The new log lines exist and a Lua test asserts them.
- The ticket ends with a cause, or with the measurement that rules the drone out; DCS is needed (David or a running session), so it cannot be closed from the repository alone.
- VMCT then takes the vendored file (a chore on that side); a surprising DCS behaviour measured goes into VMCT's `known-limitations.yaml`.
- `CHANGELOG.md` entry under `[Unreleased]`.

Related, already merged: `FIX-JTAC-IMPOSED-CODE-AND-RADIO` (PR #258), which keeps an imposed code out of the pool.
