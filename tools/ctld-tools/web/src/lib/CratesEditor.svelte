<script lang="ts">
  // Editor for spawnableCrates: { section → [crate entry, …] }. Owns a local editable
  // copy and emits the whole structure on every change (single-user, coarse-grained PUT).
  import type { TableField } from './api'
  import { t } from './i18n.svelte'
  import { DCS_TYPES_LIST, fieldLabel } from './tables'

  type Crate = Record<string, unknown>

  let {
    crates,
    fields,
    spawnAsByType = {},
    onchange,
  }: {
    crates: Record<string, Crate[]>
    fields: Record<string, TableField>
    /** type name → GROUND | AIRPLANE | HELICOPTER, from /api/dcs-types. */
    spawnAsByType?: Record<string, string>
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

  const tip = (field: string) => fields?.[field]?.tip ?? undefined
  const num = (v: unknown) => (v === undefined || v === null || v === '' ? undefined : Number(v))

  // `spawnAs` is authored as GROUND or AIR — the schema's `choices`. AIR is a convenience: DCS
  // needs the exact Group.Category, so it is resolved to AIRPLANE or HELICOPTER from the unit's
  // datamine category on the way out, and folded back to AIR on the way in. The catalogue
  // therefore keeps carrying what the engine expects, and the Mission Maker never has to know
  // which of the two a given airframe is.
  const AIR_VALUES = new Set(['AIRPLANE', 'HELICOPTER'])
  const spawnChoices = $derived(fields?.spawnAs?.choices ?? ['GROUND', 'AIR'])

  /** The stored value shown as one of the authoring choices. */
  function displayedSpawnAs(crate: Crate): string {
    return AIR_VALUES.has(String(crate.spawnAs ?? '')) ? 'AIR' : 'GROUND'
  }

  /** Resolve an authoring choice to what the engine reads, from the crate's unit type. */
  function setSpawnAs(section: string, i: number, choice: string, unit: unknown) {
    if (choice !== 'AIR') {
      // GROUND is the engine's default when the key is absent; omitting it keeps the catalogue
      // as terse as it ships.
      setField(section, i, 'spawnAs', undefined)
      return
    }
    const resolved = spawnAsByType[String(unit ?? '')]
    setField(section, i, 'spawnAs', AIR_VALUES.has(resolved) ? resolved : 'AIRPLANE')
  }
</script>

{#snippet removeButton(section: string, i: number, label: string)}
  <button class="danger rm" title={t('web.table.remove', { what: label })} aria-label={t('web.table.remove', { what: label })} onclick={() => removeCrate(section, i)}>✕</button>
{/snippet}

{#each sections as section (section)}
  <fieldset class="section">
    <legend>{section}</legend>
    {#each model[section] as crate, i (i)}
      <div class="crate">
        {#if crate.mixedSet}
          <span class="badge">{t('web.table.mixed_set')}</span>
          <label>{fieldLabel('desc')}<input value={String(crate.desc ?? '')} onchange={(e) => setField(section, i, 'desc', e.currentTarget.value)} /></label>
          <label>{fieldLabel('side')}<input type="number" value={crate.side as number} onchange={(e) => setField(section, i, 'side', num(e.currentTarget.value))} /></label>
          <span class="mixed">{t('web.table.component_weights', { weights: (crate.mixedSet as unknown[]).join(', ') })}</span>
        {:else}
          <label title={tip('desc')}>{fieldLabel('desc')}<input value={String(crate.desc ?? '')} onchange={(e) => setField(section, i, 'desc', e.currentTarget.value)} /></label>
          <label title={tip('unit')}>{fieldLabel('unit')}<input class="combo" list={DCS_TYPES_LIST} value={String(crate.unit ?? '')} onchange={(e) => setField(section, i, 'unit', e.currentTarget.value)} /></label>
          <label title={tip('weight_kg')}>{fieldLabel('weight')}<input type="number" step="0.01" value={crate.weight as number} onchange={(e) => setField(section, i, 'weight', num(e.currentTarget.value))} /></label>
          <label title={tip('cratesRequired')}>{fieldLabel('cratesRequired')}<input type="number" value={crate.cratesRequired as number} onchange={(e) => setField(section, i, 'cratesRequired', num(e.currentTarget.value))} /></label>
          <label title={tip('side')}>{fieldLabel('side')}
            <select class="side" class:red={crate.side === 1} class:blue={crate.side === 2} value={crate.side === undefined ? '' : String(crate.side)} onchange={(e) => setField(section, i, 'side', e.currentTarget.value === '' ? undefined : Number(e.currentTarget.value))}>
              <option value="">{t('web.table.side_both')}</option>
              <option value="1">RED</option>
              <option value="2">BLUE</option>
            </select>
          </label>
          <label title={tip('spawnAs')}>{fieldLabel('spawnAs')}
            <select value={displayedSpawnAs(crate)} onchange={(e) => setSpawnAs(section, i, e.currentTarget.value, crate.unit)}>
              {#each spawnChoices as choice (choice)}<option value={choice}>{choice}</option>{/each}
            </select>
          </label>
          <label class="flag" title={tip('isJTAC')}>{fieldLabel('isJTAC')}
            <input type="checkbox" checked={crate.isJTAC === true} onchange={(e) => setField(section, i, 'isJTAC', e.currentTarget.checked || undefined)} />
          </label>
        {/if}
        {@render removeButton(section, i, String(crate.desc || t('web.table.this_crate')))}
      </div>
    {/each}
    <button class="add" onclick={() => addCrate(section)}>{t('web.table.add_crate')}</button>
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
