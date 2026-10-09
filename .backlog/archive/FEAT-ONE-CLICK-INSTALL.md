# FEAT-ONE-CLICK-INSTALL

**Status:** merged (PR #92). Compacted from `FEAT-ONE-CLICK-INSTALL/` on 2026-10-09; the ticket files live on in git history.

**The Mission Maker's entry point becomes the tool**: download `ctld-tools.exe`, run it, and the engine, the beacon sounds, the configuration and the triggers all go into the `.miz` — the VMCT model. Today that is five manual steps, and step 3 bites hardest: `beacon.ogg` / `beaconsilent.ogg` are **not release assets** (repo-only, in `assets/`), so a mission ships with silent beacons and nothing says why. Decided: the exe **carries** CTLD + the sounds rather than downloading them (+7% on a 21 MB exe, works offline, an exe can only install its own release's engine — and the `--add-data` mechanism already bundles the YAML and the schema); everything lands as **files** with `DO SCRIPT FILE` triggers, config before engine; and the tool can **read a configuration back out of a `.miz`**, which is trivial once the config travels as a file instead of an escaped Lua string inside `mission`. Read VMCT's mission builder for the resource-key plumbing rather than reinventing it.

## Tickets

> **On the ticket statuses below:** the lot's own status is what was tracked; per-ticket
> `Status:` lines were not always updated on the way out. Where they disagree, the lot status
> and the delivering PR are authoritative.

| Ticket | Status | Title |
|---|---|---|
| `01-bundle-the-engine-and-the-sounds` | done | 01 — the exe carries `CTLD.lua` and the two `.ogg` |
| `02-install-into-the-miz` | done | 02 — write the engine, the sounds and the config into the `.miz` |
| `03-read-the-config-back` | done | 03 — open a `.miz` and edit the configuration it carries |
| `04-one-button-and-the-docs` | done | 04 — one button in the tool, and the documentation to match |

## PRD

## FEAT-ONE-CLICK-INSTALL — `ctld-tools.exe` installs CTLD, not just its configuration

**Status:** open.

Opened 2026-08-01. The Mission Maker's entry point becomes the tool: **download `ctld-tools.exe`,
run it.** Everything else — the engine script, the beacon sounds, the configuration, the triggers —
is the tool's job. Same model as the VEAF Mission Creation Tools.

### What a Mission Maker does today

Five manual steps, and nothing tells them any of it:

1. download `CTLD.lua` (1.1 MB) from the release;
2. download `beacon.ogg` and `beaconsilent.ogg` — which are **not release assets**, only files in
   `assets/` in the repository;
3. drop both `.ogg` into the `.miz`, or beacons are silent — `configuration.md` states the
   requirement, nothing enforces it;
4. add a MISSION START `DO SCRIPT FILE` trigger for `CTLD.lua`;
5. run `ctld-tools.exe`, which injects **only** the configuration, as an inline `a_do_script`
   trigger at rank 1.

Step 3 is the one that bites: a mission ships, the beacons do nothing, and the log says nothing
either.

### Decisions taken (David, 2026-08-01)

**1. The exe carries CTLD, it does not download it.** `CTLD.lua` (1.1 MB) and the two `.ogg`
(420 KB) are bundled into the 21 MB exe — about 7% more. In exchange: the tool works with no
network, and an exe from a given release can only ever install *that* release's engine. No version
mixing, no "download failed" path to design. The mechanism already exists: the exe bundles
`CTLD_config.yaml` and `CTLD_config_schema.yaml` through PyInstaller `--add-data`.

**2. Everything goes into the `.miz` as files, not inline.** `CTLD.lua`, `CTLD_userConfig.lua` and
the two `.ogg` are written into the archive; the triggers are `DO SCRIPT FILE`. This is what the
Mission Editor does, what `dist/CTLD_userConfig.lua`'s own instructions describe, and it keeps a
1.1 MB Lua string out of the serialised `mission` table.

**3. The tool can read a configuration back out of a `.miz`.** Today the YAML *is* in the archive,
but wrapped in an escaped Lua string inside the `mission` file — recoverable only by deserialising
the mission and unescaping. Once the config travels as a file (decision 2), reading it back is
opening the zip. One source of truth: no separate `.yaml` copy alongside the script, because two
copies drift. (The engine cannot read a `.yaml` from the archive itself — the mission scripting
environment has no file access — so the YAML must travel inside a script either way.)

### Definition of done

- A Mission Maker with a stock `.miz` and `ctld-tools.exe` gets a working CTLD mission without
  downloading anything else and without touching the Mission Editor.
- Re-running the tool on an already-injected `.miz` replaces what it injected, and does not
  accumulate triggers, files or duplicates.
- Opening an injected `.miz` in the tool shows that mission's configuration, ready to edit.
- The trigger order is guaranteed: configuration **before** the engine.
- Nothing regresses for a Mission Maker who prefers doing it by hand — the release keeps shipping
  `CTLD.lua`, and the `.ogg` files join it.

### Out of scope

- The version-aware help link and the versioned documentation — `FEAT-TOOL-VERSION-AND-DOCS`.
- The release notes' installation section — `CHORE-RELEASE-INSTALL-NOTES`, deliberately last: it
  documents the journey this lot builds.
- Injecting anything else a mission might want (scenes, plugins). One journey at a time.
