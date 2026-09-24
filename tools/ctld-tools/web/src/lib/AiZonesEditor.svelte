<script lang="ts">
  // Editor for aiZones — where AI transports pick up and drop off.
  //
  // Entries are NAMED RECORDS, not the positional arrays ZonesEditor handles, which is why this
  // key fell through to the raw JSON box until now: the positional editor would have corrupted it.
  //
  // Two traps this editor exists to respect:
  //
  //  1. `coalition` is a STRING here — RED / BLUE / NEUTRAL — while every other coalition field in
  //     the catalogue is the numeric `side` (1 = RED, 2 = BLUE). Writing a number would be read by
  //     the engine as "any coalition", silently. The select's options come from the schema's
  //     `choices`, which are seeded from the engine's own VALID_COALITION table.
  //  2. `troopStock` / `vehicleStock` carry two magic values: the key `All` means every entry, and
  //     the value -1 means unlimited. A bare key/value grid hides both, so the stock rows offer
  //     `All` as a suggestion and render -1 as "unlimited" rather than as a number to memorise.
  import { plural, t } from './i18n.svelte'
  import type { TableField } from './api'
  import { addMissingAizZones, defaultTroopStock, findOrphanedAizZones } from './aizConvention'
  import { DCS_TYPES_LIST, fieldLabel } from './tables'

  type Zone = Record<string, unknown>
  type Stock = Record<string, number>

  let {
    zones,
    fields,
    troopTemplates = [],
    missionZoneNames = [],
    onchange,
  }: {
    zones: Zone[]
    /** Per-field tips and `choices`, from the schema's tableFields.aiZones. */
    fields: Record<string, TableField>
    /** loadableGroups names, offered for troopTemplates and troopStock keys. */
    troopTemplates?: string[]
    /** Real DCS trigger-zone names read from the tracked mission (ticket 01) — offered as
     *  `dcsZoneName` autocomplete, independent of the AIZ_ naming convention (tickets 03/04). */
    missionZoneNames?: string[]
    onchange: (v: Zone[]) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  let model = $state<Zone[]>(($state.snapshot(zones ?? []) as Zone[]) ?? [])

  const UNLIMITED = -1
  const ALL_KEY = 'All'
  const TEMPLATE_LIST = 'ai-zone-templates'
  const ZONE_NAME_LIST = 'ai-zone-mission-zones'

  const tip = (f: string) => fields?.[f]?.tip ?? undefined
  // Never a literal: the vocabulary lives in the schema so a Mission Maker editing the YAML by
  // hand reads the same list, and so the UI cannot drift from the engine's VALID_* tables.
  const choices = (f: string, fallback: string[]) => fields?.[f]?.choices ?? fallback

  // Mirrors ctld_tools/validate.py's _validate_ai_zones exactly (FIX-CTLD-TOOLS-AIZ-STOCK-GAP
  // ticket 02) — same two conditions, computed here so the indicator never waits on a round trip
  // to /api/validate. `troopStockMissing` is a real warning (the engine has no fallback: absent
  // troopStock silently disables troop pickup); `vehicleStockAbsent` is calmly informational (the
  // engine falls back to a physically-placed vehicle instead) — never conflate the two.
  function effectiveCargoType(zone: Zone): string {
    const raw = zone.cargoType
    return raw === 'T' || raw === 'V' || raw === 'TV' ? raw : 'T'
  }
  function troopStockMissing(zone: Zone): boolean {
    return zone.isPickup === true && effectiveCargoType(zone).includes('T') && !zone.troopStock
  }
  function vehicleStockAbsent(zone: Zone): boolean {
    return zone.isPickup === true && effectiveCargoType(zone).includes('V') && !zone.vehicleStock
  }

  // A stock row starts life with an empty name — the Mission Maker types it after adding the row.
  // The local model keeps it so the row stays on screen; it is stripped on the way out, because an
  // empty key would reach the engine as a template named "".
  function published(): Zone[] {
    const out = $state.snapshot(model) as Zone[]
    for (const zone of out) {
      for (const field of ['troopStock', 'vehicleStock']) {
        const stock = zone[field] as Stock | undefined
        if (!stock) continue
        const clean = Object.fromEntries(Object.entries(stock).filter(([k]) => k !== ''))
        if (Object.keys(clean).length === 0) delete zone[field]
        else zone[field] = clean
      }
    }
    return out
  }

  function commit() {
    onchange(published())
  }

  // Reconciliation (tickets 03 + 04 of FEAT-CTLD-TOOLS-AIZ-SYNC): every time the mission-zone list
  // actually changes (a fresh scan, manual via App.svelte's "Choose mission" button or automatic
  // via its mtime check) — `reconciledFor` is read before `model`, so this effect stops depending
  // on `model` the moment it early-returns; it never re-fires from an unrelated edit like
  // `addZone`/`setField`, only from a genuinely new zone list.
  //
  //  - Additions are silent: an entry is created for each AIZ_-convention zone that doesn't have
  //    one yet, stock left absent on purpose (ticket 03).
  //  - Removals always need confirmation: an entry is only a candidate when its dcsZoneName
  //    matches the convention AND its zone is gone from the mission — declining leaves it in
  //    place, and a non-matching entry is never a candidate regardless of its zone (ticket 04).
  let reconciledFor: string[] | null = null
  $effect(() => {
    const names = missionZoneNames
    if (names.length === 0 || names === reconciledFor) return
    reconciledFor = names

    const withAdditions = addMissingAizZones(names, model)
    if (withAdditions !== model) {
      model = withAdditions
      commit()
    }

    const orphaned = findOrphanedAizZones(names, model)
    if (orphaned.length > 0) {
      const message = plural('web.aizone.confirm_removal', orphaned.length, {
        names: orphaned.map((z) => String(z.dcsZoneName ?? '')).join(', '),
      })
      if (confirm(message)) {
        const gone = new Set(orphaned.map((z) => String(z.dcsZoneName ?? '')))
        model = model.filter((z) => !gone.has(String(z.dcsZoneName ?? '')))
        commit()
      }
    }
  })
  function setField(i: number, field: string, value: unknown) {
    if (value === undefined || value === '') delete model[i][field]
    else model[i][field] = value
    commit()
  }
  function addZone() {
    const cargoType = 'T'
    const zone: Zone = { dcsZoneName: '', coalition: 'BLUE', isPickup: true, isDropoff: false, cargoType }
    const troopStock = defaultTroopStock(cargoType)
    if (troopStock) zone.troopStock = troopStock
    model.push(zone)
    commit()
  }
  function removeZone(i: number) {
    model.splice(i, 1)
    commit()
  }

  // ── stock tables: name → count, with All / -1 ────────────────────────────────
  const stockRows = (z: Zone, field: string) => Object.entries((z[field] as Stock) ?? {})

  function setStock(i: number, field: string, rows: [string, number][]) {
    const map: Stock = {}
    for (const [k, v] of rows) map[k] = v
    if (rows.length === 0) delete model[i][field]
    else model[i][field] = map
    commit()
  }
  function renameStock(i: number, field: string, at: number, name: string) {
    const rows = stockRows(model[i], field)
    rows[at] = [name, rows[at][1]]
    setStock(i, field, rows)
  }
  function setStockCount(i: number, field: string, at: number, count: number) {
    const rows = stockRows(model[i], field)
    rows[at] = [rows[at][0], count]
    setStock(i, field, rows)
  }
  function addStock(i: number, field: string) {
    setStock(i, field, [...stockRows(model[i], field), ['', UNLIMITED]])
  }
  function removeStock(i: number, field: string, at: number) {
    setStock(
      i,
      field,
      stockRows(model[i], field).filter((_, n) => n !== at),
    )
  }

  // ── restriction lists: troopTemplates / vehicleTypes ─────────────────────────
  const listRows = (z: Zone, field: string) => ((z[field] as string[]) ?? []) as string[]
  function setList(i: number, field: string, rows: string[]) {
    const kept = rows.filter((r) => r !== '')
    // Empty means "all of them" to the engine, so an empty list is written as absent.
    if (kept.length === 0) delete model[i][field]
    else model[i][field] = kept
    commit()
  }
</script>

<datalist id={TEMPLATE_LIST}>
  {#each troopTemplates as name (name)}<option value={name}></option>{/each}
</datalist>

<datalist id={ZONE_NAME_LIST}>
  {#each missionZoneNames as name (name)}<option value={name}></option>{/each}
</datalist>

{#each model as zone, i (i)}
  <fieldset class="zone">
    <legend>
      {String(zone.dcsZoneName || t('web.aizone.untitled'))}
      {#if troopStockMissing(zone)}
        <span class="stock-flag warn" title={t('web.aizone.troop_stock_missing_tip')}>⚠</span>
      {/if}
      {#if vehicleStockAbsent(zone)}
        <span class="stock-flag info" title={t('web.aizone.vehicle_stock_absent_tip')}>ⓘ</span>
      {/if}
    </legend>

    <div class="row">
      <label title={tip('dcsZoneName')}>
        {fieldLabel('dcsZoneName')}
        <input
          list={ZONE_NAME_LIST}
          value={String(zone.dcsZoneName ?? '')}
          onchange={(e) => setField(i, 'dcsZoneName', e.currentTarget.value)}
        />
      </label>

      <label title={tip('coalition')}>
        {fieldLabel('coalition')}
        <select value={String(zone.coalition ?? '')} onchange={(e) => setField(i, 'coalition', e.currentTarget.value)}>
          {#each choices('coalition', ['RED', 'BLUE', 'NEUTRAL']) as c (c)}<option value={c}>{c}</option>{/each}
        </select>
      </label>

      <label title={tip('cargoType')}>
        {fieldLabel('cargoType')}
        <select value={String(zone.cargoType ?? 'T')} onchange={(e) => setField(i, 'cargoType', e.currentTarget.value)}>
          {#each choices('cargoType', ['T', 'V', 'TV']) as c (c)}<option value={c}>{c}</option>{/each}
        </select>
      </label>

      <label title={tip('aiDropMode')}>
        {fieldLabel('aiDropMode')}
        <select value={String(zone.aiDropMode ?? 'GP')} onchange={(e) => setField(i, 'aiDropMode', e.currentTarget.value)}>
          {#each choices('aiDropMode', ['G', 'P', 'GP']) as c (c)}<option value={c}>{c}</option>{/each}
        </select>
      </label>

      <label class="flag" title={tip('isPickup')}>
        {fieldLabel('isPickup')}
        <input type="checkbox" checked={zone.isPickup === true} onchange={(e) => setField(i, 'isPickup', e.currentTarget.checked)} />
      </label>

      <label class="flag" title={tip('isDropoff')}>
        {fieldLabel('isDropoff')}
        <input type="checkbox" checked={zone.isDropoff === true} onchange={(e) => setField(i, 'isDropoff', e.currentTarget.checked)} />
      </label>

      <button class="danger rm" aria-label={t('web.table.remove', { what: String(zone.dcsZoneName || '') })} onclick={() => removeZone(i)}>✕</button>
    </div>

    {#each [['troopStock', TEMPLATE_LIST], ['vehicleStock', DCS_TYPES_LIST]] as [stockField, listId] (stockField)}
      <div class="stock">
        <span class="stock-label" title={tip(stockField)}>
          {fieldLabel(stockField)}
          {#if stockField === 'troopStock' && troopStockMissing(zone)}
            <span class="stock-flag warn" title={t('web.aizone.troop_stock_missing_tip')}>⚠</span>
          {/if}
          {#if stockField === 'vehicleStock' && vehicleStockAbsent(zone)}
            <span class="stock-flag info" title={t('web.aizone.vehicle_stock_absent_tip')}>ⓘ</span>
          {/if}
        </span>
        {#each stockRows(zone, stockField) as [name, count], n (n)}
          <div class="stock-row">
            <input class="combo" list={listId} placeholder={ALL_KEY} value={name} onchange={(e) => renameStock(i, stockField, n, e.currentTarget.value)} />
            <label class="unlimited">
              <input
                type="checkbox"
                checked={count === UNLIMITED}
                onchange={(e) => setStockCount(i, stockField, n, e.currentTarget.checked ? UNLIMITED : 0)}
              />
              {t('web.aizone.unlimited')}
            </label>
            {#if count !== UNLIMITED}
              <input type="number" min="0" step="1" value={count} onchange={(e) => setStockCount(i, stockField, n, Math.round(Number(e.currentTarget.value)))} />
            {/if}
            <button class="danger rm" aria-label={t('web.table.remove', { what: name })} onclick={() => removeStock(i, stockField, n)}>✕</button>
          </div>
        {/each}
        <button class="add" onclick={() => addStock(i, stockField)}>{t('web.aizone.add_stock')}</button>
      </div>
    {/each}

    {#each [['troopTemplates', TEMPLATE_LIST], ['vehicleTypes', DCS_TYPES_LIST]] as [listField, listId] (listField)}
      <div class="restrict">
        <span class="stock-label" title={tip(listField)}>{fieldLabel(listField)}</span>
        {#each listRows(zone, listField) as entry, n (n)}
          <span class="chip">
            <input
              class="combo"
              list={listId}
              value={entry}
              onchange={(e) => setList(i, listField, listRows(zone, listField).map((v, m) => (m === n ? e.currentTarget.value : v)))}
            />
            <button class="danger rm" aria-label={t('web.table.remove', { what: entry })} onclick={() => setList(i, listField, listRows(zone, listField).filter((_, m) => m !== n))}>✕</button>
          </span>
        {/each}
        <button class="add" onclick={() => setList(i, listField, [...listRows(zone, listField), ' '])}>{t('web.aizone.add_restriction')}</button>
        {#if listRows(zone, listField).length === 0}
          <span class="hint">{t('web.aizone.all_allowed')}</span>
        {/if}
      </div>
    {/each}
  </fieldset>
{/each}

<button class="add" onclick={addZone}>{t('web.aizone.add_zone')}</button>

<style>
  .zone {
    border: 1px solid var(--rule);
    border-radius: 4px;
    padding: 0.5rem 0.75rem 0.75rem;
    margin-bottom: 0.6rem;
  }
  legend {
    color: var(--accent);
    font-size: 0.8rem;
    letter-spacing: 0.04em;
    text-transform: uppercase;
  }
  .row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    align-items: end;
  }
  label {
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    font-size: 0.85rem;
  }
  label.flag,
  label.unlimited {
    flex-direction: row;
    align-items: center;
    gap: 0.35rem;
  }
  .stock,
  .restrict {
    margin-top: 0.6rem;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0.4rem;
  }
  .stock-label {
    font-size: 0.85rem;
    opacity: 0.85;
    min-width: 9rem;
  }
  .stock-row,
  .chip {
    display: flex;
    align-items: center;
    gap: 0.3rem;
  }
  .hint {
    font-size: 0.8rem;
    opacity: 0.6;
  }
  /* Two distinct treatments, on purpose: the troop case is a real warning (the engine has no
     fallback, this zone plainly won't work), the vehicle case is a calm, informational note about
     which of two legitimate modes is active — never let the two look like the same severity. */
  .stock-flag {
    cursor: help;
    font-size: 0.85rem;
  }
  .stock-flag.warn {
    color: var(--warn);
  }
  .stock-flag.info {
    color: var(--ink-dim);
  }
</style>
