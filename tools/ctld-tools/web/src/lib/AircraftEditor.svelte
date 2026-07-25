<script lang="ts">
  // Editor for capabilitiesByType: aircraft type → capabilities record (bool flags,
  // numeric maxima, two loadable-vehicle string lists). Add a type via a datamine picker.
  import StringListEditor from './StringListEditor.svelte'
  import { AIRCRAFT_BOOLS, AIRCRAFT_NUMS, blankAircraft } from './tables'

  type Rec = Record<string, unknown>

  let {
    capabilities,
    fields,
    types,
    onchange,
  }: {
    capabilities: Record<string, Rec>
    fields: Record<string, string | null>
    types: string[]
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
  <input list="dcs-types" placeholder="add aircraft type…" bind:value={newType} />
  <datalist id="dcs-types">{#each types as t (t)}<option value={t}></option>{/each}</datalist>
  <button onclick={addType} disabled={!newType.trim()}>+ type</button>
</div>

{#each typeNames as type (type)}
  <details class="aircraft">
    <summary>{type}<button class="rm" title="remove type" onclick={(e) => { e.preventDefault(); removeType(type) }}>✕</button></summary>
    <div class="flags">
      {#each AIRCRAFT_BOOLS as f (f)}
        <label title={tip(f)}><input type="checkbox" checked={model[type][f] === true} onchange={(e) => setBool(type, f, e.currentTarget.checked)} /> {f}</label>
      {/each}
    </div>
    <div class="nums">
      {#each AIRCRAFT_NUMS as f (f)}
        <label title={tip(f)}>{f}<input type="number" value={model[type][f] as number} onchange={(e) => setNum(type, f, e.currentTarget.value)} /></label>
      {/each}
    </div>
    <div class="lists">
      <div><h4 title={tip('loadableVehiclesBLUE')}>loadableVehiclesBLUE</h4>
        <StringListEditor items={(model[type].loadableVehiclesBLUE as string[]) ?? []} listId="dcs-types" onchange={(v) => setList(type, 'loadableVehiclesBLUE', v)} /></div>
      <div><h4 title={tip('loadableVehiclesRED')}>loadableVehiclesRED</h4>
        <StringListEditor items={(model[type].loadableVehiclesRED as string[]) ?? []} listId="dcs-types" onchange={(v) => setList(type, 'loadableVehiclesRED', v)} /></div>
    </div>
  </details>
{/each}

<style>
  .add-type {
    display: flex;
    gap: 0.5rem;
    margin-bottom: 0.75rem;
  }
  .add-type input {
    flex: 1;
    padding: 0.3rem 0.5rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
  }
  .aircraft {
    border: 1px solid #e0e5ee;
    border-radius: 6px;
    margin-bottom: 0.5rem;
    padding: 0.25rem 0.5rem;
  }
  .aircraft summary {
    font-weight: 600;
    cursor: pointer;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .flags {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem 1rem;
    margin: 0.5rem 0;
    font-size: 0.8rem;
  }
  .flags label {
    display: flex;
    align-items: center;
    gap: 0.25rem;
  }
  .nums {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem 1rem;
    margin: 0.5rem 0;
  }
  .nums label {
    display: flex;
    flex-direction: column;
    font-size: 0.7rem;
    color: #5a6473;
  }
  .nums input {
    width: 7rem;
    padding: 0.25rem 0.35rem;
    border: 1px solid #c3ccda;
    border-radius: 4px;
  }
  .lists {
    display: flex;
    gap: 1.5rem;
    flex-wrap: wrap;
    margin-top: 0.5rem;
  }
  .lists h4 {
    margin: 0 0 0.25rem;
    font-size: 0.75rem;
    color: #5a6473;
  }
  .rm {
    color: #a12020;
    border-color: #e0c3c3;
  }
</style>
