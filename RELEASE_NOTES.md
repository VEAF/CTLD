# CTLD 2.0.0-rc4 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/).

---

CTLD 2.0 is a **complete rewrite** of the CTLD v1 script: the monolith becomes a set of **testable**
Lua modules (Manager/Entity object design), covered by continuous integration — one build, more than
1,100 unit and functional tests, plus integration tests in a live DCS.

This **rc4** is about the three steps above. Until now, adding CTLD to a mission meant fetching the
script, fetching two sound files from the repository, dropping them into the `.miz`, adding a trigger
by hand, and only then running the tool for the configuration. Five steps, none of them announced —
and one of them, the sound files, silently left every beacon in the mission mute when it was missed.

Now there is one file to download and one button to press.

## What's new

- **The tool installs CTLD, not just its configuration.** `ctld-tools.exe` carries the engine and
  both beacon sounds; **Install into mission…** writes them into your `.miz` along with your
  configuration and the two MISSION START triggers that load them, in the right order. It then tells
  you what it wrote — engine version, files, triggers, how many settings differ from the defaults —
  so you can check without opening the mission in the editor. Installing again replaces the previous
  install rather than leaving a second copy behind.

- **Open a mission and get its configuration back.** Point the tool at a `.miz` you configured last
  month and your settings return, ready to edit. Missions prepared with rc1, rc2 or rc3 are read too,
  even though their configuration was stored differently.

- **"Disembark Troops" now appears in flight**, whenever fast-rope insertion is enabled and troops
  are aboard. The entry used to be drawn only on the ground, which made fast-rope impossible to
  trigger from the F10 menu — the feature existed and the menu hid it. Clicking it when the
  conditions are not met now tells you which one: too high, or too fast, as two distinct messages.

- **CTLD's interface language is settable from the tool.** It always worked in a hand-written
  configuration but never appeared in the app — reported by FullGas. It now sits in the **General**
  family, with the four languages CTLD ships: English, French, Spanish, Korean.

- **A help button that leads somewhere.** The panel already described the configuration you had open;
  it now also links the documentation for the version you are running — getting started, every
  setting explained, zone setup, and the guide for anyone coming from CTLD v1 — and shows the CTLD
  version, which is the thing to quote when reporting a problem.

- **The beacon sounds are attached to this release.** `beacon.ogg` and `beaconsilent.ogg` used to live
  only in the repository, while the documentation said a mission needs them or its beacons stay
  silent. Installing by hand is now possible from this page alone.

- **The documentation is published per version.** Each release gets its own copy of the pages, so a
  mission built on an older CTLD can still be read against the documentation that matched it.

## Nothing to change in an existing mission

No breaking change, no setting renamed or removed in this release. If you install by hand, keep doing
so — the script and the sound files are attached below, and the manual path stays documented as the
alternative rather than being dropped.

## Contributors

**FullGas** (lead developer), **Zip** (technical support) — VEAF.

Two of this release's changes come straight from FullGas: the fast-rope menu fix, and spotting that
CTLD's own interface language could not be set from the tool.
