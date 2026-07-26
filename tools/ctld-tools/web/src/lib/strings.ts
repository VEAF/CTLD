// Every user-facing string in the app, in one place.
//
// Two reasons this is centralised rather than inlined in the templates: the wording is a design
// decision that should be reviewable on its own, and the FR translation (the backend already has an
// EN+FR layer in `ctld_tools/i18n.py`) then becomes a mechanical substitution instead of a hunt
// through markup.
//
// Voice: say what the control does, from the Mission Maker's side of the screen. No file-format
// vocabulary where an intent will do — "Inject into mission", not "Inject to .miz".

export const UI = {
  appName: 'CTLD',
  appTagline: 'Configuration editor · helicopter logistics for DCS World',

  // ── header / session ──────────────────────────────────────────
  configLabel: 'Configuration',
  versionLabel: 'CTLD version',
  defaultsName: 'CTLD defaults',
  saveState: {
    clean: 'No changes',
    dirty: 'Unsaved changes',
    saved: 'Saved',
  },
  changedCount: (n: number) => `${n} setting${n === 1 ? '' : 's'} changed from defaults`,

  // ── actions ───────────────────────────────────────────────────
  actions: {
    loadDefaults: 'Start from CTLD defaults',
    open: 'Open a config file…',
    save: 'Save as…',
    inject: 'Inject into mission…',
    reset: 'Reset to default',
    clearSearch: 'Clear search',
  },

  // ── guided workflow ───────────────────────────────────────────
  steps: [
    { title: 'Load', hint: 'defaults or your config file' },
    { title: 'Adjust', hint: 'tune what your mission needs' },
    { title: 'Inject', hint: 'write it into your .miz' },
  ],

  // ── content panel ─────────────────────────────────────────────
  searchPlaceholder: 'Search all settings by name or description…',
  searchResults: (n: number) => `${n} setting${n === 1 ? '' : 's'} found`,
  searchEmpty: 'No setting matches. Try a shorter word, or a term from the CTLD documentation.',
  searchFamilyHint: 'in',
  sectionStandard: 'Common settings',
  sectionAdvanced: 'Advanced settings',
  advancedHint: (n: number) => `${n} advanced setting${n === 1 ? '' : 's'}`,
  sectionData: 'Mission data',
  changedBadge: 'changed',

  // ── validation ────────────────────────────────────────────────
  validation: {
    ok: 'Configuration is valid — ready to inject into a mission.',
    errorsTitle: (n: number) => `${n} problem${n === 1 ? '' : 's'} to fix before injecting`,
    warningsTitle: (n: number) => `${n} warning${n === 1 ? '' : 's'}`,
    blocksInject: 'Injection stays disabled until these are fixed.',
    lampOk: 'VALID',
    lampError: 'CHECK',
  },

  // ── outcomes ──────────────────────────────────────────────────
  injected: (miz: string) =>
    `Injected into ${miz}. The configuration is applied when the mission starts — no further step needed.`,
  savedTo: (path: string) => `Saved to ${path}`,
  injectBlocked: 'Fix the problems listed below, then inject again.',
  bootFailed:
    'Could not reach the CTLD tools service. Close this window and start ctld-tools again; keep the console window open while you work.',
  confirmDiscard: 'You have unsaved changes. Discard them?',

  // ── version gap ───────────────────────────────────────────────
  gap: {
    title: 'This config was written for an older CTLD',
    body: (from: string, to: string) =>
      `Your file targets CTLD ${from}; this build ships ${to}. Nothing has been merged — your settings are untouched. Review what changed, then carry on editing.`,
    added: (n: number) => `${n} setting${n === 1 ? '' : 's'} new in this CTLD version`,
    removed: (n: number) => `${n} setting${n === 1 ? '' : 's'} no longer used by CTLD`,
    changed: (n: number) => `${n} default value${n === 1 ? '' : 's'} changed`,
    close: 'Continue',
  },
} as const
