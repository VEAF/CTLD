// The English UI strings — the frontend's base dictionary.
//
// Keys mirror the `web.*` entries of the backend catalogs
// (`ctld_tools/data/locales/{en,fr}.json`) exactly, and `i18n.parity.test.ts` fails the build if the
// two drift apart. Keeping EN here rather than fetching it means the first paint and the error paths
// never show raw keys, and the component tests need no i18n fixture; the backend supplies the
// translations on top (see `i18n.svelte.ts`).
//
// Voice: say what the control does, from the Mission Maker's side of the screen. No file-format
// vocabulary where an intent will do — "Inject into mission", not "Inject to .miz".

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
  'web.action.inject': 'Inject into mission…',
  'web.action.reset': 'Reset to default',
  'web.action.clear_search': 'Clear search',

  // ── guided workflow ─────────────────────────────────────────────
  'web.step.load': 'Load',
  'web.step.load_hint': 'defaults or your config file',
  'web.step.adjust': 'Adjust',
  'web.step.adjust_hint': 'tune what your mission needs',
  'web.step.inject': 'Inject',
  'web.step.inject_hint': 'write it into your .miz',

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

  // ── outcomes ────────────────────────────────────────────────────
  'web.outcome.injected':
    'Injected into {miz}. The configuration is applied when the mission starts — no further step needed.',
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
  'web.field.aa': 'Anti-air (MANPAD)',
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
}
