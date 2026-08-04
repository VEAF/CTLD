# 03 — A README that matches the product

**Status:** done
**Lot:** FIX-PRELOAD-AND-INSTALL-DOCS

## Problem

The README had drifted well past "slightly out of date":

- it documented **`ctld.yamlConfigDatas`**, a name absent from the entire repository — the
  pre-ADR-0011 configuration model;
- and **`_cfg.settings[...]`** (23 occurrences, zero in the published documentation), replaced by the
  complete YAML snapshot in `ctld.configUser`;
- its installation section walked through downloading `CTLD.lua` and wiring triggers by hand, with no
  mention of `ctld-tools` — the entry point three merged lots exist to establish;
- it carried "FARP Repack", a word this project banned in favour of "pack";
- and it duplicated whole reference sections (crates, JTAC, zones, events, AA templates) that the
  documentation site now owns. A duplicate that drifts is worse than a link, and this one had.

## Change

Rewritten as an entry point rather than a manual: what CTLD is, how to install it (the tool, then the
manual path, then the Windows unblock instructions), links into the three published guides, the
feature list, and a short "coming from v1" section. Every reference section that the site owns is now
a link to it.

Two decisions worth recording:

- **Links point at the site root or at `dev/`, not at `/latest/`.** There is no `latest` alias yet:
  by the rule set in `FEAT-TOOL-VERSION-AND-DOCS`, it is created by the first *stable* release, and
  `versions.json` currently holds `dev`, `2.0.0-rc4` and `2.0.0-rc5` only. The root redirects to the
  default version, so it never breaks and never needs editing.
- **The manual-install section keeps the Sound-to-Country instruction** — it is the same mechanism
  ticket 01 automates, and a hand-made install needs it just as much.
