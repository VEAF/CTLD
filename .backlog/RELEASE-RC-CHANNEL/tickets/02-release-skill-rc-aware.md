# 02 — release skill: rc-aware bump + conditional CHANGELOG freeze

Status: ✅ done
Type: AFK
Repo: CTLD
GitHub: —

## What to build

Extend `.claude/skills/release/SKILL.md` so it handles a pre-release (rc) cut distinctly from a
stable one. The branch/PR/tag mechanics are unchanged (release branch from `develop`, PR to
`develop`, manual `published-vx.y.z` tag after merge).

1. **Version step** — allow a pre-release target such as `x.y.z-rcN` (propose the next rc when the
   maintainer is iterating on an unreleased version). `ctld.VERSION` in `src/CTLD_config.lua` is set
   to the exact string, suffix included.
2. **CHANGELOG handling — conditional on rc vs stable (decision c):**
   - **rc** (`-`-suffixed): **do not** convert `## [Unreleased]`. Leave it open so post-rc fixes keep
     landing there. (Optionally add a dated `## [x.y.z-rcN]` heading *above* `[Unreleased]` that
     captures the rc snapshot — author's call; the invariant is that `[Unreleased]` survives.)
   - **stable** (`x.y.z`): rewrite `## [Unreleased]` → `## [x.y.z] — YYYY-MM-DD`, as today.
3. **Note the CD behaviour** in the skill so the maintainer knows what the tag does: a `-rc` tag →
   GitHub pre-release, `published-latest` untouched; a plain tag → stable release, `published-latest`
   advances (delivered by ticket 01).
4. Everything else (consolidation interview, `RELEASE_NOTES.md` drafting filtered for the community,
   rebuild after the version bump, the final manual tag commands) stays as-is.

Documentation only — the skill file. No `src/` change, no rebuild, no tests.

## Acceptance criteria

- [ ] Skill supports an `x.y.z-rcN` target and sets `ctld.VERSION` to the suffixed string.
- [ ] Skill keeps `## [Unreleased]` open for an rc; freezes it to `## [x.y.z] — date` only for a stable.
- [ ] Skill states the CD effect of an rc tag vs a stable tag (pre-release / `published-latest`).
- [ ] Branch/PR/tag flow unchanged (PR to `develop`, manual `published-vx.y.z`).

## Blocked by

None. Independent of ticket 01 (documents behaviour ticket 01 delivers; either can land first).
