# 04 — An optional guard against unpacking in a logistic zone, and a notice for the retired v1 key

**Status:** ✅ done (PR #NN) · **Type:** AFK

## Parent

[PRD — FIX-LEGACY-MOVE-AND-DEPLOY-SETTINGS](../PRD.md), [ADR 0029](../../../dev/adr/0029-dropped-groups-act-alone-and-the-unpack-guard-is-optional.md). Stories 14-22, 25. GitHub issue #309.

## What to build

- **`forbidUnpackInLogisticZone`**: a new boolean setting, off by default (nothing is blocked, CTLD 2's logic is kept). When on, an ordinary crate (a vehicle, an AA system) is refused by the *Unpack Crate* menu inside a friendly logistic zone, and a parachuted equipment crate no longer unpacks by itself there. The refusal message is the v1 one, "You can't unpack that here! Take it to where it's needed!", whose translations already exist (the Korean one is checked and added if missing). The FOB and the FARP scenes keep their own rules. The test of "inside a friendly logistic zone" is the one the FOB guard already uses.
- **The catalogue and `ctld-tools`**: the key joins the catalogue (the version goes up again only if ticket 01 has not already raised it for this release, and the shape is recorded), the schema gets a boolean entry in the crates family with an English and French label and description, and the settings tables (EN and FR) get the row.
- **A start-up notice** when a snapshot still carries `minimumDeployDistance`: it is not read by CTLD 2, and the notice names `forbidUnpackInLogisticZone`, built the way the `dropOffZones` one is.
- **The migration guide (EN and FR)** covers the two v1 settings and what each became, and the **CHANGELOG** records the lot: the new default behaviour of dropped groups and how to get idle groups back (both distances at 0), the new option, the notice.
- **The backlog index** line of the lot is added in the pull request ("in progress"), then set to `merged (PR #NN)`.

## Acceptance criteria

- [x] With the option on, the menu unpack of a vehicle or an AA system inside a friendly logistic zone is refused with the v1 message and nothing is consumed; outside a zone it unpacks as before.
- [x] With the option on, a parachuted equipment crate landing in a logistic zone is not unpacked by itself; with it off, nothing changes.
- [x] The FOB and the FARP scenes behave as before in every case.
- [x] A snapshot carrying `minimumDeployDistance` produces the start-up notice naming the new setting; one without it produces none.
- [x] The key is in the catalogue (false), the catalogue version and shape are consistent, the `ctld-tools` schema and the settings tables (EN and FR) describe it; the migration guide (EN and FR) and the CHANGELOG are updated.
- [x] The new cases fail before the change and pass after it; the existing unpack and configuration specs pass unchanged; the dictionaries are regenerated for the reactivated message.
- [x] `busted tests/ci/` green; luacheck clean; the catalogue shape test passes.

## Blocked by

None - can start immediately.
