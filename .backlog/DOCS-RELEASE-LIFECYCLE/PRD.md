# DOCS-RELEASE-LIFECYCLE — how a new CTLD reaches a mission

## Why

Question from **FullGas**: *does `ctld-tools.exe` always download the latest build after a merge, or
do I have to publish a release (which I have never done)?*

The answer is written in the code and nowhere a Mission Maker reads it. `resources.py` explains the
decision — `FEAT-ONE-CLICK-INSTALL` chose to **bundle** the engine rather than download it, so the
exe installs the engine of its own release and works offline — and `release.yml` only runs on a
`published-v*` tag, `--add-data "../../CTLD.lua;ctld_data"`. Neither the README nor the mission-maker
guide says any of it, so the natural assumption is the opposite one: that the tool fetches whatever
is current.

Two consequences a maintainer needs stated:

1. a merge into `develop` reaches nobody — only a published release does;
2. an exe never updates itself, so a Mission Maker on rc4 stays on the rc4 engine until they
   download the exe again.

A third detail belongs with them: while v2 is in release candidate, every release is a
**pre-release**, so GitHub's *Latest* badge is on none of them (`releases/latest` currently redirects
to the Releases index — verified, HTTP 302). Someone told to "take the latest" finds no badge.

## Scope

- README, installation section: a short **Getting a newer CTLD** subsection.
- Mission-maker guide `ctld-tools.md` + `ctld-tools.fr.md`: the same, in the *Get the tool* section,
  where a reader is already looking at the download.

## Out of scope

- Any change to the mechanism: no auto-update, no update check, no download path. The bundled engine
  is a decision `FEAT-ONE-CLICK-INSTALL` took on purpose (offline install, reproducible result).
- The `../../releases/latest` link at the top of the README. It redirects to the Releases index today
  and becomes exact the day 2.0.0 stable is tagged; the new subsection states the pre-release rule
  instead.
