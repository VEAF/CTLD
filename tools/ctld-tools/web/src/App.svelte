<script lang="ts">
  import { onMount } from 'svelte'
  import { getSchema, loadDefault, loadPath, save, type SchemaInfo, type Snapshot } from './lib/api'
  import { classify, parameterFamilies, type Screens } from './lib/model'

  let schema = $state<SchemaInfo | null>(null)
  let snapshot = $state<Snapshot | null>(null)
  let error = $state<string | null>(null)
  let screen = $state<'parameters' | 'data'>('parameters')
  let activeFamily = $state<string | null>(null)
  let pathInput = $state('')

  const screens = $derived<Screens | null>(snapshot && schema ? classify(snapshot, schema) : null)
  const familyList = $derived<string[]>(
    !screens ? [] : screen === 'parameters' ? parameterFamilies(screens) : screens.data,
  )

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

  const activeKeys = $derived<string[]>(
    !screens || !activeFamily
      ? []
      : screen === 'parameters'
        ? (screens.parameters[activeFamily] ?? [])
        : [activeFamily],
  )

  function display(key: string): string {
    const v = snapshot?.values[key]
    if (v === null || v === undefined) return ''
    if (Array.isArray(v)) return `${v.length} item${v.length === 1 ? '' : 's'}`
    if (typeof v === 'object') {
      const n = Object.keys(v as object).length
      return `${n} entr${n === 1 ? 'y' : 'ies'}`
    }
    return String(v)
  }
</script>

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
              {family}
            </button>
          </li>
        {/each}
      </ul>
    </aside>

    <main class="panel">
      {#if activeFamily}
        <h2>{activeFamily}</h2>
        <table>
          <tbody>
            {#each activeKeys as key (key)}
              <tr>
                <th>{key}</th>
                <td>{display(key)}</td>
              </tr>
            {/each}
          </tbody>
        </table>
        <p class="hint">Read-only shell — editors arrive in ticket 04.</p>
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
    text-transform: capitalize;
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
    text-transform: capitalize;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    text-align: left;
    font-weight: 600;
    padding: 0.35rem 0.5rem;
    width: 45%;
    border-bottom: 1px solid #eef1f6;
    vertical-align: top;
  }
  td {
    padding: 0.35rem 0.5rem;
    border-bottom: 1px solid #eef1f6;
    color: #333b49;
    font-variant-numeric: tabular-nums;
  }
  .hint {
    color: #8a93a2;
    font-size: 0.8rem;
    margin-top: 1rem;
  }
</style>
