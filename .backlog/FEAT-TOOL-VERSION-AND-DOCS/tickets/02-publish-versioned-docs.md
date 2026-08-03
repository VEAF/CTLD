# 02 — publish the documentation per version, on the tag

**Status:** todo

Depends on: 01 (they must agree on the version string).

## Why

`docs.yml` deploys `mike deploy --push --update-aliases dev` on every push to `develop`, and nothing
runs on a tag, so `versions.json` has exactly one entry. There is no per-release documentation for a
help link to point at, and no way for a Mission Maker on rc2 to read rc2's pages.

## What changes

- **On a `published-v*` tag**, publish that version's documentation: `mike deploy <version>` where
  `<version>` is the tag's `x.y.z[-rcN]`, in the release workflow or a tag-triggered docs job.
- **Aliases, deliberately**:
    - a **stable** tag also updates `latest` (the alias a bare documentation link should land on);
    - a **pre-release** tag does **not** touch `latest` — same discipline as `published-latest` for
      the downloads, and the same reason: an rc must not become what a newcomer reads by default.
- `dev` keeps tracking `develop`, unchanged.
- The documentation site's version selector then shows something real; check that the mkdocs `extra`
  block (already `provider: mike`) renders it, since it has only ever had one entry to show.

## Watch out

- **This lot does not backfill.** rc1 and rc2 documentation will not exist, and that is fine — but
  the link rule in ticket 03 must therefore treat "no documentation for this version" as normal
  rather than broken, which it does by sending every `-rc` to `dev`.
- `mike` rewrites the `gh-pages` branch. Deploying from two workflows (push-to-develop and
  tag) can race. Serialise them (a concurrency group) rather than discover it on a release day.

## Acceptance

- Tagging a pre-release publishes documentation under that version and leaves `latest` alone.
- Tagging a stable publishes it and moves `latest`.
- `versions.json` lists what has been published; the selector offers it.
- Two deployments triggered close together do not clobber each other.

## Tests

None automatable beyond the workflow running. Verify by tagging into a scratch branch, or by reading
`versions.json` after the next real tag — and say in the PR which of the two was done.
