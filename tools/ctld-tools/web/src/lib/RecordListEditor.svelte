<script lang="ts">
  // Generic editor for a list of records (e.g. loadableGroups, zones). Owns a local copy
  // and emits the whole list on every change. Fields + their editor types are passed in.
  import type { Field } from './tables'

  type Rec = Record<string, unknown>

  let {
    records,
    fields,
    blank,
    onchange,
  }: {
    records: Rec[]
    fields: Field[]
    blank: () => Rec
    onchange: (v: Rec[]) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  let model = $state<Rec[]>($state.snapshot(records) as Rec[])

  function commit() {
    onchange($state.snapshot(model) as Rec[])
  }
  function setField(i: number, field: Field, raw: string | boolean) {
    let value: unknown = raw
    if (field.type === 'number') value = raw === '' ? undefined : Number(raw)
    else if (field.type === 'boolean') value = Boolean(raw)
    model[i][field.name] = value
    commit()
  }
  function addRow() {
    model.push(blank())
    commit()
  }
  function removeRow(i: number) {
    model.splice(i, 1)
    commit()
  }
</script>

<table class="records">
  <thead>
    <tr>
      {#each fields as f (f.name)}<th title={f.tip ?? undefined}>{f.name}</th>{/each}
      <th></th>
    </tr>
  </thead>
  <tbody>
    {#each model as rec, i (i)}
      <tr>
        {#each fields as f (f.name)}
          <td>
            {#if f.choices}
              <select value={String(rec[f.name] ?? '')} onchange={(e) => setField(i, f, e.currentTarget.value)}>
                {#each f.choices as c (c)}<option value={c}>{c}</option>{/each}
              </select>
            {:else if f.type === 'boolean'}
              <input type="checkbox" checked={rec[f.name] === true} onchange={(e) => setField(i, f, e.currentTarget.checked)} />
            {:else if f.type === 'number'}
              <input type="number" step="0.01" value={rec[f.name] as number} onchange={(e) => setField(i, f, e.currentTarget.value)} />
            {:else}
              <input type="text" value={String(rec[f.name] ?? '')} onchange={(e) => setField(i, f, e.currentTarget.value)} />
            {/if}
          </td>
        {/each}
        <td><button class="rm" title="remove row" onclick={() => removeRow(i)}>✕</button></td>
      </tr>
    {/each}
  </tbody>
</table>
<button class="add" onclick={addRow}>+ add</button>

<style>
  .records {
    width: 100%;
    border-collapse: collapse;
  }
  .records th {
    text-align: left;
    font-size: 0.7rem;
    color: #5a6473;
    padding: 0.25rem 0.4rem;
    border-bottom: 1px solid #e0e5ee;
  }
  .records td {
    padding: 0.2rem 0.4rem;
    border-bottom: 1px solid #f0f2f7;
  }
  .records input[type='text'],
  .records input[type='number'],
  .records select {
    width: 100%;
    min-width: 4rem;
    padding: 0.25rem 0.35rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
    font-size: 0.85rem;
  }
  .rm {
    color: #a12020;
    border-color: #e0c3c3;
  }
  .add {
    margin-top: 0.5rem;
  }
</style>
