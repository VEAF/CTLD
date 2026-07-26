<script lang="ts">
  // Editor for a name → number map (groundVehicleWeights). Rows of (key, value); emits
  // the reconstructed object on change.
  import { t } from './i18n.svelte'
  import { fieldLabel } from './tables'

  let {
    map,
    keyList,
    onchange,
  }: {
    map: Record<string, number>
    /** `<datalist>` id backing the key column — set when the key is a DCS type name. */
    keyList?: string
    onchange: (v: Record<string, number>) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  let rows = $state<[string, number][]>(Object.entries($state.snapshot(map) ?? {}) as [string, number][])

  function commit() {
    const out: Record<string, number> = {}
    for (const [k, v] of rows) if (k) out[k] = v
    onchange(out)
  }
  function setKey(i: number, k: string) {
    rows[i][0] = k
    commit()
  }
  function setVal(i: number, v: string) {
    rows[i][1] = Number(v)
    commit()
  }
  function add() {
    rows.push(['', 0])
    commit()
  }
  function remove(i: number) {
    rows.splice(i, 1)
    commit()
  }
</script>

<table class="kv">
  <thead><tr><th>{fieldLabel('unit')}</th><th>{fieldLabel('weight')}</th><th></th></tr></thead>
  <tbody>
    {#each rows as row, i (i)}
      <tr>
        <td><input class={keyList ? 'combo' : undefined} list={keyList} value={row[0]} onchange={(e) => setKey(i, e.currentTarget.value)} /></td>
        <td><input type="number" value={row[1]} onchange={(e) => setVal(i, e.currentTarget.value)} /></td>
        <td><button class="danger" title={t('web.table.remove', { what: row[0] || t('web.table.this_entry') })} aria-label={t('web.table.remove', { what: row[0] || t('web.table.this_entry') })} onclick={() => remove(i)}>✕</button></td>
      </tr>
    {/each}
  </tbody>
</table>
<button class="add" onclick={add}>{t('web.table.add_vehicle')}</button>

<style>
  .kv {
    width: 100%;
    border-collapse: collapse;
  }
  .kv th {
    text-align: left;
    font-family: var(--font-display);
    font-weight: 400;
    font-size: var(--fs-xs);
    letter-spacing: 0.6px;
    text-transform: uppercase;
    color: var(--ink-faint);
    padding: 0.3rem 0.4rem;
    border-bottom: 1px solid var(--hair);
    white-space: nowrap;
  }
  .kv td {
    padding: 0.25rem 0.4rem;
    border-bottom: 1px solid var(--hair-soft);
  }
  .kv tr:last-child td {
    border-bottom: none;
  }
  .kv input {
    width: 100%;
    min-width: 6rem;
  }
  .add {
    margin-top: 0.6rem;
  }
</style>
