<script lang="ts">
  // Editor for spawnableCrates: { section → [crate entry, …] }. Owns a local editable
  // copy and emits the whole structure on every change (single-user, coarse-grained PUT).
  type Crate = Record<string, unknown>

  let {
    crates,
    fields,
    onchange,
  }: {
    crates: Record<string, Crate[]>
    fields: Record<string, string | null>
    onchange: (v: Record<string, Crate[]>) => void
  } = $props()

  // $state.snapshot deproxies to a plain, independent deep copy (structuredClone chokes
  // on Svelte's reactive proxies when the prop comes from the parent's $state). The initial
  // capture is deliberate — this editor is uncontrolled, it owns its copy after mount.
  // svelte-ignore state_referenced_locally
  let model = $state<Record<string, Crate[]>>($state.snapshot(crates) as Record<string, Crate[]>)
  const sections = $derived(Object.keys(model))

  function commit() {
    onchange($state.snapshot(model) as Record<string, Crate[]>)
  }
  function setField(section: string, i: number, field: string, value: unknown) {
    model[section][i][field] = value
    commit()
  }
  function addCrate(section: string) {
    model[section].push({ desc: '', unit: '', weight: 0, cratesRequired: 1 })
    commit()
  }
  function removeCrate(section: string, i: number) {
    model[section].splice(i, 1)
    commit()
  }

  const tip = (field: string) => fields?.[field] ?? undefined
  const num = (v: unknown) => (v === undefined || v === null || v === '' ? undefined : Number(v))
</script>

{#each sections as section (section)}
  <fieldset class="section">
    <legend>{section}</legend>
    {#each model[section] as crate, i (i)}
      <div class="crate">
        {#if crate.mixedSet}
          <span class="badge">mixed set</span>
          <label>desc<input value={String(crate.desc ?? '')} onchange={(e) => setField(section, i, 'desc', e.currentTarget.value)} /></label>
          <label>side<input type="number" value={crate.side as number} onchange={(e) => setField(section, i, 'side', num(e.currentTarget.value))} /></label>
          <span class="mixed">weights: {(crate.mixedSet as unknown[]).join(', ')}</span>
        {:else}
          <label title={tip('desc')}>desc<input value={String(crate.desc ?? '')} onchange={(e) => setField(section, i, 'desc', e.currentTarget.value)} /></label>
          <label title={tip('unit')}>unit<input value={String(crate.unit ?? '')} onchange={(e) => setField(section, i, 'unit', e.currentTarget.value)} /></label>
          <label title={tip('weight_kg')}>weight<input type="number" step="0.01" value={crate.weight as number} onchange={(e) => setField(section, i, 'weight', num(e.currentTarget.value))} /></label>
          <label title={tip('cratesRequired')}>crates<input type="number" value={crate.cratesRequired as number} onchange={(e) => setField(section, i, 'cratesRequired', num(e.currentTarget.value))} /></label>
          <label title={tip('side')}>side
            <select value={crate.side === undefined ? '' : String(crate.side)} onchange={(e) => setField(section, i, 'side', e.currentTarget.value === '' ? undefined : Number(e.currentTarget.value))}>
              <option value="">both</option>
              <option value="1">RED</option>
              <option value="2">BLUE</option>
            </select>
          </label>
        {/if}
        <button class="rm" title="remove crate" onclick={() => removeCrate(section, i)}>✕</button>
      </div>
    {/each}
    <button class="add" onclick={() => addCrate(section)}>+ crate</button>
  </fieldset>
{/each}

<style>
  .section {
    border: 1px solid #e0e5ee;
    border-radius: 6px;
    margin: 0 0 1rem;
    padding: 0.5rem 0.75rem 0.75rem;
  }
  .section legend {
    font-weight: 600;
    padding: 0 0.4rem;
  }
  .crate {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
    align-items: flex-end;
    padding: 0.35rem 0;
    border-bottom: 1px solid #f0f2f7;
  }
  .crate label {
    display: flex;
    flex-direction: column;
    font-size: 0.7rem;
    color: #5a6473;
    gap: 0.15rem;
  }
  .crate input,
  .crate select {
    padding: 0.25rem 0.35rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
    font-size: 0.85rem;
  }
  .crate input[type='number'] {
    width: 6rem;
  }
  .badge {
    align-self: center;
    background: #eef1f6;
    color: #5a6473;
    border-radius: 4px;
    padding: 0.1rem 0.4rem;
    font-size: 0.7rem;
  }
  .mixed {
    align-self: center;
    font-size: 0.75rem;
    color: #8a93a2;
  }
  .rm {
    color: #a12020;
    border-color: #e0c3c3;
  }
  .add {
    margin-top: 0.5rem;
  }
</style>
