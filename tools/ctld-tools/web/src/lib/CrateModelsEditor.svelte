<script lang="ts">
  // Editor for spawnableCratesModels — the DCS static a crate is drawn as, per transport mode.
  //
  // Unlike every other data editor here, the set of rows is FIXED: `load`, `sling` and `dynamic`
  // are the three modes CTLDCrateManager:_crateModelKey resolves, so nothing can be added or
  // removed. The UI shows no add/remove affordance at all.
  //
  // Only the fields _spawnStatic actually copies into the DCS data table are editable. The
  // `category` field that used to sit here never reached DCS — dynAddStatic forces 'Cargos'
  // regardless — and was removed from the catalogue in FIX-CATALOGUE-TRUTH.
  import { t } from './i18n.svelte'
  import { DCS_TYPES_LIST } from './tables'

  type Model = Record<string, unknown>

  let {
    models,
    onchange,
  }: {
    models: Record<string, Model>
    onchange: (v: Record<string, Model>) => void
  } = $props()

  // The three transport modes, in the order _crateModelKey resolves them.
  const MODES = ['load', 'sling', 'dynamic'] as const

  // svelte-ignore state_referenced_locally
  let model = $state<Record<string, Model>>($state.snapshot(models ?? {}) as Record<string, Model>)

  function commit() {
    onchange($state.snapshot(model) as Record<string, Model>)
  }

  function setField(mode: string, field: string, value: unknown) {
    if (!model[mode]) model[mode] = {}
    // An empty shape_name must be absent, not "": the engine only sets data.shape_name when the
    // key is present, and writing an empty string would change the DCS static definition.
    if (value === '' || value === undefined) delete model[mode][field]
    else model[mode][field] = value
    commit()
  }
</script>

{#each MODES as mode (mode)}
  <fieldset class="mode">
    <legend>{t(`web.crate_model.${mode}`)}</legend>
    <label title={t('web.crate_model.type_tip')}>
      {t('web.crate_model.type')}
      <input
        class="combo"
        list={DCS_TYPES_LIST}
        value={String(model[mode]?.type ?? '')}
        onchange={(e) => setField(mode, 'type', e.currentTarget.value)}
      />
    </label>
    <label title={t('web.crate_model.shape_tip')}>
      {t('web.crate_model.shape')}
      <input
        value={String(model[mode]?.shape_name ?? '')}
        onchange={(e) => setField(mode, 'shape_name', e.currentTarget.value)}
      />
    </label>
    <label class="flag" title={t('web.crate_model.cargo_tip')}>
      {t('web.crate_model.cargo')}
      <input
        type="checkbox"
        checked={model[mode]?.canCargo === true}
        onchange={(e) => setField(mode, 'canCargo', e.currentTarget.checked)}
      />
    </label>
  </fieldset>
{/each}

<style>
  .mode {
    border: 1px solid var(--rule);
    border-radius: 4px;
    padding: 0.5rem 0.75rem 0.75rem;
    margin-bottom: 0.6rem;
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    align-items: end;
  }
  legend {
    color: var(--accent);
    font-size: 0.8rem;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }
  label {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    font-size: 0.85rem;
  }
  label.flag {
    flex-direction: row;
    align-items: center;
    gap: 0.4rem;
  }
</style>
