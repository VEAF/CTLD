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
export const injectMiz = (miz: string) => post('/api/inject', { miz }).then((r) => json<{ injected: string }>(r))
export const getVersionGap = () => fetch('/api/version-gap').then((r) => json<VersionGap>(r))
export const getCatalog = () => fetch('/api/catalog').then((r) => json<Snapshot>(r))
export const loadDefault = () => post('/api/catalog/load-default').then((r) => json<Snapshot>(r))
export const loadPath = (path: string) => post('/api/catalog/load', { path }).then((r) => json<Snapshot>(r))
export const save = (path: string) => post('/api/catalog/save', { path }).then((r) => json<{ saved: string }>(r))
