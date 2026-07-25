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
  description: string | null
}

export interface SchemaInfo {
  families: string[]
  keys: Record<string, SchemaKey>
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

export const getSchema = () => fetch('/api/schema').then((r) => json<SchemaInfo>(r))
export const getCatalog = () => fetch('/api/catalog').then((r) => json<Snapshot>(r))
export const loadDefault = () => post('/api/catalog/load-default').then((r) => json<Snapshot>(r))
export const loadPath = (path: string) => post('/api/catalog/load', { path }).then((r) => json<Snapshot>(r))
export const save = (path: string) => post('/api/catalog/save', { path }).then((r) => json<{ saved: string }>(r))
