# 04 — one button in the tool, and the documentation to match

**Status:** done

Depends on: 02, 03.

## What changes

**In the tool.** "Inject into mission…" stops being a configuration-only action and becomes the
install: pick a `.miz`, and the tool writes the engine, the sounds, the configuration and the
triggers. The wording must say what it does now — a Mission Maker who reads "inject the
configuration" will not believe their engine got installed. Report what was written, so the result
is verifiable without opening the archive:

```
Installed into Caucasus-CTLD.miz
  • CTLD 2.0.0-rc3 (engine)
  • beacon.ogg, beaconsilent.ogg
  • configuration — 14 settings changed from defaults
  • 2 MISSION START triggers (configuration, then engine)
```

**In the documentation.** `docs/mission-maker/` currently teaches the five manual steps. The tool
path becomes the documented one, in EN and FR:

- the getting-started page leads with **download the exe, run it, pick your `.miz`**;
- the manual path stays, for whoever wants it — but as the alternative, not the default;
- the `radioSound` / `radioSoundFC3` rows lose their "must be added to the mission `.miz`" warning
  when the tool is used, and keep it for the manual path. Do not delete the requirement, relocate it.

## Watch out

The tool's install report claims a version ("CTLD 2.0.0-rc3"). It must come from the bundled engine,
not from a string in the frontend — `FEAT-TOOL-VERSION-AND-DOCS` ticket 01 gives the tool a real
version; if that lot has not landed, read it from the bundled `CTLD.lua` header rather than inventing
a second source.

## Acceptance

- A Mission Maker following the getting-started page, having downloaded only `ctld-tools.exe`, ends
  with a working CTLD mission.
- The install report names what was written, including the engine version.
- The manual path is still documented and still correct, `.ogg` requirement included.
- EN and FR say the same thing.

## Tests

- Frontend: the install result renders every line of the report from the API response (no hardcoded
  strings).
- pytest: the install API returns the counts and the version the report displays.
- `mkdocs build --strict`.
