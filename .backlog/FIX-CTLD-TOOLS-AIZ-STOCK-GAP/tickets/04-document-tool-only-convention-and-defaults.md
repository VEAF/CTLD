# 04 — Mission-maker docs: document the `ctld-tools`-only convention, recommend keeping it complete

**Status:** ✅ done

**Blocked by:** ticket 01 (describes real, shipped default-filling behaviour) and ticket 03 (describes the visual indicator this ticket points to) — write once both are true, not before.

## What to build

`docs/mission-maker/zones.md` / `.fr.md`'s "AI transport zones (AIZ)" section states *"AIZ zones
have no naming convention"* — still true of the **engine** (unchanged, keep that statement), but
incomplete now that `ctld-tools` itself recognises an optional, partial naming pattern purely to
pre-fill its own editor (`AIZ_<name>_<coalition>_<P|D>_<cargoType-or-aiDropMode>`, `ADR 0017`,
`CONTEXT.md`'s "Tool-only naming convention"). Add a short subsection explaining:

- The pattern exists **only inside `ctld-tools`**, never interpreted by CTLD itself — naming a
  zone this way changes nothing about how the mission runs, only how much `ctld-tools` can
  pre-fill for you.
- **Recommend keeping it complete** (all four fields) if you want `ctld-tools`' mission scan to
  auto-detect and pre-fill a zone's coalition, pickup/drop-off and cargo type for you. An
  incomplete or non-matching name is not an error — the zone still works exactly the same in
  DCS — but `ctld-tools` cannot auto-detect it, so you fall back to the manual "+ AI zone" button
  and its own generic defaults (`BLUE`, pickup, `cargoType: T`), which may not match what you
  actually meant and have to be corrected by hand, field by field.
- The new default-filling behaviour itself (ticket 01): a pickup zone with troop cargo gets
  `troopStock: {All: -1}` automatically from either creation path — a safe starting point, not a
  statement of your real intent. Point at the editor's own indicator (ticket 03) as the visible
  reminder to review and narrow it rather than leave the blind default in place.

## Watch out

- Do not contradict or remove the existing, still-correct statement that the **engine** has no
  `AIZ_` naming requirement — this is additive context about the authoring tool, not a correction
  of a wrong claim.
- Keep English and French in parity, as with every other published doc change in this project.
- `docs/developer/subsystems/zones.md` documents the engine's own auto-discovery algorithm
  (`TRZ_`/`LGZ_`/`WPZ_`/`EXZ_`); add at most a brief pointer to `ADR 0017` near its existing "TRZ
  naming convention" section clarifying that `AIZ_`'s convention lives in `ctld-tools` only and is
  not part of that algorithm — don't duplicate the Mission-Maker-facing explanation there.

## Acceptance

- `docs/mission-maker/zones.md` and `.fr.md` explain the `ctld-tools`-only convention, recommend
  keeping it complete, and describe the new `troopStock` default — in parity.
- The engine-has-no-convention statement is preserved, not deleted or contradicted.
- `docs/developer/subsystems/zones.md` gains a brief, correctly-scoped pointer to `ADR 0017`.

## Tests

Docs change: no automated test — manual EN/FR parity review, matching this project's convention
for documentation-only tickets.
