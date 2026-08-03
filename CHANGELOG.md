# Changelog

All notable changes to DCS-CTLD Next are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [Unreleased]
### Tooling — every release will say how to install CTLD (CHORE-RELEASE-INSTALL-NOTES)

A release page lists several assets and says nothing about what to do with them; someone arriving
from a forum link has to guess which file matters. The `release` skill now requires the notes to
**open** with an installation section — download `ctld-tools.exe`, run it, install into your `.miz` —
and carries the wording as a template so a release cannot ship without it by forgetting to think
about it.

Two rules travel with the template: the exe is named as the **only** file needed, the other assets
belonging to the manual path one sentence lower; and it links to the documentation rather than
duplicating it, since a section that grows becomes a second copy that will contradict the first.

Written last of the three install lots, on purpose: it describes the journey the other two built.

### Added — one button installs CTLD into a mission (FEAT-ONE-CLICK-INSTALL ticket 04)

**Download `ctld-tools.exe`, run it, pick your `.miz`.** That is now the whole installation: the
tool carries the engine and the beacon sounds, and writes them, the configuration and the two
MISSION START triggers into the mission. What used to be five manual steps — fetch `CTLD.lua`, fetch
two `.ogg` from the repository, drop them in the archive, add a trigger, then run the tool for the
configuration — is one action.

The action is called **Install into mission…** rather than *Inject the configuration*, because it
does more than it used to and a Mission Maker who reads "configuration" will not believe their engine
got installed. It reports what landed in the archive — engine version, files, triggers, how many
settings differ from the defaults, and whether a previous install was replaced — so the result is
verifiable without opening the `.miz`.

The mission-maker guide leads with that journey in both languages. The manual path is documented too,
as the alternative rather than the default, and it is the one that keeps the warning about adding the
`.ogg` by hand — a requirement that had been stated on the `radioSound` setting, where someone using
the tool had no way to know it no longer applied to them.

### Fixed — CTLD's interface language can be set from the tool (FIX-TOOL-I18N-LANG)

Reported by **FullGas**: there was no way to choose CTLD's language in `ctld-tools`. Neither the
engine nor the schema was at fault — `CTLD_i18n` resolves it through `ctld.gs("i18n_lang")`, and the
schema declares it with `default: en` and `choices: [en, fr, es, ko]`. The app never showed it because
it lists **catalogue** keys, and this is the only setting of ~150 deliberately absent from the
catalogue: a scalar there would make it a *parameter* under ADR 0011 Addendum 1, so the completeness
rule would demand it and every configuration written for rc1–rc3 would report a missing setting at
mission start.

A regression from the TUI → web app move: the TUI listed schema keys, and the schema comment still
says its default is there to "surface it in the TUI picker". Fixed by offering the settings the schema
declares with a default that the catalogue does not carry — exactly one today — rather than by
cataloguing this one. Setting it writes it to `mm_facing`, where a Mission-Maker-facing setting
belongs.

### Tooling — the tool opens a mission and edits the configuration it carries (FEAT-ONE-CLICK-INSTALL ticket 03)

Once a mission is installed, the `.miz` is where its configuration lives. `ctld-tools` can now read
it back: opening a `.miz` works like opening a `.yaml`, and the tool remembers which mission it came
from.

**Both storage shapes are read**, which matters more than it sounds. Missions installed by rc1–rc3
carry the whole snapshot inside a trigger, not as a file; without that path a Mission Maker opening
last month's mission would be told there is no configuration in it — while their settings sit right
there, unreachable — and would have to redo them by hand.

The extraction is the inverse of the embed, deliberately: `wrap` picks the Lua long-bracket level
from the content (`[[`, `[=[`, `[==[`…), so a fixed pattern would read `[[` correctly and then
truncate a `[==[` snapshot at the first `]]` inside its own YAML. Pinned by tests on the payloads
that break a naive regex — `]]`, `]==]`, `]=]` and `--` inside the configuration.

A mission with no CTLD configuration is not an error: it is what a first install looks like.

### Tooling — the tool installs CTLD into a mission, not just its configuration (FEAT-ONE-CLICK-INSTALL ticket 02)

`ctld_tools.install.install()` writes everything a mission needs into the `.miz`: the engine, both
beacon sounds, the configuration, and the two MISSION START triggers that load them —
**configuration first**, because the engine reads `ctld.configUser` as it loads.

The plumbing was read out of VMCT's mission builder rather than guessed at, and it settled the
question the ticket left open. A **script** needs an entry in `l10n/DEFAULT/mapResource` mapping a
resource *key* to its file name, because `DO SCRIPT FILE` names a key and never a path. A **sound**
needs no entry at all: the engine plays it by name through `radioTransmission`, so presence in
`l10n/DEFAULT/` is the whole requirement.

Re-installing replaces: triggers (matched by comment), resource-map entries and files are all
overwritten, and a `.miz` installed twice holds one member per name — a zip may legally carry
duplicates and DCS reads whichever it finds first, which would make a re-install look like a no-op.
A mission's own resource map survives: we add our two keys, we do not own the file.

The trigger machinery `inject_userconfig` had is now shared (`rebuild_triggers`), and the inline path
stays for the missions rc1–rc3 injected in that shape.

Not wired to the tool's button yet — that is ticket 04, with the documentation.

### Tooling — the exe carries the engine and the beacon sounds (FEAT-ONE-CLICK-INSTALL ticket 01)

Groundwork for the new install journey — download `ctld-tools.exe`, run it, done. The exe now bundles
`CTLD.lua` and both `.ogg` alongside the catalogue and the schema it already carried (three more
`--add-data` entries; the exe grows about 7%). Bundled rather than downloaded on purpose: an exe then
installs the engine of *its own* release and nothing else, and it works with no network.

**`beacon.ogg` and `beaconsilent.ogg` are now release assets.** They were repo-only, under `assets/`,
while the documentation states a mission needs them or its beacons are silent — so the manual install
could not be completed from the release page alone. That gap is closed for the manual path too,
independently of the tool.

One resolver for all four payloads (`ctld_tools/resources.py`, moved out of `ctld_tools/web/` since
the CLI was already importing it from there), and a new `ctld-tools payloads` command that lists them
with their sizes and exits non-zero if one is missing. The release smoke-check runs it: a bundle that
silently loses an `--add-data` entry now fails the release instead of shipping and surfacing in DCS.


### Changed — "Disembark Troops" now visible in flight when fast-rope is enabled (UX-FASTROPE-INFLIGHT)

The F10 menu entry "Disembark Troops" was only rendered when the helicopter was on the ground,
making the fast-rope feature (deploy troops from a low hover without landing) impossible to trigger
from the menu in flight. The entry now appears in flight whenever `enableFastRopeInsertion = true`
and troops are onboard. Clicking it while the conditions are not met (too high or too fast) now
shows two distinct messages — one for altitude, one for speed — instead of a single combined message.

### Fixed — an AI zone dropped for a name clash now says so (FIX-AIZONE-NAME-COLLISION)

`_loadAIZonesFromConfig` skips any entry whose `dcsZoneName` is already a registered troop zone.
The skip is right — a discovered zone wins, as everywhere else in the manager — but it was
**completely silent**: the mission maker got an AI zone that did nothing, and nothing said why.

It is reachable by accident, because the key is the *registered* name, not the Mission Editor one:
a `TRZ_` zone registers under its parsed name, so `TRZ_dropzone1_B_0_nil_0` occupies `dropzone1`
and an `aiZones` entry pointing at a genuinely different ME zone called `dropzone1` collides with
it. The obvious way in is the workaround `FIX-DROPOFFZONES-PARITY` documents — superimposing an
inert `TRZ_` marker on an AI drop-off zone, which is never smoked — where naming the marker after
the AI zone silently disabled it.

The startup report now carries `AIZ[i] ERROR '<name>': name already taken by zone '<holder>' —
entry ignored`, matching the four `entry ignored` messages `_validateZoneNames` already emits. It
is reported at the skip site rather than in `_validateZoneNames`, which runs *before* discovery and
would have to predict what discovery is going to claim — and would be wrong about `WPZ_`, which is
discovered after the AI zones and loses the race rather than winning it.

Documented where zones are named, not only in a migration note: the zone pages now state that
`TRZ_`, `WPZ_`, AI zones and the legacy `troopZones` share **one** name space, that a `TRZ_` zone
occupies its parsed name, and that the registration order is `TRZ_` → AI → `WPZ_` → legacy.

### Fixed — `validate` accepts the modded types `modTypes` exists to declare (FIX-VALIDATE-MODTYPES)

The `modTypes` setting has one job, and the schema states it: listing a type there "is what stops
validation rejecting it as unknown to DCS". `ctld-tools validate` did not honour it — crate units
were compared against the datamine alone, so **a modded crate was an ERROR that blocked export**,
precisely what declaring it was supposed to prevent. The Lua type lint had it right all along,
excusing the same declaration, so the two layers disagreed and the blocking one was wrong.

The known-type set is now resolved **once**, in `validate()`, as the datamine union the catalogue's
`modTypes`, and handed to every type-aware rule — instead of each rule deciding for itself, which is
how the inconsistency arose (`FEAT-VMCT-INTEGRATION` added a correct local union for its new type
lists rather than widen the bug, and said so at the time).

Recorded while fixing: the tool stays knowingly narrower than the Lua lint, which also excuses each
scene's `modTypes`. A scene's crates are injected at runtime and never appear in a config, so the
gap is theoretical — the assumption is written in the module docstring, where it will be found if it
ever stops holding.

### Added — capability entries for the Gazelles and the Yak-52 (FEAT-AIRCRAFT-CAPABILITIES)

`capabilitiesByType` held nine aircraft. Five **stock DCS modules** were absent — `SA342L`,
`SA342M`, `SA342Minigun`, `SA342Mistral`, `Yak-52` — so their pilots got no crates, no troops, no
beacons and no smoke. They now carry what v1 declared for them: **one soldier, no crates**, and
nothing else (no slingload, no whole vehicle, no parachute drop, no native DCS cargo).

With a one-soldier limit the embark menu offers exactly one stock template, `Single JTAC`, because
it filters templates on `total <= maxTroopsOnboard`. That is the light-scout insertion these
airframes actually fly; a mission wanting more can raise the limit or add a smaller template.

**The `Ka-50` is deliberately left out**, and this is a departure from v1 worth stating. v1 let it
sling crates and carry `numberOfTroops` soldiers — not by decision but by absence: it had no entry
in v1's tables either, and `getUnitActions` / `getTransportLimit` fell through to their defaults. An
entry with every transport field `false` would add exactly one capability, dropping a radio beacon,
while advertising a transport that is not one; recon and JTAC status already work with no entry at
all. The migration guide records the reasoning, and a mission that wants it can add the entry.

Documentation correction, both languages: the configuration page claimed that **only** listed
aircraft receive CTLD F10 menus. They do get a menu — the root, `Check Cargo`, `RECON` and JTAC
status are ungated; what an unlisted aircraft loses is the transport half. "The menu is there but
empty" is now a documented symptom with a named cause.

### Fixed — a v1 config's `dropOffZones` no longer disappears in silence (FIX-DROPOFFZONES-PARITY)

`dropOffZones` is a v1 setting the legacy monolith really reads: an AI transport carrying troops or
a vehicle auto-unloaded when it landed inside one, and the zone was smoked on the periodic refresh.
**Nothing in `src/` reads it.** A mission migrating from v1 therefore lost that behaviour with no
error, no warning and no log line — its AI transports simply stopped unloading.

Nothing else caught it either: `validate` checks unit types, crate weights, mixedSets and schema
choices, never unknown keys, and a hand-written mission config never passes through `ctld-tools` at
all. So the fix is the missing signal, not a second implementation:

- **One startup NOTICE**, on screen, naming the replacement — an `aiZones` entry with
  `isDropoff: true`. One message for the key, not one per zone.
- **The v1 → v2 migration guide gains a `dropOffZones` section** (EN + FR), which had zero mentions
  of it: what it did, what replaces it, and a before-and-after example. A `ctld-tools` test reads
  that example out of the guide and validates it, so the documentation cannot drift from the engine.

The setting is **not** reimplemented: `aiZones` supersedes it — and is richer, since a drop-off
unloads troops, virtual vehicles and physical vehicles, with `aiDropMode` choosing ground,
parachute or either. A second spelling for one concept is what the last four lots removed.

**The v1 smoke colour has no equivalent, and that is now a recorded decision.** An AI zone is never
marked: `_loadAIZonesFromConfig` passes no `smoke`, the schema has no such field, and the global
`troopZoneSmokeColor` is read only by `_discoverTRZ`. Rather than add a field to `aiZones`, the
guide documents the workaround — a superimposed inert `TRZ_` zone, smoked in the coalition colour —
together with its trap: give the marker a **different** logical name, because an `aiZones` entry
whose `dcsZoneName` matches an already-discovered troop zone is skipped, which would silently
disable the AI zone.

### Tooling — the unit suite runs locally without busted

`tools/lua-test/` replays all of `tests/ci/unit/` with a plain **Lua 5.1** interpreter — the
version DCS runs — in about a second, for developers who cannot install `busted` (luarocks needs
Lua ≤ 5.4, which a Windows box often cannot provide). `run_specs.ps1` finds the interpreter,
accepts a name filter, and refuses anything newer than 5.1 rather than reporting failures DCS
would never see.

It is a pre-commit check, not a second gate: it implements only the busted subset the specs use,
so a spec reaching for `spy` / `mock` / `stub` fails there and passes in CI. A bundled minimal
JSON decoder stands in for the `dkjson` rock so `config_spec` runs too — that is the spec
comparing `parseYAML` to the committed defaults oracle, i.e. the one that catches a setting added
to `CTLD_config.yaml` without regenerating `tests/ci/data/config_defaults.json`. Skipping it
locally would hide exactly the failure it exists to catch.

### Added — a beacon can be created by a caller that is not a pilot (FEAT-VMCT-INTEGRATION ticket 03)

New public API **`CTLDBeaconManager:createAtPoint(point, coalitionId, countryId, opts)`** and
**`:removeBeacon(name)`**. Until now every way into the beacon subsystem went through
`dropBeacon(transport, player, …)`, which reads the coalition and the country off the transport
and publishes an event carrying a `player` — so a script building a FARP or a FOB could not place
a beacon at all, even though `dropBeacon` already accepted an `overridePosition` and an `isFOB`.

`createAtPoint` returns the `CTLDBeacon`, whose `vhf` / `uhf` / `fm` fields are the caller's answer
(`beacon:freqText()` formats them). `opts` carries `name`, `batteryMinutes` (`-1` = never expires)
and `isFOB`.

- **`dropBeacon` and `createAtZone` now delegate to it**, so spawn, frequency assignment, battery
  and map layers exist once instead of three times. Their pilot-facing behaviour is unchanged —
  same offset behind a grounded aircraft, same coalition message, same `OnBeaconDropped`.
- **`createAtPoint` is silent**: no coalition message and no `OnBeaconDropped`, whose payload's
  `player` field would be meaningless. A dedicated `OnBeaconCreated` is not added until something
  needs it.
- **`enabledRadioBeaconDrop` does not gate it** — that setting governs the pilot's F10 action, and
  a beacon placed by a mission's own logic is not a player drop. The refresh loop, which `init()`
  only starts when that setting is on, is now started on demand so a scripted beacon still
  transmits and still expires on its battery.
- Side effect of the shared engine: `createAtZone(..., batteryLife = -1, ...)` now means "never
  expires" instead of producing a beacon whose battery was already flat.

### Fixed — a troop pickup zone backed by a ship no longer stays behind (FIX-SHIP-ZONE-ANCHOR-PARITY)

A `troopZones` entry whose name matches no trigger zone falls back to a unit lookup — the
documented way to make a carrier a pickup point. CTLD 2 snapshotted the ship's position at init,
so the carrier steamed away and its pickup point stayed in the water, silently.

This was an **undeclared parity deviation**, not a design choice: v1 (`ctld.inPickupZone`)
re-resolves the position on **every** check — `trigger.misc.getZone(name)` first, and when that
misses, `getTransportUnit(name):getPoint()`. `FEAT-MOVING-ZONE` established the same principle for
CTLD 2 (a zone resolves its position lazily) and unified `getCenter()` across zone types; this path
was missed. Nothing for a mission maker to change — the old behaviour was the bug.

- `CTLDTroopZone:getCenter()` gains the `linkedUnit` branch it lacked, in `CTLDLogisticZone`'s
  order: linked unit → trigger zone → stored centre. `isDynamic()` / `isAlive()` follow.
- `_loadLegacyZones` passes the resolved ship as `linkedUnit` instead of freezing its point. The
  captured point survives as the last-known position, so a sunk carrier leaves the zone where it
  went down rather than erroring.
- The radius of a ship-backed zone is **200 m**, v1's hardcoded value, replacing
  `maximumDistancePackableUnitsSearch` — a second, separate deviation. Fixing the anchor while
  keeping a different radius would only have traded one for the other.

### Added — troop pickup points on ships, declared by type (FEAT-VMCT-INTEGRATION ticket 02)

New setting **`troopZoneShipTypes`**, the sibling of `logisticUnitTypes` for the troop side: a
list of DCS type names, empty by default. Every mission ship of a listed type becomes a troop
pickup point with unlimited stock, anchored to the vessel — no unit name anywhere.

It reuses the anchoring restored by `FIX-SHIP-ZONE-ANCHOR-PARITY` and that fix's 200 m radius
rather than introducing a second mechanism, so a discovered zone and a `troopZones` entry naming
the same ship behave identically. An explicitly configured zone of the same name always wins;
discovered zones carry no smoke and no stock limit, which is what naming the ship in `troopZones`
is for. Type names are checked in the same two places as ticket 01 — the offline `CTLDTypeCollector`
lint and the blocking `ctld-tools validate`.

### Added — a logistic point can be declared by unit type (FEAT-VMCT-INTEGRATION ticket 01)

New setting **`logisticUnitTypes`**: a list of DCS type names. Every mission unit **and static**
whose type is listed becomes a logistic zone anchored to that object, so a carrier keeps its
logistic point as it steams. Empty by default — an existing config behaves exactly as before.

Until now the only way to say "every carrier is a logistic point" was to name each unit in
`logisticUnits`, a per-mission list that cannot be shared, cannot survive a copy-paste, and
silently misses any unit added later. The two settings differ on purpose: `logisticUnits` names
objects and WARNs when one is missing; `logisticUnitTypes` is a catalogue of types and stays
silent for a type the mission does not hold.

A name that matches no DCS type would produce no error at all in game — just a zone that never
appears — so `ctld-tools validate` now rejects it (`modTypes` still declares a modded type), and
`CTLDTypeCollector` reports it in the offline type lint.

Documentation note: the developer zone reference stated the `logisticUnits` radius default as
500 m; `maximumDistanceLogistic` is **200 m**. Corrected in both languages.

### Docs — the configuration documentation describes the complete-snapshot model (release 2.0.0-rc2)

The whole published configuration surface still taught two APIs deleted by
`FEAT-CONFIG-YAML-COMPLETE`: the `ctld.yamlConfigDatas` scalar block and the `ctld.userSetup`
callbacks (`addCrate` / `removeCrate` / `patchCrate` / `addTroopGroup` / `addTo` / `logDefaults`).
Every snippet is rewritten as the YAML it really is, in the section it really lives in
(`mm_facing` / `advanced`), with `ctld-tools` presented as the primary path. Audited by diffing every
`| `key` | `value` |` row in `docs/` against `src/CTLD_config.yaml`, and every documented symbol
against `src/`; the following were **wrong**, not merely dated:

- **`transportPilotNames` was shown as a dictionary** (`["heliai_supply"] = true`) in the AI-transport
  setup, while `CTLD_player.lua:316` walks it with `ipairs`. A Mission Maker copying that shape had
  every AI transport silently ignored — the same failure mode `modTypes` had in `FIX-CATALOGUE-TRUTH`.
- **`injectAACrates` was still documented as a live API** in `api-reference`, `subsystems/aa` and
  `subsystems/crates`, including a four-step description of an injection that no longer happens. The
  AA crates are ordinary catalogue entries in `CTLD_config.yaml`; `TEMPLATES` (the assembly rules)
  is what survived, and it is now declared in `CTLD_aasystem.lua`, not "populated from
  `CTLD_config.lua` at config load".
- **`specificParams` on a crate was documented as live orbit tuning** passed to `startLase` — it is
  ignored and produces a startup NOTICE.
- **The legacy zone section named settings that do not exist.** `ctld.pickupZones` /
  `ctld.dropOffZones` / `ctld.wpZones` / `ctld.logisticUnits` were presented as `ctld.*` globals; the
  globals were removed and the engine reads the *settings* `troopZones` / `wpZones` / `logisticUnits`.
  **`dropOffZones` has no equivalent at all in CTLD 2** — it exists in the legacy monolith and is
  read there, so a v1 config carrying it loses its AI drop-off points. Now stated explicitly, with
  `aiZones` + `isDropoff` as the replacement.
- **`i18n_lang` was still documented as "edit the top of `src/CTLD_i18n.lua`"**, four months after it
  became a real setting.
- **`maxSlingloadSpeed` was still documented as `50`** in the crate catalogue (both languages), the
  value corrected to `26` in this same `[Unreleased]` cycle. The unit is now spelled out with its
  km/h and kt equivalents.
- **`desc` was documented as needing a `ctld.tr(...)` wrapper** — in YAML it is plain text, and
  `CTLDConfig.localiseI18n` translates every `desc`/`name` at load.
- **The load order was presented backwards** on `docs/index` and `mission-maker/index` ("add
  `CTLD.lua`, then add a *second* trigger with your `CTLD_userConfig.lua`"), when the config trigger
  must come **first**. Both now start from "CTLD runs on its defaults" and route to `ctld-tools`.
- **`architecture.fr` and `building-and-testing.fr` claimed `CTLD_userConfig.lua` is merged last**
  into `CTLD.lua`. It is not in `listToMerge.txt` at all — it ships as a separate file. The EN pages
  correctly said `CTLD_bootstrap.lua`; the FR pages had drifted.
- `AIZones` (the dead capitalised spelling) removed from the two "where the rest is configured"
  tables; the `aiZones` editor and the string-vs-numeric `coalition` trap are documented.
- `mission-maker/index` gained the missing link to the `ctld-tools` page.

Follow-up after rc2 was tagged: the **download link on both home pages was broken twice over**. It
pointed at `../../releases/latest`, a GitHub-relative path that only resolves when the markdown is
read on github.com — from the published site (`site_url: https://veaf.github.io/CTLD/`) it escapes the
repo entirely, which is what mkdocs' "unrecognized relative link" INFO was reporting. And
`/releases/latest` excludes pre-releases, so with `2.0.0-rc1` and `2.0.0-rc2` the only releases in the
repo, the GitHub form 404s as well. Now an absolute link to the releases **index**, which lists
pre-releases and therefore works before 2.0.0 stable exists.

Also in `src/`, comment-only: the `ctld.yamlConfigDatas` reference in `CTLD_config.lua`'s example
block, and the `CTLD_userConfig.lua` template header, which stated the ticket-04 rule ("an element you
omit is absent at runtime") that Addendum 1 superseded — a scalar now resolves to its default.

### Removed — runtime

- **`CTLDCrateManager:dropCrate` and its `maxDropHeight` setting.** Unreachable: no F10 menu entry ever
  called it, it is absent from `legacy_api.lua`, and neither the method nor the setting exists in the
  legacy monolith — it was introduced during the modernisation and never wired. The airborne drop it
  implemented is served by `parachuteCrates`, which the flight-state-aware menu does offer, with a
  configured descent rate, an intact landing and auto-unpack. **Side effect worth knowing:**
  `OnCrateDestroyed` was published only by `dropCrate`, so that event is **no longer emitted at all**.
  Its documentation section says so explicitly rather than disappearing, because a plugin may subscribe
  to it and its author needs to know the handler will not fire.

### Changed — runtime

- **Drone JTAC orbit geometry is now four settings instead of a per-crate block.** `specificParams`
  is removed from the crate schema, the catalogue and the engine; orbit altitude, both radii and speed
  come from `JTAC_droneAltitude`, the new `JTAC_droneRadiusNoLase` / `JTAC_droneRadiusOnLase` /
  `JTAC_droneSpeed`, and the single `JTAC_droneRadius` is retired — one key could not express both the
  searching radius and the tighter lasing radius, and that distinction is deliberate.
  **Every default was rebased onto the value the two shipped drones actually used** (3000 m, 2000 m,
  1000 m, 150 km/h), so the orbit itself is unchanged.
  **Two in-flight changes, both of them alignments:** a drone now *spawns* at 3000 m instead of 4000 m,
  and at 150 km/h instead of a hardcoded 54 m/s (≈194 km/h). Before, it was born high and fast and then
  changed altitude and speed a couple of seconds later when the orbit route was applied; now it flies at
  one height and one speed throughout. A config still carrying `specificParams` on a crate produces a
  startup **NOTICE** naming the crates and the settings that replace it — neither `validate` nor
  `version-gap` can see a field nested inside a crate entry, so the runtime report is the only signal.
  **Not touched:** `specificParams.task` on `loadableGroups` templates. That is Feature I's post-spawn
  troop routing, a different feature that happens to share the field name.
- **A setting now has exactly one default, in `src/CTLD_config.yaml`.** 114 fallbacks were deleted —
  103 `ctld.gs("x") or <literal>` plus 11 that duplicated a code constant (`_ROLE_EQUIP_WEIGHTS`,
  `trigger.smokeColor.Red`). With a missing parameter now resolving from the catalogue (see *Fixed*
  below), each was a second default free to drift from the one it duplicates — and five had already
  drifted: `maximumSearchDistance` (code `10000` vs catalogue `3000`, two sites),
  `maximumDistanceLogistic` (`500` vs `200`), and, not previously reported,
  `parachuteMinAltitudeCrates` / `…Troops` / `…Vehicles` (`30` / `50` / `30` in code vs `152` for all
  three in the catalogue). **No in-game behaviour changes**: a catalogue is always loaded, so the
  catalogue value always won and is what missions have been running on. The 46 `or {…}` guards on lists
  are deliberately untouched — for a list, absent still means empty. A test fails if a scalar literal
  fallback reappears.
- **`maxSlingloadSpeed` default corrected from `50` to `26`.** The value is in **metres per second**:
  the engine compares it to the magnitude of `Unit:getVelocity()` (`CTLD_crate.lua:1100`), with no
  conversion anywhere in `src/`. So `50` meant ~180 km/h / 97 kt — nearly double a UH-1H's sling-load
  limit — and reads like a value entered as knots. `26` m/s is ~50 kt / 94 km/h. **This changes
  in-flight behaviour**: a crate is now cut loose at a lower speed than before. Raise the setting per
  mission if your airframe warrants it; the unit is now spelled out in the setting's description.
  The Lua fallback (`ctld.gs(...) or 50`) was corrected in the same move — leaving it would have left
  two different defaults depending on whether a config was loaded — and a test now pins the two
  together.
### Fixed

- **The schema and catalogue now describe what the engine actually reads.** Four blocks were teaching
  Mission Makers something false, and one of them is why the AI-zones editor showed a raw JSON box:
    - `tableFields.AIZones` described a **dead positional format** (`zoneName` / `mode` / `side`) that
      the engine has never read, in `src/` or in the legacy monolith. PR #69 dropped the dead config
      *key* but left the schema block. Rewritten as `tableFields.aiZones` with the ten fields
      `_loadAIZonesFromConfig` really reads, and the three enums declared as machine-readable
      `choices` — `RED/BLUE/NEUTRAL`, `T/V/TV`, `G/P/GP` — seeded from the engine's own `VALID_*`
      tables. The `coalition` description now spells out that it is a **word, not a number**: every
      other coalition field in the catalogue is the numeric `side`, and an editor reusing that widget
      would silently write a value the engine reads as "both coalitions".
    - `spawnAs` advertised **`GROUND_UNIT`**, a value in no lookup table — it worked only by falling
      through `_SPAWN_CATEGORY_MAP`'s error path to `GROUND`. Replaced by `choices: [GROUND, AIR]`, with
      the description stating that DCS can only build ground units, statics, helicopters and drones from
      a raw definition.
    - `modTypes` shipped as `{}` — a **map** — while the engine walks it with `ipairs`. Harmless while
      empty, but a Mission Maker copying that shape had every entry silently ignored, and then saw their
      modded units rejected as unknown to DCS with no way to see why. Now `[]`, with a description that
      explains what the setting is for.
    - `spawnableCratesModels[*].category` never reached DCS: `_spawnStatic` does not copy it, and
      `dynAddStatic` forces `category = 'Cargos'` regardless. Removed from all three models. Parity
      holds — the legacy monolith forced the same value at the same point.
  A new `test_catalogue_truth.py` asserts each of these against the Lua that consumes it, so the
  documentation cannot drift from the runtime again.
- **`minimumHoverHeight` / `maximumHoverHeight` now state their reference frame.** Picking up a crate or
  a vehicle measures height **above the object**; releasing a slingload measures it **above the terrain**,
  because there is no object to measure from. That is deliberate, and the two never apply at the same
  moment — pickup versus release — so this is a wording fix, not a behaviour change.
- **An incomplete mission config no longer crashes the mission.** Three settings were read with no
  fallback and fed straight into arithmetic: `JTAC_searchIntervalSeconds` / `JTAC_laseIntervalSeconds`
  into `t + interval` (`CTLD_jtac.lua:905`), and `slingCutDestroyHeight` into `agl > …`
  (`CTLD_crate.lua:1503`). A config missing any of them errored on every JTAC tick, or on every
  slingload release. This is reachable in practice — a config authored against an older catalogue, or
  simply hand-edited, since the YAML is deliberately editable without the tool.
  [ADR 0011](dev/adr/0011-complete-yaml-config-and-webapp-tooling.md) now distinguishes the two config
  tiers (Addendum 1): a **parameter** (its default value is a scalar) always resolves — absent from the
  mission snapshot it falls back to the CTLD default, and every such key is named once on screen in the
  startup report, because a hand-written config never passes through `ctld-tools validate`. A **list**
  keeps the original semantic: omitting it, or one of its elements, is an intentional removal. Nothing
  is merged — a list is never combined with the default, and a mission running on the shipped defaults
  parses nothing extra.
- **A troop-group editor that corrupted the file it edited.** `jtac` was typed as a boolean in the web
  app while the catalogue ships counts (`jtac: 1`, `jtac: 2`): it rendered as a checkbox that no
  numeric value could tick — so "JTAC Group" and "JTAC Group 2" looked identical and "Single JTAC"
  looked empty — and toggling it wrote `true`/`false` over the count in the Mission Maker's YAML. Now
  typed as a number, with tests on both sides pinning every troop-group field as a count.
- **Eleven French setting descriptions were double-encoded** in `src/CTLD_config_schema.yaml`
  (`rÃ©fÃ©rence` for `référence`) — UTF-8 bytes written out as cp1252. Introduced in `5e4dc50`
  (PR #66) and only visible once the FR UI shipped. Repaired, and `tests/test_encoding.py` now fails
  the build on any such sequence in the authored YAML and locale files, including a test that the
  detector itself still fires.
- **`AIZones` was a dead catalogue key.** Nothing in `src/` reads it — the engine reads `aiZones`
  (lowercase), whose entries are named records, not positional arrays — and the legacy monolith has
  neither spelling. It shipped four default AI zones with no effect in game, and the web app gave them
  a dedicated editor, which made them look configured. Key, schema entry and positional field schema
  removed; the parity oracle and `CTLD.lua` regenerated. `aiZones` now defaults to `[]` (the engine
  iterates it) and its record format is documented in the schema.
- **`logisticUnits` moved from Crates to Zones.** A logistic unit *is* a zone — a mobile one, centred
  on a vehicle rather than drawn in the Mission Editor. Classifying it by use rather than by nature
  would equally justify filing `troopZones` under Troops, emptying the Zones family.
- **`nbLimitSpawnedTroops` and `beaconIconColor` are no longer raw JSON.** Both are short positional
  arrays whose meaning is the index: named fields now (RED / BLUE coalition limits; DCS RGBA with a
  colour preview), with the format documented in the schema. Array length is preserved — the engine
  indexes these by position.

### Tooling — every complex config key gets a real editor (FEAT-EDITOR-COVERAGE)

- **`aiZones` has an editor.** It used to fall through to a raw JSON box, because its entries are
  *named records* and the positional zone editor would have corrupted them. The new editor respects the
  two traps the data carries: **`coalition` is a string** here (`RED` / `BLUE` / `NEUTRAL`) where every
  other coalition field in the catalogue is the numeric `side` — writing a number would be read by the
  engine as "any coalition", silently — and the **stock tables carry two magic values**, the key `All`
  and the count `-1`, now offered as a placeholder and a checkbox rather than left as lore.
- **`spawnableCratesModels` has an editor**: three fixed rows, one per transport mode, with no add or
  remove control because no row can be added or removed. Clearing the optional shape name omits the key
  instead of writing an empty string, which would have changed the DCS static definition.
- **`isJTAC` and a strict `spawnAs` dropdown on every crate.** The engine has always lased any crate
  flagged `isJTAC`, ground or air — only the editor was short. The two ship together because they
  determine each other. The dropdown offers `GROUND` and `AIR` only; **`AIR` is an authoring convenience**
  the tool resolves to `AIRPLANE` or `HELICOPTER` from the unit's datamine category, so the YAML keeps
  carrying what the engine expects and a Mission Maker never has to know which of the two an airframe is.
- **`modTypes` is editable as a list** of DCS type names, with the datamine autocomplete.
- **Every closed value set now comes from the schema, never from a component.** `/api/schema` widened so
  a table field carries its `choices` alongside its help text — a value list living only in the frontend
  would help users of the app and nobody editing the YAML by hand.
- The vendored datamine bundle now maps each type to its category, which is what makes the `AIR`
  resolution possible. The category was already in the datamine's directory layout and was being
  discarded.

### Tooling — config completeness is checked before export (FEAT-CONFIG-PARAM-SEMANTICS)

- **`validate` now refuses an incomplete config.** A setting the config omits is reported as an
  `ERROR`, which blocks export to the `.miz` — a setting cannot be removed by omission, because the
  engine needs a value (ADR 0011 Addendum 1). Omitting a **list**, or one of its elements, stays a
  legitimate removal and is not reported. The rule is keyed off the **default catalogue**, never the
  schema: `i18n_lang` is schema-declared but deliberately absent from the catalogue, so a
  schema-driven rule would fail every valid config.
- `validate` gains `--default` (the reference catalogue); it falls back to the bundled one, so
  `ctld-tools validate --yaml mine.yaml` checks completeness with no extra ceremony. The web app
  passes the loaded default automatically, on both `/api/validate` and the `/api/inject` guard.
- This is the design-time half of the pair. The runtime half is the on-screen startup notice, and it
  exists because nothing obliges a Mission Maker to run the tool at all — a hand-written YAML never
  reaches `validate`.

### Tooling — ctld-tools Mission-Maker UX pass (CTLD-TOOLS-MM-UX)

UI/UX rework of the `ctld-tools.exe` web app for a **non-technical Mission Maker**, plus a visual
identity rooted in the subject (DCS rotary-wing logistics). Confined to `tools/` and to the authoring
metadata in `src/CTLD_config_schema.yaml`, which the build does not read — so no `CTLD.lua` rebuild and
no runtime behaviour change.

- **One navigation by functional family** replaces the `Parameters` / `Data` split. That split
  followed the *shape* of a value rather than its subject, filing `enableCrates` under one screen and
  `spawnableCrates` under another; a family now owns its settings **and** its tables. Two new
  families (`Aircraft`, `Zones`), explicit domain ordering, per-family icons.
- **Settings placed by name when the schema is silent** — a prefix/substring fallback
  (`familyOf`) shrinks the catch-all `Other` family from ~44 settings to 7. Schema `group:` always
  wins; the fallback reads the key's spelling only and invents nothing.
- **Human labels** (`humanize`) instead of raw config keys, with the raw key kept alongside in small
  type since that is what the docs and forums name. **Units** (m / kg / s) are extracted from the
  existing schema descriptions — never guessed from a key name. Readable column headings for the
  crate / troop / aircraft / zone tables.
- **Boots onto the CTLD defaults** instead of an empty "load something to begin" screen.
- **Guided workflow** — a Load → Adjust → Inject step strip, `Inject into mission…` promoted to the
  single primary action, intent-based button wording, an explicit **save-state** indicator
  (`No changes` / `Unsaved changes` / `Saved`) and an unsaved-changes guard on open / reset.
- **Reset to default + changed markers**, backed by a new additive `GET /api/defaults`: a changed
  setting is marked, counted per family and in the header, and restorable in one click.
- **Search across all settings** (label, key, description, ranked) — including behind the Advanced
  disclosure, which is now collapsed by default and opens by itself when it holds a change or when a
  family has no common settings.
- **Plain-language validation panel**, always visible, naming settings by their human label, with a
  header status lamp; clicking a finding jumps to the setting. `Inject` is disabled while errors
  remain. The version-gap dialog is rewritten as counted, expandable summaries that state plainly
  that nothing was merged.
- **Cockpit/kneeboard theme** — design tokens in `web/src/lib/theme.css` (dark instrument ground,
  olive-biased neutrals, caution-amber accent, NATO side colours for RED/BLUE, display/mono type
  split), shared control styling, real page title and favicon (was Vite's default), responsive down
  to ~1000px, visible focus, `prefers-reduced-motion` honoured.
- **Units are traced from the engine, not guessed.** `unit:` on 66 numeric settings in
  `src/CTLD_config_schema.yaml`, each one established by reading the Lua that consumes the value —
  `maxSlingloadSpeed` is **m/s** (compared to the magnitude of `Unit:getVelocity()`, no conversion
  anywhere in `src/`), `deployedBeaconBattery` is **minutes** (the engine applies `* 60` at four
  sites), `hoverTime` is **seconds** (counted down on a 1s tick), and so on. Previously the unit was
  scraped out of the description text, which covered 40 of the 80 numeric settings and nothing for
  those without a description. The remaining 14 provably have no unit (counters, colour and laser
  codes, 0–1 fractions, a multiplier, a DCS font size) and stay bare. Units are not translated.
  Two fixes fell out of the investigation: `spawnDistanceInCircle` was mislabelled as a *spacing*
  when the code uses it as a **radius**, and `maxTransportWeight` gained a description because `0`
  (which disables the check entirely) was unreadable. The runtime anomalies the sweep turned up —
  including a `maxSlingloadSpeed` default of 50 m/s ≈ 180 km/h, two Lua fallbacks that disagree with
  the YAML catalogue, and three settings that would raise on a missing key — are recorded on
  `dev/roadmap.md` rather than changed here.
- **Setting names are authored and bilingual.** `label: { en, fr }` on all 137 catalogue keys in
  `src/CTLD_config_schema.yaml` (41 keys had no schema entry and got one), exposed per-language by
  `/api/schema` and preferred over the key-derived name everywhere a setting is named — rows, search,
  validation findings, version-gap and data-table titles. Search therefore matches the *translated*
  name. Beyond translation this fixes several English names the derivation got wrong
  (`enableAllCrates` → "Show the \"All crates\" shortcuts", per its own description) and brings the
  project's **"no repack"** convention into the UI (`enableFARPRepack` → "Allow packing a FARP back
  into crates"), with a test asserting no label in either language says "repack".
- **In-app help**, from a `Help` button in the header — and generated from the schema and the open
  catalogue rather than written as prose: setting and family counts, the family list carrying the
  schema's own descriptions, and an inventory of every mission-data table with its real size. Adding a
  family or a table updates the help with no text to maintain. The hand-written part covers what data
  cannot say (the three steps, reading a setting row, validation, saving vs injecting, and the
  complete-snapshot rule). EN+FR like the rest, 28 new keys. Counts only render once a catalogue is
  loaded — the button is reachable from the first paint, and "0 settings across 0 families" would have
  been a lie rather than a loading state.
- **French UI.** The web app is now bilingual, reusing the backend i18n layer that already served the
  CLI's validation messages: 90 `web.*` keys in `ctld_tools/data/locales/{en,fr}.json`, a new
  `GET /api/i18n`, and `GET /api/schema?lang=` so that switching language also translates **setting
  descriptions, table headings and family labels** — not just the chrome. A header picker overrides
  the OS locale and is remembered in `localStorage`. A parity test reads the catalogs from disk and
  fails the build if EN/FR key sets, texts, placeholders or plural pairs drift apart. Known limit:
  setting *names* were still English at this point — closed by the `label:` work above.
- **Families are named and described in the schema** (`src/CTLD_config_schema.yaml`, new reserved
  `families:` section: bilingual `label` + `description`, plus `order` for the navigation). The
  labels were **recovered from the retired TUI's `tui.family.*` catalogs** (commit `3205ef6`) rather
  than re-invented — they had existed in EN+FR all along. Descriptions are new, written from the
  settings and tables each family actually holds. `Schema` gains `family_label/description/order`,
  and `families` joins `tableFields` as a reserved section so it is never taken for a setting. The UI
  shows the description under the family title. This is the only `src/` change in the lot and it is
  authoring metadata — not read by the build, so `CTLD.lua` is unaffected.
- **A picture of the subject, behind the whole page**: a DCS frame of a Mi-8 putting troops on the
  ground, fixed behind the app with the setting rows, data cards, step strip and rail translucent over
  it (`--panel-glass`). Because the viewport is roughly 16:9, the entire frame shows — an earlier
  attempt banded it across the header, where a 15:1 strip could only ever reveal 11% of it. Photo
  brightness, opacity and card alpha were swept together against a contrast floor for every text
  colour that lands on the image (12.4:1 for body text on a card, 4.5:1 for muted text straight on the
  background); `--ink-faint` was lifted to `#7b8d96`, which the brighter backdrop had pushed to 2.5:1.
  Asset is 79 KB (1600×900 WebP), and a missing file degrades silently to the gradient.
- **The release smoke-check now boots the exe and pulls resources out of it** — the page, the
  background photo, the favicon, and the schema / i18n / defaults / DCS-types endpoints. The previous
  check only ran `--help`, so an exe with a missing or broken bundled web app would have shipped
  green; that is the part a Mission Maker actually double-clicks. Verified against a locally built
  exe: 21.2 MB, and every resource served.
- **CI gains a `frontend` job** (`npm run check` + `npm test` + `npm run build`). The web-app suite
  existed since `CTLD-TOOLS-WEBAPP` but no workflow ran it — `release.yml` only built the bundle, so
  a red test could ship. The exe embeds this frontend, so it now gates like the rest.
- Docs: `docs/mission-maker/ctld-tools.{md,fr.md}` updated to the new UI. Deferred follow-ups
  recorded on `dev/roadmap.md`: **UI i18n (FR)** — every string is centralised in
  `web/src/lib/strings.ts` to make it mechanical — and **enriching `CTLD_config_schema.yaml`** with
  the missing `group:` / `label:` / `unit:` metadata, which is the durable home for it.

### Tooling — ctld-tools v2 web app (CTLD-TOOLS-WEBAPP)

- Lot 3 (ticket 08): **docs rewrite** — `docs/mission-maker/ctld-tools.{md,fr.md}` rewritten for the
  web app (double-click the exe → browser; the Parameters/Data screens + families; live validate;
  `.miz` inject; version-gap popup; the complete-snapshot model). Stale TUI / `gen-user` /
  `user-config.yaml` diff-model references removed from the mission-maker docs.
- Lot 3 (ticket 07): **CI frontend build + exe packaging** — `release.yml` now builds the Svelte
  frontend with Node and packages a single **console** `ctld-tools.exe` (PyInstaller) that bundles
  the built assets, the default config YAML + schema, and the DCS type set — so a Mission Maker
  double-clicks it with no repo, no Node, no network. FastAPI **serves the bundled frontend at `/`**
  (the ticket-01 mount, populated here); resources resolve from the PyInstaller bundle
  (`sys._MEIPASS`) when frozen. `uvicorn` gets the app object (not an import string) for the frozen
  exe. Verified locally in single-server mode (FastAPI serving static + API); the exe build itself
  runs at CI.
- Lot 3 (ticket 06): **version-gap re-migration popup** — on opening a config whose `configVersion`
  differs from the current CTLD default, a modal surfaces the diffs (new / removed / differs-from-
  default) before re-injecting — never a silent merge (ADR 0011 point 5). Drives the lot-2
  `version_gap` API (`/api/version-gap`).
- Lot 3 (ticket 05): **`.miz` inject + native file dialogs** — Open… / Save… / Inject to .miz… now
  drive **native OS dialogs** via the local backend (`/api/dialog/{open,save,miz}`, tkinter). Inject
  exports the current catalogue as `ctld.configUser` (lot-2 `embed`) and injects it into the chosen
  `.miz` (lot-2 `miz.inject_userconfig`), **blocked when validation has errors**. Live validation was
  already wired in 04b.
- Lot 3 (ticket 04e): **zones + mission lists + vehicle weights + no-editing-gaps gate** — the Data
  screen is now fully editable. `troopZones`/`wpZones`/`AIZones` edit as **named fields** (positional
  arrays converted via the ported `_ZONE_FIELD_SCHEMAS`, exposed at `/api/schema` `zoneFields`);
  `transportPilotNames`/`extractableGroups`/`logisticUnits` as string lists; `groundVehicleWeights`
  as a name→weight map; and **any remaining structure via a generic JSON fallback** so no key is
  uneditable. A **blocking coverage gate** (`tests/test_schema_coverage.py`, evolved from FullGas's)
  fails the build if a structured field lacks an EN/FR description or a zone-editor field is
  undocumented.
- Lot 3 (ticket 04d): **aircraft capabilities editor** — the Data screen edits `capabilitiesByType`
  (type → capabilities): boolean flags, numeric maxima, and the `loadableVehiclesBLUE`/`RED` string
  lists; add a type via a **datamine-backed picker** (new `/api/dcs-types` endpoint, 1143 types),
  remove a type, `tableFields` tooltips. New reusable `StringListEditor`.
- Lot 3 (ticket 04c): **troop-groups editor** — the Data screen edits `loadableGroups` via a generic
  `RecordListEditor` (name + `inf`/`mg`/`at`/`aa`/`mortar` counts + `jtac`), add/remove, typed
  editors, `tableFields` tooltips, live validation.
- Lot 3 (ticket 04b): **crates editor** — the Data screen edits `spawnableCrates` (section → crate
  list): per-entry `desc` / `unit` / `weight` / `cratesRequired` / `side`, add/remove, with
  `tableFields` tooltips and **live validation** (unknown units, weight collisions, mixedSet dangling
  weights) surfaced as findings. The backend `/api/schema` now exposes `tableFields`; new
  `/api/validate` wiring in the UI. mixedSet entries are shown with their weights.
- Lot 3 (ticket 04a): **scalar editors + 12 families** — the Parameters screen is now editable.
  Schema-driven per-type editors (bool / enum / number / string) with a **generic fallback** so
  every key renders an editor (unit-tested totality gate); edits PUT through the backend into the
  lot-2 `Catalog`, schema `description` shown as help. Navigation by the **12 functional families**
  (FullGas taxonomy) with labels + a Standard/Advanced split. Families are FullGas's 12 **plus a
  Parachute family** (the lot-1 parachute-physics settings) — 13 in all, + an "Other" catch-all.
  Structured-data editors follow in tickets 04b–04e.
- Lot 3 (ticket 03): **frontend shell** — a Svelte + Vite + TypeScript app under
  `tools/ctld-tools/web/`: the top-level **Parameters** (how CTLD behaves) vs **Data** (what CTLD
  operates on) split, navigation by the schema **functional families**, and a read-only view of a
  loaded catalogue (load defaults / open / save wired to the backend). Values are read-only here —
  editors arrive in ticket 04. Vitest coverage (classification + family-nav rendering).
- Lot 3 (ticket 02): **double-click launcher** — `ctld_tools/web/launcher.py`. A bare invocation /
  double-click (no command) boots the web app (`uvicorn` on `127.0.0.1` + opens the browser; the
  console is the "close to quit" window); an explicit `embed`/`validate`/`gen` still runs headless.
  Double-click is detected by walking the parent process tree (explorer.exe vs a shell, VMCT pattern,
  `psutil`). New `serve` CLI command. No `--noconsole`.
- Lot 3 (ticket 01): **FastAPI backend skeleton** — a new `ctld_tools/web/` package with thin
  endpoints wrapping the lot-2 core (load / read / edit / save / `validate` / `version-gap` / schema),
  a single-user in-memory session, and no business logic (ADR 0011 point 7). Added `fastapi` +
  `uvicorn` deps (`httpx` dev, for the TestClient). No frontend yet.

### Tooling — ctld-tools v2 core (CTLD-TOOLS-CORE)

- Lot 2 (ticket 05): **retire the last Lua-facing Python + drop `lupa`**. Removed `genconfig`,
  `genreference`, `extract`, `reference` (+ `reference.json`), `luaconfig`, and their tests. The CLI
  is trimmed to `embed` / `validate` / `gen`: `embed` wraps a config YAML verbatim into a `ctld.<var>`
  Lua string module (`ctld_tools/embed.py`, one implementation reused by the build for `configDefault`
  and by the lot-3 MM export for `configUser`); `gen` emits the flat engine defaults as a JSON parity
  oracle (`ctld_tools/oracle.py`). **Build/CI rewired:** `merge_CTLD.ps1` embeds via `ctld-tools embed`
  (no more `gen-config` / `CTLD_config_defaults.lua`); the busted round-trip parity now compares
  `parseYAML` to the committed `tests/ci/data/config_defaults.json` (read via `dkjson`) instead of a
  generated Lua table; `generate_i18n_dicts.ps1` scans the YAML `desc`/`name` label values (which the
  vanished `config_defaults.lua` used to surface). `CTLD.lua` output is unchanged.
- Lot 2 (ticket 04): **version-gap detection** — `ctld_tools/versiongap.py` (`version_gap()`): a pure
  function that diffs an authored catalogue against the current default over the `Catalog` flat
  namespace and returns structured data (`added` / `removed` / `changed` defaults + from/to
  `configVersion`) for the lot-3 re-migration popup (ADR 0011 point 5). Equal versions → empty gap;
  `configVersion` itself is excluded from the diff. No runtime behaviour, no UI.
- Lot 2 (ticket 03): `validate` rewritten for the complete-catalogue model (no more ops/diff) —
  it checks a whole `Catalog`: known DCS unit types (datamine), globally-unique crate weights, AA
  **mixedSet consistency** (every "All crates" weight resolves to a crate in its section), and schema
  `choices` enums. New i18n keys (`validate.mixedset.dangling_weight`, `validate.setting.bad_choice`);
  the `validate` CLI command now takes a full config YAML (+ optional `--schema`).
- Lot 2 (ticket 02): the UI-agnostic **catalogue core** — `ctld_tools/catalog.py` (`Catalog`: load /
  get / set / add / remove / save the complete config YAML in full, round-trip via ruamel, over the
  `mm_facing`/`advanced` sections + top-level keys) and `ctld_tools/schema.py` (`Schema`: typed access
  to the authoring metadata — `group` / `standard` / `choices` / `description`). The expanded schema
  from the FullGas branch (`group` families + `standard` + bilingual descriptions) is recovered into
  `CTLD_config_schema.yaml`, merged with the lot-1 externalised knobs + `configVersion` (13 entries,
  `group` assigned by heuristic — reviewed with the UI in lot 3). 97/121 scalar settings covered; the
  rest fall back to a generic editor (lot 3). No Lua / no UI.
- Lot 2 (ticket 01): demolish the ops/diff + interactive surfaces retired by ADR 0011 — remove the
  Textual TUI (`ctld_tools/tui/*`), the ops editor (`editmodel.py`), the dead `gen-user`/`scaffold`
  generators, the `gen-user`/`tui` CLI commands, and their tests; drop the `textual` and
  `pytest-asyncio` dependencies. (`gen-config`/`lupa` stay until ticket 05.) Tool docs are rewritten
  with the web app (lot 3). Not a deliverable change — `CTLD.lua` untouched.

### Changed — engine config knobs externalised to YAML (FEAT-CONFIG-YAML-COMPLETE)

- Lot 1 (ticket 01): twelve hardcoded constants are now mission-configurable settings, read via
  `ctld.gs(...)` and defined in `CTLD_config.yaml` (+ schema descriptions) — **behaviour-preserving**
  (identical defaults). Part of the complete-YAML config pivot (ADR 0011):
  - MM-facing: `aaRearmDistance` (300), `aaAssemblyDistance` (500), `beaconRemovalRadius` (500),
    `loadCrateSearchRadius` (50), `unpackSearchRadius` (300), `fobCrateCollectionRadius` (750),
    `slingCutDestroyHeight` (40).
  - Advanced: `jtacLaserCodeMin` (1111), `jtacLaserCodeMax` (1688), `defaultVehicleWeight` (2500),
    `fieldExtractTroopWeight` (130), `defaultZoneRadius` (500).
  - The FOB "not enough crates" message is now parameterised with the actual radius (EN/FR/ES/KO).
- Lot 1 (ticket 02): `CTLDConfig.parseYAML` rewritten to parse the full nested catalogue — block
  sequences at the key's indent, sequences of maps, sequences of sequences (`- - x`), inline empty
  `{}`/`[]`, and quoted scalars — so the whole config can arrive as a YAML string at runtime. Guarded
  by a round-trip parity test (parse `CTLD_config.yaml`, merge sections, assert equality with the
  generated engine defaults). The unused `|` literal-block path was dropped. Behaviour-preserving.
- Lot 1 (ticket 03): the build (`merge_CTLD.ps1`) now embeds the canonical `CTLD_config.yaml`
  verbatim as the `ctld.configDefault` Lua string (generated module, merged after the i18n dicts,
  long-bracket level chosen dynamically). No behaviour change yet — the complete-config loader
  consumes this string in ticket 04.
- Lot 1 (ticket 06): the `ctld.userSetup` ops API is removed (clean break, pre-2.0.0) —
  `CTLD_userSetup.lua` and its helpers (`addCrate`/`removeCrate`/`patchCrate`/`addTroopGroup`/…)
  are deleted, along with the `ctld.initialize()` callback dispatch. The MM template
  `CTLD_userConfig.lua` is rewritten to the complete-config model: a single mission-start trigger
  sets `ctld.configUser` to a full YAML snapshot. The default YAML and schema now carry a top-level
  `configVersion` tag (`"2.0.0"`), merged into settings alongside the sections, so a `configUser` can
  record the version it was authored against (the tool consumes it for version-gap detection in a
  later lot). The v1 Legacy API (ADR 0004) is untouched.
- Lot 1 (ticket 05): the AA-system deployable crates are now ordinary catalogue entries in
  `CTLD_config.yaml` (sections `SAM mid range` / `SAM long range`) instead of being generated at
  runtime. `CTLDCrateAssemblyManager.injectAACrates` and its `ctld.initialize()` call site are removed;
  the crates were expanded once (golden-compared to the old injection output) and committed to the YAML.
  `CTLDCrateAssemblyManager.TEMPLATES` (the assembly rules the runtime still needs — parts, count,
  launcher) moves from `CTLDConfig:load()` to a static declaration in `CTLD_aasystem.lua`. Runtime
  assembly/spawn behaviour is unchanged.
- Lot 1 (ticket 04): `CTLDConfig:load()` switches to the complete-config model (ADR 0011) — it parses
  `ctld.configUser or ctld.configDefault` **whole** into settings, with **no merge** (an element
  omitted from a `configUser` snapshot is absent at runtime, not defaulted). A malformed `configUser`
  is a **hard error**. i18n labels (`desc`/`name`) are re-translated at load via `ctld.tr()`, matching
  the former generated defaults in every language. The legacy `ctld.yamlConfigDatas` scalar-merge path
  and the backward-compat `ctld.<setting>` globals are removed. `CTLD_config_defaults.lua` is no longer
  merged into `CTLD.lua` (still generated as the parity-test oracle + i18n scan source; `gen-config`
  itself is retired in lot 2).

### Fixed — hardcoded i18n strings in RECON menus and AA system (FIX-I18N-HARDCODED)

- **`CTLD_recon.lua`**: RECON submenu layer names (Infantry, Air Defense (AA), Ground Vehicles,
  Helicopters, Aircraft, Ships, FARP / FOB) now pass through `ctld.tr()` — previously always
  displayed in English regardless of the active language.
- **`CTLD_aasystem.lua`**: 6 player-facing `outText` messages replaced with `ctld.tr()` calls
  (deploy limit, AI/player deploy confirmation, rearm, repair limit, repair confirmation).
- **`CTLD_i18n_en.lua`**: 7 RECON layer name keys added to the EN dictionary.
- **`CTLD_i18n_fr.lua`**: FR translations for all 7 layer names and all 6 AA system messages.

### Added — i18n auto-translate + startup-report wiring (BUILD-DICT-AI-TRANSLATE)

- **`translate_i18n.py`** (`tools/build/`): fills empty i18n stubs via the Claude Haiku API
  (one batch call per language: FR, ES, KO). Runs automatically during `merge_CTLD.ps1` when
  `ANTHROPIC_API_KEY` is set locally; skipped silently in CI. Non-blocking: any API or Python
  error prints a WARNING and the build continues. Requires `pip install anthropic` once.
- **`ctld.initialize()`**: audits the active language dictionary after boot; adds an `INFO`
  entry to `ctld.startupReport` when untranslated stubs remain, so mission makers can see
  the count in `DCS.log`. No screen output (INFO severity).

### Added — i18n dict auto-sync in build + pre-push hook (BUILD-DICT-AUTOSYNC)

- **`merge_CTLD.ps1`**: calls `generate_i18n_dicts.ps1 -Apply` automatically after gen-config,
  before the merge loop. Missing keys are added as empty stubs; build continues regardless.
- **`.githooks/pre-push`**: cross-platform bash hook (detects `pwsh` then `powershell`,
  skips gracefully if neither available). Blocks push on MISSING keys; warns on STALE keys.
- **`CLAUDE.md`**: documents `git config core.hooksPath .githooks` for hook activation.

### Fixed — startup report INFO level (STARTUP-REPORT-INFO-LEVEL)

- **`ctld.startupReport`** : ajout du niveau `INFO` — log-only, aucun `outText` écran.
  `[OK]` n'est écrit que si le collecteur est totalement vide (toutes sévérités confondues).
- **INIT-E** (`CTLDCoreManager._initExtractableGroups`) : sévérité `NOTICE` → `INFO`.
  Les 25 noms fictifs `extract1`–`extract25` de la config par défaut ne génèrent plus
  aucun message à l'écran ; les entrées restent visibles dans `DCS.log` sous
  `CTLD_STARTUP_REPORT` pour un MM qui consulte le log.
- **ADR 0010** amendé : table des sévérités étendue à trois niveaux (ERROR / NOTICE / INFO).

### Fixed — i18n dictionary sync (FIX-I18N-DICT-SYNC)

- **`generate_i18n_dicts.ps1`**: fixed `$repoRoot` path (was one level too shallow — `tools/`
  instead of repo root — causing the script to scan `tools/src/` and silently report "0 keys").
  Now matches the `merge_CTLD.ps1` pattern: `Resolve-Path (Join-Path $scriptDir "..\..")`.
- **72 missing keys synced** to all four dictionaries (EN/FR/ES/KO). EN values filled from the
  key itself; ES/KO remain empty stubs per policy.
- **62 FR translations** filled in for all newly-synced keys, including all primary menu labels
  (`Troop Commands` → `Commandes de troupes`, `Crate Commands` → `Commandes de caisses`,
  `Vehicle Commands` → `Commandes de véhicules`, `Request Equipment` → `Demander de l'équipement`,
  `Smoke` → `Fumée`, etc.) and all pilot-facing messages. Dictionary versions bumped 1.8 → 1.9.

### Added — unified startup report (STARTUP-REPORT-UNIFIED)

- **`ctld.startupReport`** collector in `CTLD_utils`: `add(severity, source, message)` feeds
  init/config diagnostics from any manager; `flush()` called once at end of `ctld.initialize()`
  consolidates everything.
- **`DCS.log` banner**: `=== CTLD_STARTUP_REPORT ===` always written at startup — searchable,
  even on a clean config (`[OK] No issues detected.`).
- **Single `outText`** on screen when issues exist: NOTICE entries shown in full (player-facing
  too); ERROR entries produce a single alarm banner directing the MM to search
  `CTLD_STARTUP_REPORT` in `DCS.log`. Clean config = total silence.
- **Migration**: `CTLDCrateManager` (invalid mixedSet), `CTLDZoneManager` (zone validation),
  `ctld.addCrate` (duplicate weight), `ctld.runUserSetup` (callback failures),
  `CTLDCoreManager` INIT-E (missing extractableGroup) all routed through the collector.
  The 5-second `timer.scheduleFunction` delay on crate errors is eliminated.
- **ADR 0010**: two-family separation — Family 1 (init/config) via `ctld.startupReport`,
  Family 2 (runtime/dev) via `ctld.utils.log`. No bare `outText` in `src/` init code.
- **i18n**: alarm banner and INIT-E notice translated EN + FR (ES/KO stubs).

### Fixed — interface language is now a real setting (CTLD-TOOLS-TUI-POLISH)

- `i18n_lang` (the CTLD interface language, en/fr/es/ko) can now be set from the
  user-config. `ctld.tr` resolves the active language via `ctld.gs("i18n_lang")`
  (user-config wins), falling back to the module global `ctld.i18n_lang` (the legacy
  "edit CTLD_i18n.lua" method still works), then `"en"`. Previously it was a bare global
  read only by `tr`, so setting it from the user-config silently did nothing. It is
  surfaced in the ctld-tools TUI with a value list via the schema (`default: en`,
  `choices: [en, fr, es, ko]`) — deliberately **not** added to the engine defaults, so
  the legacy global keeps working.
- **Setting descriptions in the TUI**: `CTLD_config_schema.yaml` now carries a bilingual
  `description` per setting (seeded from the mission-maker config docs, 73 settings). The
  "Set setting" picker shows each setting's description in the current language and lets
  you **search by it** (filter matches name *and* description). The schema is embedded in
  the reference bundle; it is now the source of truth for these descriptions.
- **Double-click launches the TUI**: run with no command in an interactive terminal —
  including a double-click of `ctld-tools.exe` from Explorer — now opens the TUI directly
  (VMCT approach). Docs note the Windows **Unblock** step for a downloaded `.exe`.

### Tooling — ctld-tools: interactive TUI + embedded reference (CTLD-TOOLS-TUI)

- **`ctld-tools tui`**: a full-screen **textual** console for Mission Makers — a structured editor of
  the `user-config.yaml` (settings / crates / troops / arrays) with **filter-as-you-type pickers**
  (DCS types, catalogue crates/troops), **live validation**, and **save / generate / inject** in one
  place. Generation is refused while any validation error remains.
- **Actions**: three buttons — **Add / Remove / Patch** — each followed by a type chooser (only the
  valid object kinds), then a guided form. **Edit** a tree entry (`e`) reopens its form pre-filled to
  fix it in place; **delete** (with confirmation); **undo / redo** (Ctrl+Z / Ctrl+Y). **Patch** now
  works on troop groups too.
- **Settings help**: Set setting picks from the ~108 scalar settings via a filterable picker, showing
  and pre-filling each setting's default; an unknown setting is flagged (warning, with a suggestion).
  The embedded reference bundle now carries the scalar settings and their defaults. Boolean and
  fixed-value settings are chosen from a **list** (true/false, or an enum such as `JTAC_lock`); the
  allowed values come from a new authoring schema `src/CTLD_config_schema.yaml` (additive, not used
  by the build), folded into the embedded bundle.
- **Unsaved-changes guard**: quitting the TUI with unsaved edits asks for confirmation and shows how
  long ago the last save was.
- **Crate weight uniqueness on patch**: validation now also flags a `patch` that re-weights a crate
  onto an already-used weight (previously only `add` was checked); `gen-user` maps a patch's
  `weight_kg` to the runtime `weight` key, as `add` already did.
- **Fixed file names**: Save always writes the same `user-config.yaml` and Generate the canonical
  `CTLD_userConfig.lua` beside it (no path prompt); the TUI **auto-loads** `user-config.yaml` on
  start if it exists. Inject opens a **file browser** (DirectoryTree filtered to `.miz`) to pick the
  mission.
- **Internationalisation (EN + FR)**: the TUI and the validation messages follow the **OS language**;
  force it with `--lang` or `CTLD_LANG`. Tiny stdlib layer (flat JSON catalogs, `data/locales/`),
  modelled on VMCT.
- **Runtime**: new `ctld.patchTroopGroup(name, patch)` helper in `CTLD_userSetup.lua` (mirrors
  `patchCrate`), so a troop group can be patched by name from the `user-config`.
- **Embedded reference**: the catalogue is now bundled in the tool (`ctld_tools/data/reference.json`,
  generated from `src/` by the new `gen-reference` build step and committed, golden-tested for
  parity). `Reference.from_embedded()` is the default for `validate` / `gen-user` / `tui`, so the MM
  needs **only the `.exe`** — no CTLD `src/`. `--src` stays as a dev override.
- **lupa is now build-time-only** (moved to the `dev` group, imported lazily): the MM `.exe` ships
  without lupa or the native Lua binary. Only `gen-reference` / `gen-config` / `extract` use it.
- Edit logic (`EditModel`) and the picker filter are pure modules, unit-tested independently of the
  textual UI; a Pilot smoke test proves the UI↔model wiring. See [ADR 0009](dev/adr/0009-external-yaml-authoring-ctld-tools.md).
- Docs: `mission-maker/ctld-tools.md` (EN + FR) gains the interactive-editor section and the
  embedded-reference note (`--src` no longer required).

### Tooling — ctld-tools: automatic `.miz` injection (CTLD-TOOLS-MIZ-INJECT)

- **`ctld-tools inject`**: inserts a generated `CTLD_userConfig.lua` into a `.miz` as a **MISSION
  START trigger placed first** (runs before the CTLD trigger), **idempotently** (re-injection
  updates the same trigger, matched by comment). The mission `trig`/`trigrules` tables are patched
  in place — existing triggers are shifted and their in-code `[idx]` self-references rewritten (the
  VMCT mission-builder approach).
- Vendored `luadata` (parse/serialize the Lua `mission`, indices kept as dict keys) under
  `ctld_tools/vendor/` (excluded from lint/type/coverage). Tested end to end: injected mission
  reparses, is valid Lua, and re-injection stays single. **Final validation is a load in DCS.**
- Docs: `mission-maker/ctld-tools.md` (EN + FR) gains the injection flow, with a back-up + test-in-DCS
  warning.

### Feature — Anchored zones via DCS Moving Zone (FEAT-MOVING-ZONE)

- `CTLDLogisticZone` and `CTLDTroopZone`: `getCenter()` now calls `trigger.misc.getZone()` at
  every invocation — Moving Zones (trigger zones attached to a unit in the ME) follow their anchor
  unit live; fixed zones are transparent (same behavior).
- Zone discovery (`_discoverTRZ` / `_discoverLGZ`): detect `linkUnit` in
  `env.mission.triggers.zones` at init and resolve the anchor unit name via `coalition.getGroups()`.
- `isDynamic()` / `isAlive()` extended on both zone entity types to cover Moving Zone anchors;
  `isAlive()` returns false when the anchor unit is destroyed.
- Polygon Moving Zones: vertex relative offsets stored at init, reconstructed to absolute
  coordinates from the live center in `isInZone()`.
- `CTLDTroopZone:isDynamic()` and `isAlive()` added (previously absent).

### Tooling — ctld-tools finalize: gen-au-build, `.exe` distribution, MM docs (CTLD-TOOLS-FINALIZE)

- **gen-au-build**: `merge_CTLD.ps1` now regenerates `src/CTLD_config_defaults.lua` from
  `CTLD_config.yaml` via `ctld-tools` on **every build** — it is a git-ignored artifact, no longer
  committed. The `build` + `busted` CI jobs and `release.yml` gain `setup-python` + poetry; the drift
  check is dropped (the file is always fresh). Dev workflow is now simply "edit the YAML, rebuild".
- **`ctld-tools.exe`** is built (PyInstaller, lupa + datamine bundled) and attached to each Release
  by a **separate `build-exe` job**, isolated so a packaging issue never blocks the `CTLD.lua`
  release. Verified end to end (the exe runs `validate` with the embedded Lua runtime + type set).
- **Docs**: dedicated `mission-maker/ctld-tools.md` page (EN + FR), with the full `user-config.yaml`
  format, commands and examples (block + flow), linked in the site nav.

### Tooling — Mission Maker YAML authoring: `validate` + `gen-user` (CTLD-TOOLS-USERCONFIG)

- **`ctld-tools` gains the MM volet**: `validate` (checks a `user-config.yaml` against the reference
  catalogue + embedded DCS type set, reporting errors with suggestions) and `gen-user` (compiles
  `add` / `remove` / `patch` operations into a `CTLD_userConfig.lua` calling the `ctld.userSetup`
  helpers). Mission Makers target crates and troop groups **by name** — ctld-tools resolves names to
  the unique weight the runtime uses, and flags unknown/ambiguous names.
- **`gen-user --scaffold`** writes a commented starter `user-config.yaml` (block + flow styles).
- **Embedded datamine**: a machine-readable DCS type set (`dcs_types.json`) is bundled in the
  package (kept in sync with `tests/data/dcs_types.lua`) for offline `unit` validation.
- **Distribution**: `release.yml` builds and attaches **`ctld-tools.exe`** (PyInstaller), isolated so
  a packaging hiccup never blocks the `CTLD.lua` release.
- Docs: `mission-maker/configuration.md` (EN + FR) present the YAML authoring flow as recommended.

### Tooling — engine config as YAML source of truth + `ctld-tools` (CTLD-TOOLS-CONFIG)

- **Engine defaults moved out of Lua into `src/CTLD_config.yaml`** (sectioned MM-facing / advanced),
  now the single source of truth. `CTLDConfig:load()` copies a generated `ctld.__configDefaults`
  table (`src/CTLD_config_defaults.lua`) instead of writing ~800 lines of defaults inline; the
  `TEMPLATES` block and the user-YAML merge are unchanged. No in-game behaviour change.
- **New `ctld-tools` Python package** (isolated poetry sub-project `tools/ctld-tools/`, following the
  VMCT stack: typer, ruamel.yaml, lupa, pytest + ruff + mypy): `extract` (one-shot Lua→YAML) and
  `gen-config` (YAML→Lua, re-emitting `ctld.tr()` on desc/name). See ADR 0009.
- **CI**: new `python-quality` workflow (ruff + mypy + pytest). Parity is guarded by a frozen
  reference (yaml→lua→settings == original, with a distinctive translator proving the `ctld.tr`
  wrappers) and a drift check (committed generated Lua == fresh `gen-config`).
- The generated `CTLD_config_defaults.lua` is committed (VEAF pattern) and merged after the
  `CTLD_i18n_*` modules (it calls `ctld.tr` at load time).

### Feature — safe Mission Maker config API `ctld.userSetup` (FEAT-USERCONFIG-API)

- **New `ctld.userSetup` API**: Mission Makers customise the complex config tables from setup
  callbacks instead of the silently-broken Section 2 of `CTLD_userConfig.lua` (which called
  `CTLDConfig.get()` before CTLD had defined it). Helpers on `ctld`: `addCrate`, `removeCrate`,
  `patchCrate` (deep-merge one level), `addTroopGroup`, `removeTroopGroup`, `addTo`, `logDefaults`.
  Each callback runs guarded, so a failing one warns without aborting the others or the mission.
- **`injectAACrates` relocated** from `CTLDCrateManager:_processSpawnableCrates()` to
  `ctld.initialize()` (before the userSetup callbacks), so the AA-system crate sections are visible
  and patchable from a callback. `ctld.initialize()` is now the single place that materialises the
  full config: defaults → AA injection → userSetup callbacks → managers.
- **`CTLD_userConfig.lua` template rewritten**: the broken Section 2 (direct `CTLDConfig.get()`
  edits) is replaced by documented `ctld.userSetup` examples + per-table field schemas; the
  test-only debug block (with its hardcoded `aiZones`) is removed; Section 1 scalar defaults
  corrected (`parachuteMinAltitude*` = 152, `JTAC_droneAltitude` = 4000).
- **Docs**: `mission-maker/configuration.md` (EN + FR) updated to the callback-based flow.

### Tooling — release pre-release channel + `published-latest` (RELEASE-RC-CHANNEL)

- **`release.yml`**: a `-rc`-suffixed version (e.g. `published-v2.0.0-rc1`) now publishes the GitHub
  Release as a **pre-release**, and a new floating **`published-latest`** tag tracks the last
  **stable** release (advanced only by a non-rc release; a pre-release leaves it on the previous
  stable). Trigger model unchanged (tag-driven `published-v*`); `published-latest` is not matched by
  that glob, so it does not re-trigger the workflow.
- **`release` skill**: rc-aware — supports an `x.y.z-rcN` target, keeps `## [Unreleased]` open for a
  pre-release (only a stable release freezes it to `## [x.y.z] — date`), and documents the CD effect
  of an rc vs stable tag.
- **Docs**: `developer/workflow.md` (EN+FR) gains a "Release process" section describing the
  tag-driven flow and the rc/stable channels; corrected the stale "releases promoted to master"
  wording (`master` is not wired to release automation).

### Tooling — dev-local martyr load via `CTLD_DEV_ROOT` (DEV-LOCAL-MIZ)

- **Test mission (`Test_CTLDNEXT_01.miz`, the "martyr")**: the MISSION START trigger now loads
  `CTLD.lua` from a per-developer `CTLD_DEV_ROOT` environment variable instead of a hardcoded
  absolute path. The committed `.miz` no longer carries any machine-specific path (no more git
  noise / leaked personal paths). The trigger is hardened to fail loudly (log + on-screen) on a
  sanitized DCS install, an unset variable, or a bad path. The dead `ctldLogPath = "C:/CTLD.lua"`
  line is removed.
- **Docs**: the live-DCS testing page (`integration-testing`, L1–L6) moved into `docs/developer/`
  and gained a "Loading your build into the test mission (martyr)" section (de-sanitize DCS,
  `setx CTLD_DEV_ROOT`, restart DCS). The `dcs-runtime-debug` skill's `CTLD.log` section is
  realigned onto on-demand `diag_enable_ctld_log.lua` injection (it no longer references a
  `ctldLogPath` set in the `.miz`).

### Tooling — CHANGELOG guard + index-in-PR convention (CHORE-DOC-GATES)

- **New CI job `changelog-guard`**: a pull request that touches `src/**` must also update
  `CHANGELOG.md`, or the check fails. Escape hatch: label the PR `skip-changelog`. Runs on pull
  requests only. Root-cause fix for three lots that merged without a CHANGELOG entry (#36/#37/#38).
- **Workflow docs**: `CLAUDE.md` and `dev/agents/issue-tracker.md` now state that a lot's
  `.backlog/README.md` index line is set to `merged (PR #NN)` **within the delivering PR** (covered
  by review), never left `pending merge` for a separate post-merge commit. The PR template's
  CHANGELOG checkbox points to the `skip-changelog` escape hatch.

### Bug fixes — plugin crate instant refresh (FIX-PLUGIN-CRATE-INSTANT-REFRESH)

- **Fix**: a scene crate injected after init (`_injectSceneCrate`, e.g. a post-init scene
  plugin) now refreshes the transport players' Request Equipment menu immediately instead of
  waiting for the next 10s poll cycle — the crate appears in the menu as soon as the plugin
  loads.

### Bug fixes — LGZ ground poll nil `_isFlying` (FIX-LGZ-POLL-NIL-ISFLYING)

- **Fix**: the LGZ ground-position poll no longer skips players that have never flown
  (`_isFlying == nil`). Guard changed from `== false` to `~= true`, so a nil flight state is
  treated as ground. Regression test added; diagnosed via dcs-bridge (2026-07-19).

### Config validation — extend type collector coverage (TEST-TYPENAME-VALIDATION)

- **`CTLDTypeCollector.collect()`** extended to cover `aiZones[*].vehicleStock`,
  `capabilitiesByType[*].loadableVehiclesRED/BLUE`, and `aiZones[*].vehicleTypes` — closing the
  CI type-linter gap that let the invalid `"M1025 HMMWV Armament"` typeName through to a silent
  DCS spawn substitution.

### Build — separate user config template from deliverable (USERCONFIG-LOADING)

- **`CTLD_userConfig.lua` removed from the build merge**: the MM configuration template is no
  longer embedded in `CTLD.lua`. It is delivered as a standalone file in `dist/` for Mission
  Makers to customise and load via a `DO SCRIPT FILE` trigger **before** `CTLD.lua`.
- **New `CTLD_bootstrap.lua`**: the engine bootstrap (`ctld.initialize()` + auto-start guard)
  extracted into its own source file, merged last into `CTLD.lua`. `CTLD.lua` continues to
  auto-start with factory defaults — no breaking change for existing missions.
- **`dist/CTLD_userConfig.lua`** produced by the build script alongside `CTLD.lua`.

### DCS integration testing — plugin post-init contract (TEST-PLUGIN-POSTINIT)

- **F-124** (`noPlayer`, tier `auto`): new L3 scenario verifying the SCENE-PLUGINS post-init
  contract end-to-end in live DCS — `registerSceneModel` called after init adds the model to the
  scene registry; `deferMenuSection` called after init routes directly into `_menuSections` without
  queuing in `_deferredSections`; `requiresCtld` version mismatch logs WARN but still registers
  the model (soft-fail).

### Bug fixes — AI transport C2 (virtual stock) path

- **Fix (Bug 1)**: C2 virtual-stock path no longer activates when a physical vehicle is
  present in the pickup zone but exceeds the helicopter's weight limit. Guard changed from
  `not physicalLoaded` to `not physicalLoaded and not physicalPresent`, matching the
  existing code comment.
- **Fix (Bug 2a)**: invalid DCS typeName `"M1025 HMMWV Armament"` replaced by
  `"M1045 HMMWV TOW"` in the example `vehicleStock` config and all documentation. The
  former caused a silent DCS Leopard-2 substitution at vehicle spawn time.
- **Test**: `F-176` updated to reflect `M1045 HMMWV TOW`; `scenario_mt08b_weight_exceeded`
  (`auto-slow`) added as end-to-end regression — confirms no spawn at dropoff when C1
  rejects the physical vehicle on weight. PASS 7/7.

### Tooling — test taxonomy formalisation

- **Docs**: `CONTEXT.md` Testing terms section rewritten with canonical tier definitions
  (`auto`, `auto-check`, `auto-slow`, `human`, `disabled`), banned aliases (`ia`, `--no-ai`),
  L1–L6 level table, and headless sweep definition.
- **ADR 0006**: documents the `disabled` tier quarantine pattern for scenarios blocked by
  external DCS issues (pathfinding, missing mod).
- **Fix**: `mt08` and `mt14` Land waypoints moved to open flat terrain away from urban areas;
  both scenarios retagged `disabled` → `auto-slow`. MT-08 PASS 12/12, MT-14 PASS.
- **Fix**: stale `recette/` paths in `tests/manual_test_sequences.md` (MT-06 prerequisites)
  corrected to `tests/dcs/util/`.

### Asset validation — no more runtime probe (ASSET-VALIDATION-REVAMP)

- **BREAKING (behavioural)**: CTLD no longer probe-spawns objects at mission start to validate DCS
  type names. `CTLD_modValidator` is removed. The probe wasted resources and fired real
  `S_EVENT_BIRTH`/destroy events that custom mission handlers could observe (ADR 0007).
- **New**: `CTLDTypeCollector` — one source of truth for the DCS types a mission configures
  (registry incl. GROUND `unitType(coalitionId)`, `spawnableCrates`, AA templates, `loadableGroups`)
  and the declared mod types. Fixes a gap where GROUND group unit types were skipped by the scene
  asset gate.
- **New**: optional dev-time **asset-check companion** (`CTLD_asset_check.lua`, a release asset) — a
  mission maker loads it after CTLD during development and it WARNs on unknown configured types (pure
  lookup, no spawning). See [Validating your config](docs/mission-maker/asset-validation.md).
- **New**: `modTypes` config setting to declare a mission's own non-stock (mod) types.
- Custom troop `componentTypes` are used as-is at runtime (no more probe fallback to a standard
  soldier); validity is a dev-time concern now.

### Scenes — pluggable scenes (SCENE-PLUGINS)

- **BREAKING**: the **Metal FARP** scene is no longer bundled in `CTLD.lua`. It is now an opt-in
  **plugin** in the new [`VEAF/CTLD_plugins`](https://github.com/VEAF/CTLD_plugins) repository.
  Missions that use Metal FARP must load its plugin `.lua` from a **mission-start trigger, after
  CTLD** (see the [Scenes & FOB guide](docs/mission-maker/scenes-fob.md#plugin-scenes) and the
  [migration guide](docs/developer/migration-v1-v2.md)). This removes the mod-dependent scene — and
  the warning it printed at every mission start — from the core deliverable.
- **Scenes are now load-position-independent**: the same scene source works whether merged into
  `CTLD.lua` or loaded as a plugin after CTLD. `CTLDPlayerManager.deferMenuSection` routes to the
  live manager when called after init, so a plugin scene's radio submenu still attaches.
- **Change**: scene DCS-asset validation moved from a runtime probe to a **design-time busted
  hard-gate** (datamine set ∪ per-scene `modTypes`). The runtime scene audit
  (`_auditAfterModValidator`) and its `requiresMod` warning were removed; `CTLD_modValidator`
  (crates/troops) is unchanged. A scene may declare `requiresCtld` to warn on an incompatible CTLD.

### Docs — README cleanup

- **Fix**: README H1 renamed from the stale `DCS-CTLD Next` temporary-repo title to `CTLD`.
- **Restructure**: `Pack Equipt` and `Virtual Slingload` demoted from `##` to `###` and moved
  inside `Crate Operations` (their parent workflow, and already grouped under **Crate Commands**
  in the F10 menu); `AA System Construction` relocated to immediately follow `Crate Operations`.
- **Restructure**: `Developer Guide` (a prose block duplicating the published docs site) replaced
  by a `Documentation` section linking directly to the pilot, mission maker and developer guides.
- Table of Contents updated to match the new section hierarchy.

### Bug fixes (FullGas review round)

- **Fix**: whole-vehicle spawn from the **Request Equipment** menu (Feature Q) was silently
  disabled — `refreshRequestEquipmentSection` hardcoded `spawnAsVehicle=false` after a DCS-cargo
  refactor dropped the loadable-vehicle detection. Restored: a transport with
  `canTransportWholeVehicle` again spawns a whole vehicle for its loadable types.
- **Fix**: AI-zone stock validation — dropoff-only zones no longer receive a bogus
  `pickMaxStock`, and an invalid `troopStock` (a legacy scalar like `0`/`-1`/`10`, or an empty
  table, instead of a `{[templateName]=N}` table) now emits a clear config WARN.

### DCS integration testing — first live validation

- **Fix**: `missions/Test_CTLDNEXT_01.miz`'s embedded `beacon.ogg` (420KB) broke the DCS Mission
  Editor's own unpacker on load (`VFS_open_write: Can't create file ...beacon.ogg`) — replaced
  with a 4-byte stub (source preserved at `assets/beacon.ogg`; no test scenario depends on
  audio). Root cause is a DCS Mission Editor bug, not a zip-structure issue (verified: intact
  archive, explicit zip directory entries made no difference).
- **Fix**: `Test_CTLDNEXT_01.miz`'s startup trigger now loads `CTLD.lua` from a real path, sets
  a valid `ctldLogPath`, and injects `dcs-bridge.lua` (replacing the old Witchcraft injection)
  with the `dcsBridge = { host, port }` config `dcs-bridge.lua` needs to actually connect to
  `dcs-serve` (undocumented gotcha — flagged upstream as `VEAF-dcs-bridge` `LOT-013`).
- **Fix**: `tools/integration-runner/run_scenarios.py` crashed on Windows consoles (`cp1252`)
  when a scenario's verdict message contained non-ASCII characters — `stdout`/`stderr` now
  forced to UTF-8.
- `integration-testing` skill documents the `dcsBridge` port-config prerequisite and the
  DCS-editor `beacon.ogg`-class bug (large embedded `l10n/DEFAULT/` resources).
- First full live run (`--no-ai`, 45 scenarios) against a real DCS mission: 27/45 passed after a
  mission reload cleared cross-scenario state contamination between 4 vehicle/JTAC-family
  scenarios (F-120/F-121/F-122/F-123); 18 failures total. 8 were fixed by the FullGas review
  round above; the remaining 10 (`FIX-LIVE-DCS-FAILURES` lot) turned out to be the same class of
  cross-scenario state contamination, not real bugs — a fresh mission reload cleared all of them
  (48/48 `auto`/`auto-check` scenarios green, confirmed on two consecutive fresh runs).

### DCS integration testing — pilot-scenario catch-up (`CATCH-UP-PILOT-SCENARIOS`)

- **Fix**: `CTLDTroopManager:refreshMenuSection` always computed flight state live via
  `_isInAir(unit)`, unlike `CTLDCrateManager:refreshCrateFlightSection` which accepts an
  `overrideInAir` param so `onTakeoff`/`onLand` can force the correct state immediately
  (`S_EVENT_LAND`/`TAKEOFF` fire before `ctld.utils.inAir()`'s speed/AGL threshold settles).
  Found live: right after landing, "Parachute Troops" stayed visible and "Disembark Troops"
  stayed hidden. `refreshMenuSection` now takes the same `overrideInAir` param, wired through
  `onTakeoff`/`onLand`/the flight-state poller.
- Added `tools/integration-runner/run_ia_scenario.py`: an interactive terminal runner for
  `ia`-tier `pilotActive`/`pilotPassive` scenarios that self-verify (most of them) — no AI
  needed to drive the injection/polling loop, just a live pilot. Re-running the same command
  resets any stuck state first (crash recovery), instead of requiring a DCS restart.
- Bumped `HUMAN_TIMEOUT_S` 300s→3600s in the two L5 menu-visual scenarios and the
  `_template_pilotActive.lua` template — 5 minutes was a source of false FAILs, not a useful
  safety net, for a step that's meant to be answered at a real pilot's pace.
- **Mistagging found**: `scenarioTroopsFullCycle_v2.lua`, `scenario_extract_menu.lua`,
  `scenario_jtac_crate_pack.lua`, `scenario_feature_k_jtac_vehicle.lua` were all tagged `ia` by
  the `pilotPassive/` folder-blanket default, but none check real flight state or wait on F10 —
  only a BLUE slot occupied for position/groupId. Retagged `auto-check`, now runnable via
  `run_scenarios.py --no-ai` too. `run_scenarios.py` gained the same `RUNNING`-verdict
  re-injection support `run_ia_scenario.py` already had (previously it failed `RUNNING`
  outright, assuming a physical action was always needed).
- **Fix**: `scenarioTroopsFullCycle_v2.lua`'s step 7 (destroys 4 targets on a timer, validates
  JTAC reacquisition) had no guard against re-entry while its ~50s monitoring window was still
  running — `run_ia_scenario.py` re-injecting every 2s on `RUNNING` raced a second concurrent
  destroy/snapshot timer against the first, corrupting the claim log. Added a re-entry guard
  and exposed `_SCN_TFC_CLEANUP` (this scenario had no external-reset hook at all; a `FAIL`
  inside `check()` left `_G[STEP_N]` stuck re-validating stale data on any re-run).
- **Fix**: `run_ia_scenario.py` only printed progress when the verdict *token* changed — a
  multi-step `RUNNING` scenario's message advances every step while the token stays `RUNNING`
  throughout, so a long-but-healthy step looked indistinguishable from a hang. Now prints on
  any message change.
- **Tier audit (ticket 04)**: `scenario_multigroup_transport`, `scenario_weight_aggregation`,
  `scenario_unpack_jtac_drone`, `scenario_farp_repack` retagged `ia`→`auto-check` (none need
  piloting — just a BLUE slot). Only `scenario_warehouse_cycle` remains genuine `ia (fly)`.
- **Fix**: `scenario_farp_repack.lua` referenced the dead FullGas `ctld_test` framework (nil,
  same cause as the 194 relics) — replaced with a local `getTransport()`. It also never emitted
  a terminal verdict (looped 1→2→99→1 forever under the re-inject loop) — added a `_done` flag
  so the summary step returns `PASS`. Plus a premature-reinjection retry guard (step 2 waited
  for `playSceneAtPos` to register the scene instead of a false immediate `fail()`).
- **Fix**: `scenario_unpack_jtac_drone.lua` V3/V4 asserted the drone had *no* target after its
  spawned RED unit was destroyed — but a mission RED unit (`Sol_g-2`, 4135m) is inside the
  drone's lase range, so it correctly re-tasks. Rewrote V3/V4 to assert the drone no longer
  lases the *specific destroyed unit* (re-tasking to any other in-range enemy is correct CTLD
  behaviour). Also exposed `_SCN_JTACDRONE_INSTR` (it only printed to the DCS screen) and made
  each VERIFY publish its result there for live CLI progress; same missing-`_INSTR` gap fixed
  in `scenario_p2_fob_parachute` / `p3_csfarp_parachute` / `p4_metal_farp`.
- `run_ia_scenario.py` gained an elapsed `[mm:ss]` stamp on every line, a periodic heartbeat
  (`--heartbeat`, default 30s) echoing the last real progress line, and tolerance for transient
  poll errors (`--max-errors`, default 5) so a single HTTP 504 mid-run no longer aborts a
  13-minute scenario.

### CI / tooling

- **CI covers `develop`** — pushes to `develop` and PRs targeting `develop` now run the full
  pipeline (previously only `master`/`feature_*`).
- **Single build source** — the CI build job calls `tools/build/merge_CTLD.ps1` instead of a
  duplicated inline merge, so `CTLD.lua` is produced one canonical way.
- **Coverage ratchet** — the busted job measures coverage and enforces a floor that only ever
  rises (`COVERAGE_FLOOR`).
- **Secret scanning** — gitleaks runs on push and PR.
- **Formatting** — added `stylua.toml`; CI enforcement is deferred to a dedicated stylua-adoption
  lot (style-config sign-off + reviewed baseline reformat) rather than a noisy report-only job.
- **Repo hygiene** — `dependabot.yml` (github-actions), `CODEOWNERS`, issue/PR templates.
- **Bumped GitHub Actions** — `actions/checkout` and `actions/upload-artifact` v4 → v7.
- **Removed the broken `docs` job** — docs publication moves to the DOC-MKDOCS lot (no `mkdocs.yml`
  exists yet).

### Documentation (internal)

- **Architecture Decision Records** — added `dev/adr/` with the key retroactive decisions of the
  v2.0.0 rewrite (modular tree + build, OOP Manager/Entity, MIST removal, legacy API, repack→pack).

### Documentation

- **Docs publishing infrastructure** — `mkdocs.yml` (material, `mkdocs-static-i18n` EN default + FR,
  `mike` versioning) + a `docs.yml` workflow deploying to the repo's `gh-pages` (`develop` → `dev`,
  `master` → `latest`). Content restructure/translation is deferred to the DOC-TECH / DOC-USER-ROLES lots.
- **Developer documentation refonte (DOC-TECH)** — consolidated `docs/dev-guide.md`,
  `docs/api-reference.md` and `migration/specs/` into a single, coherent, **bilingual (EN + FR)**
  `docs/developer/` section: `index`, `workflow` (new — backlog process, Git Flow, TDD, quality
  gates, authoring skills), `architecture`, ten `subsystems/` pages, `events`, `i18n`,
  `building-and-testing`, `migration-v1-v2`, `api-reference`, `design-spec`. Every page was
  verified against current `src/` and corrected for drift (stale method names, TRZ naming, dead
  states, `Repack`→`pack`, etc.). Old sources and `migration/specs/` removed; broken links and
  gaps fixed; `mkdocs build --strict` is clean.
- **User guide split by role (DOC-USER-ROLES)** — split the 2062-line monolithic
  `docs/missionmaker_guide.md` into two **bilingual (EN + FR)** role-based sections:
  `docs/pilot/` (in-flight F10 operations — troop transport, crates, vehicles, sling-load,
  parachute, JTAC, recon, beacons, smoke, pack) and `docs/mission-maker/` (Mission Editor + config
  setup — configuration, zones, scenes & FOB, crate catalogue, minefield, translations, legacy API).
  Mixed sections were reorganised by subsection (config → mission-maker, F10 actions → pilot).
  Every page was verified against current `src/` and corrected for drift (menu paths
  `F10 → CTLD → …`, stale config keys, dead request-vehicle branch, AA template counts, legacy
  wrapper signatures, no `EXZ` prefix, etc.). The monolith removed; nav gains Pilot + Mission Maker
  sections; broken links fixed; `mkdocs build --strict` clean.
- **Completed FR coverage** — added the missing French versions of the site home (`docs/index.fr.md`)
  and the Integration Testing page (`docs/recette-procedure.fr.md`), so the FR site no longer falls
  back to English on any page.

### Fixed

- **Stale i18n header comments** — `src/CTLD_i18n*.lua` headers said translation version `1.7`
  (actual `1.8`) and referenced regenerating a non-existent "loader"; corrected to match the code.

### Release

- **Release process** — a `release` skill (consolidates the CHANGELOG into community-oriented
  `RELEASE_NOTES.md`, bumps `ctld.VERSION`, opens a `release/x.y.z` PR) and a dedicated
  `release.yml` workflow triggered by the `published-v*` tag (rebuilds `CTLD.lua` and publishes
  the GitHub Release). The old `release` job and `v*` trigger were moved out of `ci.yml`.

### Tooling

- **Offline config type linter** — a vendored set of known DCS type names
  (`tests/data/dcs_types.lua`, generated from Quaggles/dcs-lua-datamine by
  `tools/dcs-data/gen_dcs_types.py`, not shipped) + a busted spec that reports configured type
  names not in the stock set (likely typos). Runtime `CTLD_modValidator` is unchanged.

### DCS integration testing

- **Migrated from Witchcraft to VEAF-dcs-bridge** — `tests/dcs/` scenarios now inject via
  `dcs-client mcp` / `exec_lua` (project `.mcp.json`) instead of the Witchcraft Node.js bridge.
- **Return contract** — every scenario returns (and mirrors into `_G["_SCN_<ID>_RESULT"]`) a
  parsable verdict: `PASS[ <p>/<t>]`, `FAIL[ <f>/<t>]: <reasons>`, `ABORT: <msg>`, `RUNNING[:
  <detail>]`, or `STARTED` for async scenarios. Documented in the new `integration-testing` skill.
- **79 scenarios migrated** to the new contract (`noPlayer`, `pilotActive`, `pilotPassive`); the
  four `_template_*.lua` templates updated to match.
- **`integration-testing` skill** added, replacing `.claude/witchcraft-workflow.md` (removed).
  The `.vscode/tasks.json` Witchcraft task is also removed.
- **Dev setup** — `tools/dcs-bridge/install.ps1` installs VEAF-dcs-bridge into a project-local,
  gitignored venv (`tools/dcs-bridge/venv/`); `.mcp.json` references it via
  `${CLAUDE_PROJECT_DIR}` so the `dcs-bridge` MCP server works from a fresh checkout without
  relying on the system PATH.
- Note: `tests/dcs/noPlayer/` still contains ~194 legacy FullGas scenarios (dangling
  `DCS-CTLD_FG/recette/setup.lua` reference, no `ctld_test` framework) predating this migration —
  out of scope here, tracked as `CLEANUP-LEGACY-DCS-TESTS`.
- **`@tier` tagging** — every one of the 79 scenarios and the four `_template_*.lua` templates
  now carries a `-- @tier: auto | auto-check | ia` header (43 `auto`, 2 `auto-check`, 34 `ia`),
  documented in the `integration-testing` skill. Lets `INTEGRATION-TEST-RUNNER`'s "run without
  AI" mode select scenarios that don't need a player or human/AI judgment.
- **Headless runner** — `tools/integration-runner/run_scenarios.py` (stdlib-only, no
  install step) discovers scenarios, filters by `@tier`/folder/name, drives them over
  `dcs-serve`'s REST API, polls async (`STARTED`) scenarios to resolution, and writes a JUnit
  XML report. `--no-ai` runs every `auto`/`auto-check` scenario headlessly against a live DCS
  mission; 31 stdlib unit tests cover the parsing/filtering/polling logic without needing
  `dcs-serve`. Closes the three-lot DCS-bridge triptych
  (`DCS-BRIDGE-MCP` → `INTEGRATION-TEST-TAGS` → `INTEGRATION-TEST-RUNNER`).
- **Fix**: `F-122` (JTAC lifecycle on loadVehicle/unloadVehicle) never resolved its verdict —
  a leftover gap from a migration agent cut off mid-file; now returns a proper `PASS`/`FAIL`.

### Claude Code automations (project)

- **Protective hooks** — a PreToolUse hook blocks edits to `migration/source/**` and the generated
  `CTLD.lua`; a PostToolUse hook runs luacheck on edited `src/` Lua (best-effort). See
  `tools/hooks/README.md`.
- **Review subagents** — `lua51-compliance-reviewer` and `legacy-parity-checker` under `.claude/agents/`.

---

## [2.0.0] — 2026-07-06

Complete ground-up modular rewrite of DCS-CTLD as a maintainable, testable, and extensible Lua project.
Single-file deliverable (`CTLD.lua`) produced by the build system from `src/`.
Backward compatible with missions using the v1 scripting API via the legacy compatibility layer.

### Architecture

- **Modular source tree** — `src/` split into ~32 focused files concatenated by `tools/build/merge_CTLD.ps1`.
  Order controlled by `tools/build/listToMerge.txt`.
- **OOP everywhere** — all entities use `src/core/class.lua` prototype system:
  `CTLDCrate`, `CTLDTroopGroup`, `CTLDPlayer`, `CTLDBeacon`, `CTLDJTACDetector`, and all managers.
- **MIST removed** — all `mist.*` calls replaced by `ctld.utils.*`; no external dependency.
- **Legacy API** — `src/legacy/legacy_api.lua` provides 22 thin wrappers for v1 mission scripts
  (`ctld.addTroops`, `ctld.addCrates`, etc.). Drop-in for existing missions.
- **Single event bridge** — `CTLDDCSEventBridge`: one `world.addEventHandler` with internal
  delegation via `bridge:register()`. No more scattered handler registrations.
- **Version constant** — `ctld.VERSION = "2.0.0"` injected at build time into the output header.

### Features added / rewritten

- **`capabilitiesByType`** — unified per-aircraft capability table replaces the legacy per-feature
  boolean globals. Controls crates, troops, parachute, slingload, whole-vehicle transport,
  DCS native cargo integration, and slot/weight limits per aircraft type.
- **`convertNativeLoadToCTLD`** — per-aircraft flag: when `true`, a DCS-native cargo load is
  immediately converted to a CTLD-managed crate (ghost slot prevention). Required for UH-1H,
  CH-47Fbl1. Leave `false` for C-130 / Il-76 which retain DCS native cargo for ground ops and
  use the DCS native parachute function (provides 3D parachute animation on crates).
- **Scene system** — `CTLDSceneManager` + 9 built-in scenes (FARP Alpha, Countryside FARP,
  Metal FARP, FOB, Minefield…). Polar and axis step types. Mission maker can define custom scenes.
- **FARP Repack** — pack a deployed FARP back into crates; warehouse fuel snapshot preserved
  and restored at next unpack. Controlled by `enableFARPRepack`.
- **Mod Validation Guard** — `CTLDModValidator` probes all DCS type names declared in config at
  mission start. Scenes that depend on missing mod types are automatically disabled with a WARN
  outText. `step.critical = true` on a scene step aborts the scene if the spawn returns nil.
  `requiresMod` scene field triggers a WARN for mod types that cannot be auto-validated
  (heliport-type objects: DCS returns identical API values whether the mod is installed or not).
- **AI Zone config** (Feature S) — `cfg.settings["aiZones"]` table replaces brittle naming
  convention. Full control of pickup/dropoff zones, troop/vehicle stock, templates, drop mode.
- **AI Zone stock per template/type** (Feature T) — `troopStock`/`vehicleStock` per template
  name; rotation algorithm favours highest-stock eligible templates.
- **AA System construction** (Feature U) — `CTLDCrateAssemblyManager` spawns AA systems
  (HAWK, Patriot…) without crate assembly steps; AI transport integration.
- **Vehicle Pack** — pack a ground vehicle into crates at any logistics zone; unpack at
  destination for reassembly.
- **Native DCS Cargo (C-130 / Il-76)** — detection of vehicles in cargo bay bounding box;
  whole-vehicle transport without crate workflow.
- **Virtual Slingload** — hover detection, overspeed loss, release / cut menus. No DCS sling
  physics bugs.
- **Virtual Parachute** — inertia + lateral drift simulation for crates, troops, and vehicles.
  Per-aircraft altitude gates. Distinct from DCS native parachute (C-130).
- **Radio Beacons** — VHF/UHF/FM, battery timer, F10 map layer, `CTLDBeaconManager`.
- **JTAC Auto-Lase** — `CTLDJTACDetector` with laser pool (`LASER_CODE_MIN=1111..LASER_CODE_MAX=1688`),
  toggleStandby, orbit task for air JTACs.
- **Zone validation** — `_validateZoneNames()` with i18n error messages (EN/FR/ES/KO).
  Checks TRZ/LGZ/WPZ/AIZ naming, stock coherence, cargoType/vehicle transport gates.
- **i18n** — `ctld.tr()` runtime engine; EN reference + FR/ES/KO translations;
  `generate_i18n_dicts.ps1` drift detector.

### Quality

- **`.luacheckrc`** — static analysis config; `std = "lua51"`, all DCS globals declared.
- **Lua 5.1 strict** — codebase audited for Lua 5.2+ constructs (`goto`, `table.move`,
  `math.type`, `<const>`, `utf8.*`). All replaced with Lua 5.1 equivalents.
- **Nil-safety guards** — `getGroupId`, `isExist`, `getUnits`, `coalition.getGroups`,
  `Group.getByName` call sites hardened.
- **Dead code removed** — `isParachuting`, `parachuteStartAltitude`, `estimatedLandingTime`
  fields; unused `hoverStatus` and player SMK tables.
- **pcall result checks** — all `pcall()` return values checked; silent failures now log WARN.
- **Named constants** — `LASER_CODE_MIN/MAX` (CTLD_jtac.lua), `BEACON_REMOVAL_RADIUS`
  (CTLD_beacon.lua) replace hardcoded literals.
- **Menu cleanup fix** — `missionCommands.removeItemForGroup` now uses opaque `_dcsHandle`
  (was silently ignored when passed `{item.name}`).
- **inAir logic fix** — corrected inverted nil-transport guard in `CTLD_vehicle.lua`.

### CI / Tooling

- **GitHub Actions** — lint, build, busted, release artifact on tag `v*`, MkDocs deploy to
  GitHub Pages on push to master.
- **busted test suite** — `tests/ci/` L1/L2 unit tests with DCS stub environment
  (`tests/helpers/`). Coverage: config, utils, crate manager, troop group, JTAC, beacon, player.
- **DCS integration scenarios** — `tests/dcs/` Witchcraft-injected scenarios for
  pilotPassive (noPlayer) and interactive recettes.
- **Build header** — `merge_CTLD.ps1` injects version, date, and source URL into
  `CTLD.lua` output.

### Documentation

- `docs/missionmaker_guide.md` — 16 sections covering all features, zone setup, per-aircraft
  config, parachute behavior per aircraft type (C-130 native vs UH-1H/CH-47 CTLD menu), slingload,
  scenes, AI zones, scripting API, events.
- `docs/dev-guide.md` — architecture, module split, OOP pattern, event system, testing guide.
- `docs/api-reference.md` — full public API reference.
- MkDocs site deployed to GitHub Pages.

### Migration from v1

See [docs/missionmaker_guide.md §9 — Legacy API compatibility](docs/missionmaker_guide.md) and
`migration/` for the full modernization plan and per-feature spec sheets.

Key breaking changes:
- `ctld.debug = true` no longer sufficient — use `cfg.settings["debug"] = true`.
- Per-aircraft config moved to `capabilitiesByType` table (replaces `ctld.dynamicTransports` etc.).
- Zone naming for AI zones replaced by `cfg.settings["aiZones"]` config table.
- `repack` terminology replaced by `pack` everywhere (methods, config keys, menus).

---

## [1.x] — Legacy (pre-rewrite)

See `migration/MODERNIZATION-PLAN.md` for the full history of the v1 codebase and the
decision log for each architectural change made during the v2 rewrite.
