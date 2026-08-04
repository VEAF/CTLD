# CTLD 2.0.0-rc6 — release candidate

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the
   beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click
**More info** → **Run anyway**. If the file came through a browser you may also need right-click →
**Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the
[documentation](https://veaf.github.io/CTLD/2.0.0-rc6/mission-maker/).

---

**If you installed a mission with rc5, re-install it with this version.** rc5's installer made your
beacon sounds play out loud at mission start — a beacon tone every connected player heard. The engine
is unchanged; re-installing over rc5's work fixes it in place.

## What's fixed

- **The beacon sounds no longer play out loud at mission start.** rc5 added a trigger referencing the
  two sound files, which is what stops the Mission Editor from deleting them — but it played them to
  everyone. The trigger now addresses a country your mission does not use, so the files stay
  registered and nobody hears a thing. This is the same technique the manual instructions have always
  described, now done for you.

## Also in this release

- **The documentation says what to do when Windows blocks the tool.** `ctld-tools.exe` is not
  code-signed, so Windows stops it on a first run behind a screen that reads like a virus warning. The
  way past it is now written down — in the release page above, in the README, and in the mission maker
  guide.

- **The README matches the tool again.** It still described configuring CTLD by hand-editing Lua
  tables, a model replaced some time ago, and its installation section predated `ctld-tools`
  entirely. It is now a short entry point that links the published guides.

## Nothing to change in your configuration

No setting added, renamed or removed. The engine is rc5's apart from its version stamp — everything
in this release is in the tool and the documentation.

## Contributors

**FullGas** (lead developer), **Zip** (technical support) — VEAF.

The sound fix is Zip's: he specified the right technique from the start, and this release is what it
should have been in rc5.
