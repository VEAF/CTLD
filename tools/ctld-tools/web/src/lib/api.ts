// Thin client over the FastAPI backend (ctld_tools/web/app.py).

export interface Snapshot {
  path: string | null
  keys: string[]
  values: Record<string, unknown>
}

export interface SchemaKey {
  group: string | null
  standard: boolean
  choices: unknown[] | null
  /** Named control when the value type is not enough to pick one (`sound` = beacon-sound picker).
   *  Optional like the rest of the schema's metadata: an entry that declares none is normal. */
  editor?: string | null
  /** Written by the tool beside another setting — never listed as a setting of its own. */
  hidden?: boolean
  /** Authored display name in the active language; null → derive one from the key. */
  label: string | null
  /** Authored unit symbol ("m", "s", "kg", …); null → fall back to reading the description. */
  unit: string | null
  description: string | null
}

export interface ZoneField {
  name: string
  pos: number
  type: string
  choices?: string[]
  optional?: boolean
}

export interface FamilyMeta {
  label: string | null
  description: string | null
  order: number
}

/** Help text for one field of a structured table, plus its allowed values when the set is closed. */
export interface TableField {
  tip: string | null
  /** From the schema's `choices:`; present only for a closed vocabulary (e.g. spawnAs, aiZones enums). */
  choices?: string[] | null
}

export interface SchemaInfo {
  families: string[]
  /** Per-family label / description / navigation order, from the schema's `families:` section. */
  familyMeta: Record<string, FamilyMeta>
  keys: Record<string, SchemaKey>
  tableFields: Record<string, Record<string, TableField>>
  zoneFields: Record<string, ZoneField[]>
}

export interface I18nBundle {
  lang: string
  available: string[]
  strings: Record<string, string>
}

export interface Finding {
  severity: string
  where: string
  key: string
  message: string
}

export interface ValidateResult {
  hasErrors: boolean
  findings: Finding[]
}

export interface VersionGap {
  fromVersion: string | null
  toVersion: string | null
  isEmpty: boolean
  added: string[]
  removed: string[]
  changed: { key: string; old: unknown; new: unknown }[]
}

async function json<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let detail = res.statusText
    try {
      detail = (await res.json()).detail ?? detail
    } catch {
      /* non-JSON body */
    }
    throw new Error(detail)
  }
  return res.json() as Promise<T>
}

const post = (url: string, body?: unknown) =>
  fetch(url, {
    method: 'POST',
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  })

const put = (url: string, body: unknown) =>
  fetch(url, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) })

const langQuery = (lang?: string) => (lang ? `?lang=${encodeURIComponent(lang)}` : '')

// Descriptions and family labels are language-dependent, so the schema is re-fetched on a switch.
export const getSchema = (lang?: string) => fetch(`/api/schema${langQuery(lang)}`).then((r) => json<SchemaInfo>(r))
export const getI18n = (lang?: string) => fetch(`/api/i18n${langQuery(lang)}`).then((r) => json<I18nBundle>(r))
export const getDefaults = () => fetch('/api/defaults').then((r) => json<{ values: Record<string, unknown> }>(r))
export const putSetting = (key: string, value: unknown) =>
  put('/api/catalog/setting', { key, value }).then((r) => json<{ key: string; value: unknown }>(r))
export const getValidate = () => fetch('/api/validate').then((r) => json<ValidateResult>(r))
/** `spawnAs` maps every known type to GROUND / AIRPLANE / HELICOPTER — see /api/dcs-types. */
export const getDcsTypes = () =>
  fetch('/api/dcs-types').then((r) => json<{ types: string[]; spawnAs: Record<string, string> }>(r))
export const openDialog = (kind: 'open' | 'save' | 'miz') =>
  fetch(`/api/dialog/${kind}`).then((r) => json<{ path: string | null }>(r))
/** What an install wrote, so the UI can report it without reopening the archive. */
export type InstallResult = {
  injected: string
  mission: string
  engineVersion: string | null
  files: string[]
  triggers: string[]
  replacedPrevious: boolean
  changedSettings: number
  sounds: InstalledSound[]
}

export type InstalledSound = {
  setting: string
  file: string
  size: number
  custom: boolean
}

/** What one beacon-sound picker shows: which source, which file, and whether it can be installed. */
export type SoundState = {
  setting: string
  custom: boolean
  file: string
  /** The name the file had on the MM's disk — the reserved in-mission name would lose it. */
  originalName: string | null
  size: number | null
  available: boolean
}

export const getSounds = () => fetch('/api/sounds').then((r) => json<{ sounds: SoundState[] }>(r))

/** Open the native picker and adopt the chosen file; `{cancelled:true}` when the MM backs out. */
export const chooseSound = (setting: string) =>
  post(`/api/sounds/${setting}/custom`).then((r) =>
    json<{ cancelled?: boolean; setting?: string; file?: string; originalName?: string; size?: number }>(r),
  )

export const resetSound = (setting: string) =>
  post(`/api/sounds/${setting}/default`).then((r) => json<{ setting: string; file: string }>(r))

export const injectMiz = (miz: string) =>
  post('/api/inject', { miz }).then((r) => json<InstallResult>(r))
/** The CTLD version this build belongs to, and the docs version to link to (`dev` for an rc). */
export type ToolVersion = { ctld: string; docs: string }

export const getVersion = () => fetch('/api/version').then((r) => json<ToolVersion>(r))
export const getVersionGap = () => fetch('/api/version-gap').then((r) => json<VersionGap>(r))
export const getCatalog = () => fetch('/api/catalog').then((r) => json<Snapshot>(r))
export const loadDefault = () => post('/api/catalog/load-default').then((r) => json<Snapshot>(r))
export const loadPath = (path: string) => post('/api/catalog/load', { path }).then((r) => json<Snapshot>(r))
export const save = (path: string) => post('/api/catalog/save', { path }).then((r) => json<{ saved: string }>(r))
