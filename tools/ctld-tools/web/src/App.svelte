<script lang="ts">
  import { onMount } from 'svelte'
  import {
    getSchema,
    getValidate,
    loadDefault,
    loadPath,
    putSetting,
    save,
    type Finding,
    type SchemaInfo,
    type Snapshot,
  } from './lib/api'
  import CratesEditor from './lib/CratesEditor.svelte'
  import { familyLabel } from './lib/families'
  import {
    classify,
    coerce,
    editorType,
    parameterFamilies,
    standardSplit,
    type EditorType,
    type Screens,
  } from './lib/model'

  let schema = $state<SchemaInfo | null>(null)
  let snapshot = $state<Snapshot | null>(null)
  let error = $state<string | null>(null)
  let screen = $state<'parameters' | 'data'>('parameters')
  let activeFamily = $state<string | null>(null)
  let pathInput = $state('')
  let findings = $state<Finding[]>([])

  const screens = $derived<Screens | null>(snapshot && schema ? classify(snapshot, schema) : null)
  const familyList = $derived<string[]>(
    !screens ? [] : screen === 'parameters' ? parameterFamilies(screens) : screens.data,
  )
  const activeKeys = $derived<string[]>(
    !screens || !activeFamily
      ? []
      : screen === 'parameters'
        ? (screens.parameters[activeFamily] ?? [])
        : [activeFamily],
  )
  const split = $derived(schema ? standardSplit(activeKeys, schema) : { standard: [], advanced: [] })

  onMount(async () => {
    try {
      schema = await getSchema()
    } catch (e) {
      error = String(e)
    }
  })

  async function run(load: () => Promise<Snapshot>) {
    try {
      snapshot = await load()
      error = null
      activeFamily = familyList[0] ?? null
      await doValidate()
    } catch (e) {
      error = String(e)
    }
  }

  async function doValidate() {
    try {
      findings = (await getValidate()).findings
    } catch {
      findings = []
    }
  }

  async function saveCrates(value: Record<string, Record<string, unknown>[]>) {
    try {
      await putSetting('spawnableCrates', value)
      if (snapshot) snapshot = { ...snapshot, values: { ...snapshot.values, spawnableCrates: value } }
      error = null
      await doValidate()
    } catch (e) {
      error = String(e)
    }
  }

  async function doSave() {
    if (!pathInput) return
    try {
      await save(pathInput)
      error = null
    } catch (e) {
      error = String(e)
    }
  }

  function pick(s: 'parameters' | 'data') {
    screen = s
    activeFamily = familyList[0] ?? null
  }

  async function edit(key: string, raw: string | boolean, type: EditorType) {
    try {
      const r = await putSetting(key, coerce(raw, type))
      if (snapshot) snapshot = { ...snapshot, values: { ...snapshot.values, [key]: r.value } }
      error = null
    } catch (e) {
      error = String(e)
    }
  }

  function dataSummary(key: string): string {
    const v = snapshot?.values[key]
    if (Array.isArray(v)) return `${v.length} item${v.length === 1 ? '' : 's'}`
    if (v !== null && typeof v === 'object') {
      const n = Object.keys(v as object).length
      return `${n} entr${n === 1 ? 'y' : 'ies'}`
    }
    return String(v ?? '')
  }
</script>

{#snippet settingRow(key: string)}
  {@const meta = schema?.keys[key]}
  {@const value = snapshot?.values[key]}
  {@const type = editorType(meta, value)}
  <div class="row">
    <label class="key" for={`f_${key}`}>{key}</label>
    <div class="editor">
      {#if type === 'boolean'}
        <input id={`f_${key}`} type="checkbox" checked={value === true} onchange={(e) => edit(key, e.currentTarget.checked, 'boolean')} />
      {:else if type === 'enum'}
        <select id={`f_${key}`} value={String(value)} onchange={(e) => edit(key, e.currentTarget.value, 'enum')}>
          {#each meta?.choices ?? [] as choice}
            <option value={String(choice)}>{String(choice)}</option>
          {/each}
        </select>
      {:else if type === 'number'}
        <input id={`f_${key}`} type="number" value={value as number} onchange={(e) => edit(key, e.currentTarget.value, 'number')} />
      {:else}
        <input id={`f_${key}`} type="text" value={String(value ?? '')} onchange={(e) => edit(key, e.currentTarget.value, 'string')} />
      {/if}
    </div>
    {#if meta?.description}<p class="help">{meta.description}</p>{/if}
  </div>
{/snippet}

<header>
  <h1>CTLD&nbsp;tools</h1>
  <div class="actions">
    <button onclick={() => run(loadDefault)}>Load defaults</button>
    <input placeholder="path to a config .yaml" bind:value={pathInput} />
    <button onclick={() => run(() => loadPath(pathInput))} disabled={!pathInput}>Open</button>
    <button onclick={doSave} disabled={!pathInput || !snapshot}>Save</button>
  </div>
</header>

{#if error}
  <p class="error" role="alert">{error}</p>
{/if}

{#if !snapshot}
  <p class="empty">Load the defaults or open a config file to begin.</p>
{:else}
  <nav class="tabs">
    <button class:active={screen === 'parameters'} onclick={() => pick('parameters')}>
      Parameters <small>how CTLD behaves</small>
    </button>
    <button class:active={screen === 'data'} onclick={() => pick('data')}>
      Data <small>what CTLD operates on</small>
    </button>
  </nav>

  <div class="body">
    <aside class="families" aria-label="families">
      <ul>
        {#each familyList as family (family)}
          <li>
            <button class:active={family === activeFamily} onclick={() => (activeFamily = family)}>
              {screen === 'parameters' ? familyLabel(family) : family}
            </button>
          </li>
        {/each}
      </ul>
    </aside>

    <main class="panel">
      {#if activeFamily && screen === 'parameters'}
        <h2>{familyLabel(activeFamily)}</h2>
        {#if split.standard.length}
          <h3>Standard</h3>
          {#each split.standard as key (key)}{@render settingRow(key)}{/each}
        {/if}
        {#if split.advanced.length}
          <h3>Advanced</h3>
          {#each split.advanced as key (key)}{@render settingRow(key)}{/each}
        {/if}
      {:else if activeFamily === 'spawnableCrates'}
        <h2>Spawnable crates</h2>
        {#if findings.length}
          <ul class="findings">
            {#each findings as f (f.where + f.key)}
              <li class={f.severity}>{f.where}: {f.message}</li>
            {/each}
          </ul>
        {/if}
        <CratesEditor
          crates={snapshot.values.spawnableCrates as Record<string, Record<string, unknown>[]>}
          fields={schema?.tableFields?.spawnableCrates ?? {}}
          onchange={saveCrates}
        />
      {:else if activeFamily}
        <h2>{activeFamily}</h2>
        <table>
          <tbody>
            <tr><th>{activeFamily}</th><td>{dataSummary(activeFamily)}</td></tr>
          </tbody>
        </table>
        <p class="hint">Structured-data editors arrive in tickets 04c–04e.</p>
      {/if}
    </main>
  </div>
{/if}

<style>
  :global(body) {
    margin: 0;
    font-family: system-ui, sans-serif;
    color: #1c2330;
    background: #f4f6fa;
  }
  header {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.75rem 1.25rem;
    background: #1c2330;
    color: #fff;
  }
  h1 {
    font-size: 1.15rem;
    margin: 0;
    white-space: nowrap;
  }
  .actions {
    display: flex;
    gap: 0.5rem;
    flex: 1;
  }
  .actions input {
    flex: 1;
    padding: 0.35rem 0.5rem;
    border: 1px solid #3a4560;
    border-radius: 4px;
  }
  button {
    padding: 0.35rem 0.7rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
    background: #fff;
    cursor: pointer;
  }
  button:disabled {
    opacity: 0.5;
    cursor: default;
  }
  .error {
    margin: 0.75rem 1.25rem;
    color: #a12020;
  }
  .empty {
    margin: 2rem 1.25rem;
    color: #5a6473;
  }
  .tabs {
    display: flex;
    gap: 0.5rem;
    padding: 0.75rem 1.25rem 0;
  }
  .tabs button {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
  }
  .tabs button small {
    font-weight: 400;
    color: #5a6473;
    font-size: 0.7rem;
  }
  .tabs button.active {
    border-color: #1c2330;
    border-bottom-width: 3px;
  }
  .body {
    display: flex;
    gap: 1rem;
    padding: 1rem 1.25rem;
    align-items: flex-start;
  }
  .families {
    flex: 0 0 12rem;
  }
  .families ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .families button {
    width: 100%;
    text-align: left;
    margin-bottom: 0.25rem;
  }
  .families button.active {
    background: #1c2330;
    color: #fff;
    border-color: #1c2330;
  }
  .panel {
    flex: 1;
    background: #fff;
    border: 1px solid #e0e5ee;
    border-radius: 6px;
    padding: 1rem 1.25rem;
  }
  .panel h2 {
    margin-top: 0;
  }
  .panel h3 {
    margin: 1rem 0 0.5rem;
    font-size: 0.8rem;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: #5a6473;
    border-bottom: 1px solid #eef1f6;
    padding-bottom: 0.25rem;
  }
  .row {
    display: grid;
    grid-template-columns: 45% 1fr;
    gap: 0.25rem 1rem;
    align-items: center;
    padding: 0.3rem 0;
  }
  .row .key {
    font-weight: 600;
    font-family: ui-monospace, monospace;
    font-size: 0.85rem;
  }
  .row .editor input[type='text'],
  .row .editor input[type='number'],
  .row .editor select {
    width: 100%;
    padding: 0.3rem 0.4rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
  }
  .row .help {
    grid-column: 1 / -1;
    margin: 0 0 0.25rem;
    font-size: 0.75rem;
    color: #8a93a2;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    text-align: left;
    padding: 0.35rem 0.5rem;
    border-bottom: 1px solid #eef1f6;
  }
  td {
    padding: 0.35rem 0.5rem;
    border-bottom: 1px solid #eef1f6;
  }
  .hint {
    color: #8a93a2;
    font-size: 0.8rem;
    margin-top: 1rem;
  }
  .findings {
    list-style: none;
    margin: 0 0 1rem;
    padding: 0.5rem 0.75rem;
    background: #fbf5f5;
    border: 1px solid #e9d4d4;
    border-radius: 6px;
    font-size: 0.8rem;
  }
  .findings li.error {
    color: #a12020;
  }
  .findings li.warning {
    color: #8a6d1a;
  }
</style>
