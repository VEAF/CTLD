# CTLD 2.1.1

## Installation

1. Download **`ctld-tools.exe`** below — it is the only file you need.
2. Run it: the tool opens in your browser, locally, with nothing to install.
3. Open your `.miz`, adjust what you want, then **Install into mission**: the tool writes CTLD, the beacon sounds and your configuration into it.

**Windows blocks it on the first run?** The tool is not code-signed, so SmartScreen stops it: click **More info** → **Run anyway**.
If the file came through a browser you may also need right-click → **Properties** → tick **Unblock** → **OK**.

Prefer doing it by hand? The files are attached to this release too — see the [documentation](https://veaf.github.io/CTLD/2.1.1/mission-maker/).

---

CTLD 2.1.1 is a small release with a single fix, for the AI Fat Cow.
A mission configuration written for 2.1.0 keeps working unchanged.

## What changes in game

- **An AI Fat Cow no longer flies until it runs dry.** On a live server, an AI cow packed its FARP on an F10 order and then kept flying for over five hours until it ran out of fuel and vanished. Now:
  - an AI cow in the air with less than 25 % of its fuel goes home, whatever it was told, and its flight reads "The Fat Cow is low on fuel and returns home.";
  - a cow whose flight has left the server (every pilot gone) goes home reliably, instead of depending on a single check that DCS could beat.

## For mission makers

- Every F10 order given to an AI cow (Land here, Take off, Hold here, Join us, RTB, Release, Take over) and every change of its phase now writes one line in the log, so a cow that behaves oddly can be explained afterwards.
- No setting was added or changed.

See the [documentation](https://veaf.github.io/CTLD/2.1.1/) for pilots and Mission Makers, and `CHANGELOG.md` for the full list.

---

CTLD is the work of FullGas and Zip, of the VEAF.
Thanks to the VEAF pilots who fly CTLD on the Open Trainings and report what goes wrong.
