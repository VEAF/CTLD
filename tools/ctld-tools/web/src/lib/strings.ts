// The English UI strings — the frontend's base dictionary.
//
// Keys mirror the `web.*` entries of the backend catalogs
// (`ctld_tools/data/locales/{en,fr}.json`) exactly, and `i18n.parity.test.ts` fails the build if the
// two drift apart. Keeping EN here rather than fetching it means the first paint and the error paths
// never show raw keys, and the component tests need no i18n fixture; the backend supplies the
// translations on top (see `i18n.svelte.ts`).
//
// Voice: say what the control does, from the Mission Maker's side of the screen. No file-format
// vocabulary where an intent will do — "Install into mission", not "Inject to .miz".

export const EN_STRINGS: Record<string, string> = {
  // ── chrome ──────────────────────────────────────────────────────
  'web.tagline': 'Configuration editor · helicopter logistics for DCS World',
  'web.header.config': 'Configuration',
  'web.header.version': 'CTLD version',
  'web.header.defaults': 'CTLD defaults',
  'web.lang.label': 'Language',

  // ── save state ──────────────────────────────────────────────────
  'web.state.clean': 'No changes',
  'web.state.dirty': 'Unsaved changes',
  'web.state.saved': 'Saved',
  'web.changed.one': '{n} setting changed from defaults',
  'web.changed.many': '{n} settings changed from defaults',

  // ── actions ─────────────────────────────────────────────────────
  'web.action.load_defaults': 'Start from CTLD defaults',
  'web.action.open': 'Open a config file…',
  'web.action.save': 'Save as…',
  'web.action.inject': 'Install into mission…',
  'web.action.reset': 'Reset to default',
  'web.action.clear_search': 'Clear search',

  // ── guided workflow ─────────────────────────────────────────────
  'web.step.load': 'Load',
  'web.step.load_hint': 'defaults or your config file',
  'web.step.adjust': 'Adjust',
  'web.step.adjust_hint': 'tune what your mission needs',
  'web.step.inject': 'Install',
  'web.step.inject_hint': 'write CTLD and your settings into your .miz',

  // ── content panel ───────────────────────────────────────────────
  'web.search.placeholder': 'Search all settings by name or description…',
  'web.search.results.one': '{n} setting found',
  'web.search.results.many': '{n} settings found',
  'web.search.empty': 'No setting matches. Try a shorter word, or a term from the CTLD documentation.',
  'web.search.in': 'in',
  'web.section.standard': 'Common settings',
  'web.section.advanced': 'Advanced settings',
  'web.section.advanced_hint.one': '{n} advanced setting',
  'web.section.advanced_hint.many': '{n} advanced settings',
  'web.section.data': 'Mission data',
  'web.badge.changed': 'changed',

  // ── validation ──────────────────────────────────────────────────
  'web.validation.ok': 'Configuration is valid — ready to inject into a mission.',
  'web.validation.problems.one': '{n} problem to fix before injecting',
  'web.validation.problems.many': '{n} problems to fix before injecting',
  'web.validation.warnings.one': '{n} warning',
  'web.validation.warnings.many': '{n} warnings',
  'web.validation.blocks_inject': 'Injection stays disabled until these are fixed.',
  'web.validation.lamp_ok': 'VALID',
  'web.validation.lamp_error': 'CHECK',

  'web.help.docs_title': 'Full documentation',
  'web.help.docs_body': 'The pages for this version of CTLD, in your browser.',
  'web.help.docs_start': 'Getting started',
  'web.help.docs_settings': 'Every setting, explained',
  'web.help.docs_zones': 'Zone setup',
  'web.help.docs_migration': 'Coming from CTLD v1',
  'web.help.version': 'CTLD {version}',

  // ── outcomes ────────────────────────────────────────────────────
  'web.outcome.injected':
    'Installed into {miz}: CTLD {version}, the beacon sounds and your configuration ({changed} setting(s) changed). Two MISSION START triggers were written — configuration, then engine.',
  'web.outcome.installed_replaced': 'A previous CTLD install was replaced.',
  'web.outcome.saved_to': 'Saved to {path}',
  'web.outcome.inject_blocked': 'Fix the problems listed below, then inject again.',
  'web.outcome.boot_failed':
    'Could not reach the CTLD tools service. Close this window and start ctld-tools again; keep the console window open while you work.',
  'web.confirm_discard': 'You have unsaved changes. Discard them?',

  // ── version gap ─────────────────────────────────────────────────
  'web.gap.title': 'This config was written for an older CTLD',
  'web.gap.body':
    'Your file targets CTLD {from_version}; this build ships {to_version}. Nothing has been merged — your settings are untouched. Review what changed, then carry on editing.',
  'web.gap.added.one': '{n} setting new in this CTLD version',
  'web.gap.added.many': '{n} settings new in this CTLD version',
  'web.gap.removed.one': '{n} setting no longer used by CTLD',
  'web.gap.removed.many': '{n} settings no longer used by CTLD',
  'web.gap.changed.one': '{n} default value changed',
  'web.gap.changed.many': '{n} default values changed',
  'web.gap.close': 'Continue',

  // ── table field headings ────────────────────────────────────────
  // Each restates the field's own schema description, so no meaning is invented.
  'web.aizone.add_restriction': "+ restriction",
  'web.aizone.add_stock': "+ stock entry",
  'web.aizone.add_zone': "+ AI zone",
  'web.aizone.all_allowed': "empty = all of them",
  'web.aizone.unlimited': "unlimited",
  'web.aizone.untitled': "New AI zone",
  'web.crate_model.cargo': "Cargo-capable",
  'web.crate_model.cargo_tip': "Marks the static as cargo, so DCS lets a helicopter sling it.",
  'web.crate_model.dynamic': "DCS dynamic cargo",
  'web.crate_model.load': "Carried inside",
  'web.crate_model.shape': "Shape name",
  'web.crate_model.shape_tip': "Optional 3D shape override. Leave empty to omit it \u2014 an empty value would change the DCS definition.",
  'web.crate_model.sling': "Slung underneath",
  'web.crate_model.type': "DCS static type",
  'web.crate_model.type_tip': "The DCS static object a crate is drawn as in this mode.",
  'web.field.aiDropMode': "Delivery mode",
  'web.field.cargoType': "Cargo type",
  'web.field.coalition': "Coalition",
  'web.field.dcsZoneName': "DCS trigger zone",
  'web.field.isDropoff': "Drop-off",
  'web.field.isPickup': "Pickup",
  'web.field.troopStock': "Troop stock",
  'web.field.troopTemplates': "Troop templates",
  'web.field.vehicleStock': "Vehicle stock",
  'web.field.vehicleTypes': "Vehicle types",
  'web.field.aa': 'Anti-air (MANPAD)',
  'web.field.isJTAC': 'JTAC',
  'web.field.spawnAs': 'Unpacks as',
  'web.field.at': 'Anti-tank (RPG)',
  'web.field.canPickup': 'Pickup allowed',
  'web.field.colour': 'Smoke colour',
  'web.field.cratesRequired': 'Crates required',
  'web.field.desc': 'Display name',
  'web.field.groupSize': 'Group size',
  'web.field.iconId': 'Map icon ID',
  'web.field.inf': 'Infantry',
  'web.field.jtac': 'JTAC',
  'web.field.mg': 'Machine-gunners',
  'web.field.mortar': 'Mortar crew',
  'web.field.name': 'Display name',
  'web.field.side': 'Coalition',
  'web.field.troopLimit': 'Troop limit',
  'web.field.unit': 'DCS unit type',
  'web.field.weight': 'Weight (kg)',
  'web.field.zoneName': 'DCS zone name',

  // ── table editors ───────────────────────────────────────────────
  'web.table.add': '+ Add',
  'web.table.add_row': '+ Add row',
  'web.table.add_crate': '+ Add crate',
  'web.table.add_aircraft': '+ Add aircraft',
  'web.table.add_vehicle': '+ Add vehicle',
  'web.table.add_aircraft_placeholder': 'Add an aircraft type…',
  'web.table.remove': 'Remove {what}',
  'web.table.remove_row': 'Remove this row',
  'web.table.this_entry': 'this entry',
  'web.table.this_crate': 'this crate',
  'web.table.mixed_set': 'Mixed set',
  'web.table.component_weights': 'Component weights: {weights} kg',
  'web.table.side_both': 'Both',
  'web.table.vehicles_blue': 'Whole vehicles — BLUE',
  'web.table.vehicles_red': 'Whole vehicles — RED',
  'web.table.json_hint':
    'This table has no dedicated editor yet, so it is edited in its raw form. Keep the punctuation (braces, brackets, commas) exactly as it is and change only the values.',
  'web.table.json_invalid': 'Invalid JSON: {message}',
  // ── in-app help ─────────────────────────────────────────────────
  'web.help.open': "Help",
  'web.help.title': "Using this editor",
  'web.help.intro': "This tool writes CTLD's configuration for you: no Lua, no hunting for crate weights. It starts on CTLD's defaults, you change what your mission needs, and it writes the result into your .miz.",
  'web.help.workflow_title': "The three steps",
  'web.help.workflow_load': "Load — the app opens on CTLD's defaults. Use “Open a config file…” to pick up work you saved earlier.",
  'web.help.workflow_adjust': "Adjust — change what your mission needs. Every edit is kept as you go; nothing is written to disk until you save or inject.",
  'web.help.workflow_inject': "Inject — pick your mission and the configuration is written into it as a MISSION START trigger. Re-injecting updates that trigger instead of adding a second one.",
  'web.help.families_title': "How it is organised",
  'web.help.families_body': "Everything is grouped by what it does. Pick a family on the left and you get its settings and its mission data together — the crate settings and the list of crates live in the same place. This configuration has {settings} settings across {families} families:",
  'web.help.landmarks_title': "Reading a setting",
  'web.help.landmark_name': "Each setting shows a plain-language name; the small grey text beside it is the technical name used in the CTLD documentation and on the forums.",
  'web.help.landmark_units': "Numeric settings show their unit (m, s, min, m/s, kg). A value with no unit is a count, a code or a ratio.",
  'web.help.landmark_changed': "A setting you have changed is marked “changed” and its family gets a counter, so you can always see what you touched.",
  'web.help.landmark_reset': "The arrow next to a changed setting puts CTLD's default value back.",
  'web.help.landmark_advanced': "Rarely-used settings sit under “Advanced settings”, folded away. It opens by itself if it contains something you changed.",
  'web.help.landmark_search': "The search box looks through every family at once, by name or by description — use it when you don't know where a setting lives.",
  'web.help.landmark_lang': "The Language picker switches the whole interface, including these help texts and the settings' own descriptions.",
  'web.help.validation_title': "Validation",
  'web.help.validation_body': "Your configuration is checked as you edit: unknown DCS unit types, duplicate crate weights, and so on. The lamp in the header reads VALID or CHECK, and any problem is listed above the settings — click one to jump to the setting it concerns. Injection stays disabled while an error remains.",
  'web.help.data_title': "Your mission data",
  'web.help.data_body': "These tables are what CTLD operates on. Counts come from the configuration currently open:",
  'web.help.data_entries': "{n} entries",
  'web.help.data_sections': "{n} sections",
  'web.help.saving_title': "Saving",
  'web.help.saving_body': "“Save as…” writes a config file you can reopen later, and the header always says whether your work is saved. Injecting into a mission does not save a config file — do both if you want to keep the configuration around.",
  'web.help.snapshot_title': "One important rule",
  'web.help.snapshot_body': "Your configuration replaces CTLD's defaults completely — it is not a list of changes. Anything removed here is absent in game rather than falling back to a default. That is why you start from the defaults rather than from an empty file.",
  'web.help.close': "Close",
  // ── positional editors (coalition limits, DCS RGBA) ─────────────
  'web.table.colour_preview': "Preview",
  'web.slot.troops_red': "RED coalition",
  'web.slot.troops_blue': "BLUE coalition",
  'web.slot.troops_hint': "0 = no limit",
  'web.slot.colour_r': "Red",
  'web.slot.colour_g': "Green",
  'web.slot.colour_b': "Blue",
  'web.slot.colour_a': "Opacity",
  'web.slot.colour_hint': "0.0 to 1.0",
}
