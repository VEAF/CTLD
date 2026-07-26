<script lang="ts">
  // Editor for capabilitiesByType: aircraft type → capabilities record (bool flags,
  // numeric maxima, two loadable-vehicle string lists). Add a type via a datamine picker.
  import StringListEditor from './StringListEditor.svelte'
  import { t } from './i18n.svelte'
  import { AIRCRAFT_BOOLS, AIRCRAFT_NUMS, blankAircraft, DCS_TYPES_LIST, fieldLabel } from './tables'

  type Rec = Record<string, unknown>

  let {
    capabilities,
    fields,
    onchange,
  }: {
    capabilities: Record<string, Rec>
    fields: Record<string, string | null>
    onchange: (v: Record<string, Rec>) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  let model = $state<Record<string, Rec>>($state.snapshot(capabilities) as Record<string, Rec>)
  let newType = $state('')
  const typeNames = $derived(Object.keys(model).sort())

  function commit() {
    onchange($state.snapshot(model) as Record<string, Rec>)
  }
  function setBool(type: string, field: string, v: boolean) {
    model[type][field] = v
    commit()
  }
  function setNum(type: string, field: string, raw: string) {
    model[type][field] = raw === '' ? undefined : Number(raw)
    commit()
  }
  function setList(type: string, field: string, v: string[]) {
    model[type][field] = v
    commit()
  }
  function addType() {
    const name = newType.trim()
    if (!name || model[name]) return
    model[name] = blankAircraft()
    newType = ''
    commit()
  }
  function removeType(type: string) {
    delete model[type]
    commit()
  }
  const tip = (f: string) => fields?.[f] ?? undefined
</script>

<div class="add-type">
  <!-- The DCS type list is mounted once by App.svelte, so it is available on every family. -->
  <input class="combo" list={DCS_TYPES_LIST} placeholder={t('web.table.add_aircraft_placeholder')} bind:value={newType} />
  <button onclick={addType} disabled={!newType.trim()}>{t('web.table.add_aircraft')}</button>
</div>

{#each typeNames as type (type)}
  <details class="aircraft">
    <summary>
      <span class="type">{type}</span>
      <button class="danger" title={t('web.table.remove', { what: type })} aria-label={t('web.table.remove', { what: type })} onclick={(e) => { e.preventDefault(); removeType(type) }}>✕</button>
    </summary>
    <div class="flags">
      {#each AIRCRAFT_BOOLS as f (f)}
        <label title={tip(f)}><input type="checkbox" checked={model[type][f] === true} onchange={(e) => setBool(type, f, e.currentTarget.checked)} /> {fieldLabel(f)}</label>
      {/each}
    </div>
    <div class="nums">
      {#each AIRCRAFT_NUMS as f (f)}
        <label title={tip(f)}>{fieldLabel(f)}<input type="number" value={model[type][f] as number} onchange={(e) => setNum(type, f, e.currentTarget.value)} /></label>
      {/each}
    </div>
    <div class="lists">
      <div><h4 class="blue" title={tip('loadableVehiclesBLUE')}>{t('web.table.vehicles_blue')}</h4>
        <StringListEditor items={(model[type].loadableVehiclesBLUE as string[]) ?? []} listId={DCS_TYPES_LIST} onchange={(v) => setList(type, 'loadableVehiclesBLUE', v)} /></div>
      <div><h4 class="red" title={tip('loadableVehiclesRED')}>{t('web.table.vehicles_red')}</h4>
        <StringListEditor items={(model[type].loadableVehiclesRED as string[]) ?? []} listId={DCS_TYPES_LIST} onchange={(v) => setList(type, 'loadableVehiclesRED', v)} /></div>
    </div>
  </details>
{/each}

<style>
  .add-type {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 0.8rem;
  }
  .add-type input {
    flex: 1;
  }
  .aircraft {
    border: 1px solid var(--hair-soft);
    border-radius: var(--radius);
    margin-bottom: 0.5rem;
    padding: 0.3rem 0.7rem;
    background: rgba(0, 0, 0, 0.12);
  }
  .aircraft summary {
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 0.5rem;
    padding: 0.3rem 0;
  }
  /* The airframe name is the row's identity — set it like an instrument readout. */
  .aircraft .type {
    font-family: var(--font-mono);
    font-size: var(--fs-md);
    color: var(--ink);
  }
  .flags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.4rem 1.1rem;
    margin: 0.6rem 0;
    font-size: var(--fs-sm);
  }
  .flags label {
    display: flex;
    align-items: center;
    gap: 0.35rem;
    color: var(--ink-dim);
  }
  .nums {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem 1.1rem;
    margin: 0.6rem 0;
  }
  .nums label {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    font-family: var(--font-display);
    font-size: var(--fs-xs);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--ink-faint);
  }
  .nums input {
    width: 7.5rem;
  }
  .lists {
    display: flex;
    gap: 1.5rem;
    flex-wrap: wrap;
    margin-top: 0.6rem;
  }
  .lists h4 {
    margin: 0 0 0.35rem;
    font-family: var(--font-display);
    font-size: var(--fs-xs);
    letter-spacing: 0.6px;
    text-transform: uppercase;
  }
  .lists h4.blue {
    color: var(--side-blue);
  }
  .lists h4.red {
    color: var(--side-red);
  }
</style>
