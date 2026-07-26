# 08 — Docs + CHANGELOG

**Status:** done

## Work

- `docs/mission-maker/ctld-tools.md` (+ `.fr.md`) — update the walkthrough to the new UI: boots on
  the defaults, one navigation by family, search, reset-to-default, the 3-step strip and the
  validation panel. Screenshots/wording that describe the old `Parameters` / `Data` tabs must go.
- `tools/ctld-tools/README.md` — the web-app section: the UI is organised by functional family; note
  that UI labels are derived in the frontend (`labels.ts`) and that enriching
  `src/CTLD_config_schema.yaml` with `group:`/`label:`/`unit:` is the durable follow-up.
- `dev/roadmap.md` — record the two deferred follow-ups: UI i18n (FR) and schema enrichment.
- `CHANGELOG.md` `[Unreleased]` — one entry under the tooling section. `src/` is untouched by this
  lot, so the `changelog-guard` job does not apply, but the exe is a user-facing deliverable and the
  change is worth recording.
