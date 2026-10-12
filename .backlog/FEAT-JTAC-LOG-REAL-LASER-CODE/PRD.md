# FEAT-JTAC-LOG-REAL-LASER-CODE — the JTAC never logs its laser code or its spot, so a "no laser" report cannot be settled

Status: ⬜ ready

## Found

David and Claude, 2026-10-12, Sinai Open Training v6 on dcs.veaf.org (Privé 1, VMCT 6.29.0).
Reaper 1 is an ASSETS drone with `jtac: 1511`.
The log shows it claiming nine targets one after the other between 19:59 and 20:58 UTC (`[JTAC] claim` / `release claim`), yet David, in an A-10C_2 with the TGP LSS on 1511 for about a minute at 15 nm, found no spot. His own TGP laser was on 1681, so the kills that coincided with a claim release were his own.
The log cannot say which code the drone's spot actually carried, nor whether `Spot.createLaser` returned a spot at all: `_claimTarget` and `_releaseTarget` are the only JTAC lines.

## Tickets

| # | Ticket | Status |
|---|---|---|
| [01](tickets/01-log-the-code-then-measure-the-lss.md) | Log the real code and the spot, then find why the LSS saw nothing | ⬜ |

## Definition of done

- The new log lines exist and a Lua test asserts them.
- The ticket ends with a cause, or with the measurement that rules the drone out; DCS is needed (David or a running session), so it cannot be closed from the repository alone.
- VMCT then takes the vendored file (a chore on that side); a surprising DCS behaviour measured goes into VMCT's `known-limitations.yaml`.
- `CHANGELOG.md` entry under `[Unreleased]`.

Related, already merged: `FIX-JTAC-IMPOSED-CODE-AND-RADIO` (PR #258), which keeps an imposed code out of the pool.
