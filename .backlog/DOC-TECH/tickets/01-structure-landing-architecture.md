# 01 — Developer section: structure, landing & architecture (EN)

Status: ✅ done
Type: AFK

## What to build

Create the `docs/developer/` section skeleton and its first content pages (EN):

- `docs/developer/index.md` — landing page: what the developer docs cover, how to navigate them,
  and the architecture overview (from `dev-guide.md` §1 Repository structure + §2 Architecture
  overview, including the CTLDCoreManager init sequence).
- `docs/developer/architecture.md` — repo structure, CoreManager init sequence, the module pattern
  ("Adding a new module", §3), and the internal libraries (§19: `class.lua`,
  `CTLD_objectRegistry`, `CTLD_modValidator`, `CTLD_utils`).

Fix the broken sub-section numbering while porting. Preserve diagrams/assets (reference the
existing `docs/assets/` SVGs).

## Acceptance criteria

- [ ] `docs/developer/index.md` and `architecture.md` exist, EN, well-numbered.
- [ ] Content is faithful to `dev-guide.md` §1–3 + §19 (no behavioural invention).
- [ ] Internal cross-links use relative paths that resolve under mkdocs.

## Blocked by

None.
