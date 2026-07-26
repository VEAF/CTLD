<script lang="ts">
  // Editor for spawnableCrates: { section → [crate entry, …] }. Owns a local editable
  // copy and emits the whole structure on every change (single-user, coarse-grained PUT).
  import { fieldLabel } from './tables'

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

{#snippet removeButton(section: string, i: number, label: string)}
  <button class="danger rm" title={`Remove ${label}`} aria-label={`Remove ${label}`} onclick={() => removeCrate(section, i)}>✕</button>
{/snippet}

{#each sections as section (section)}
  <fieldset class="section">
    <legend>{section}</legend>
    {#each model[section] as crate, i (i)}
      <div class="crate">
        {#if crate.mixedSet}
          <span class="badge">Mixed set</span>
          <label>{fieldLabel('desc')}<input value={String(crate.desc ?? '')} onchange={(e) => setField(section, i, 'desc', e.currentTarget.value)} /></label>
          <label>{fieldLabel('side')}<input type="number" value={crate.side as number} onchange={(e) => setField(section, i, 'side', num(e.currentTarget.value))} /></label>
          <span class="mixed">Component weights: {(crate.mixedSet as unknown[]).join(', ')} kg</span>
        {:else}
          <label title={tip('desc')}>{fieldLabel('desc')}<input value={String(crate.desc ?? '')} onchange={(e) => setField(section, i, 'desc', e.currentTarget.value)} /></label>
          <label title={tip('unit')}>{fieldLabel('unit')}<input value={String(crate.unit ?? '')} onchange={(e) => setField(section, i, 'unit', e.currentTarget.value)} /></label>
          <label title={tip('weight_kg')}>{fieldLabel('weight')}<input type="number" step="0.01" value={crate.weight as number} onchange={(e) => setField(section, i, 'weight', num(e.currentTarget.value))} /></label>
          <label title={tip('cratesRequired')}>{fieldLabel('cratesRequired')}<input type="number" value={crate.cratesRequired as number} onchange={(e) => setField(section, i, 'cratesRequired', num(e.currentTarget.value))} /></label>
          <label title={tip('side')}>{fieldLabel('side')}
            <select class="side" class:red={crate.side === 1} class:blue={crate.side === 2} value={crate.side === undefined ? '' : String(crate.side)} onchange={(e) => setField(section, i, 'side', e.currentTarget.value === '' ? undefined : Number(e.currentTarget.value))}>
              <option value="">Both</option>
              <option value="1">RED</option>
              <option value="2">BLUE</option>
            </select>
          </label>
        {/if}
        {@render removeButton(section, i, String(crate.desc || 'this crate'))}
      </div>
    {/each}
    <button class="add" onclick={() => addCrate(section)}>+ Add crate</button>
  </fieldset>
{/each}

<style>
  .section {
    border: 1px solid var(--hair-soft);
    border-radius: var(--radius);
    margin: 0 0 0.9rem;
    padding: 0.4rem 0.8rem 0.7rem;
  }
  .section legend {
    font-family: var(--font-display);
    font-size: var(--fs-base);
    letter-spacing: 0.4px;
    color: var(--accent);
    padding: 0 0.4rem;
  }
  .crate {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem 0.7rem;
    align-items: flex-end;
    padding: 0.45rem 0;
    border-bottom: 1px solid var(--hair-soft);
  }
  .crate:last-of-type {
    border-bottom: none;
  }
  .crate label {
    display: flex;
    flex-direction: column;
    font-family: var(--font-display);
    font-size: var(--fs-xs);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--ink-faint);
    gap: 0.2rem;
  }
  .crate input[type='number'] {
    width: 6.5rem;
  }
  /* Coalition reads as a coalition, not as a number. */
  .side.red {
    color: var(--side-red);
    border-color: var(--side-red-hair);
    background-color: var(--side-red-soft);
  }
  .side.blue {
    color: var(--side-blue);
    border-color: var(--side-blue-hair);
    background-color: var(--side-blue-soft);
  }
  .badge {
    align-self: center;
    font-family: var(--font-display);
    font-size: var(--fs-xs);
    letter-spacing: 0.5px;
    background: var(--raised);
    color: var(--ink-dim);
    border: 1px solid var(--hair);
    border-radius: 3px;
    padding: 0.1rem 0.4rem;
  }
  .mixed {
    align-self: center;
    font-size: var(--fs-sm);
    color: var(--ink-faint);
  }
  .rm {
    align-self: center;
  }
  .add {
    margin-top: 0.6rem;
  }
</style>
