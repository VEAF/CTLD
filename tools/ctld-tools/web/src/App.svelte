<script lang="ts">
  import { onMount } from 'svelte'
  import {
    getDcsTypes,
    getDefaults,
    getSchema,
    getValidate,
    getVersionGap,
    injectMiz,
    loadDefault,
    loadPath,
    openDialog,
    putSetting,
    save,
    type Finding,
    type SchemaInfo,
    type Snapshot,
    type VersionGap,
  } from './lib/api'
  import AircraftEditor from './lib/AircraftEditor.svelte'
  import BrandMark from './lib/BrandMark.svelte'
  import CratesEditor from './lib/CratesEditor.svelte'
  import JsonEditor from './lib/JsonEditor.svelte'
  import KeyValueEditor from './lib/KeyValueEditor.svelte'
  import RecordListEditor from './lib/RecordListEditor.svelte'
  import SettingRow from './lib/SettingRow.svelte'
  import StringListEditor from './lib/StringListEditor.svelte'
  import ValidationPanel from './lib/ValidationPanel.svelte'
  import VersionGapPopup from './lib/VersionGapPopup.svelte'
  import ZonesEditor from './lib/ZonesEditor.svelte'
  import { DATA_FAMILY, familyDescription, familyIcon, familyLabel, familyOf } from './lib/families'
  import { availableLanguages, currentLanguage, initLanguage, plural, setLanguage, t } from './lib/i18n.svelte'
  import { settingLabel } from './lib/labels'
  import { classify, coerce, isChanged, settingKeys, type EditorType, type Family } from './lib/model'
  import { searchSettings } from './lib/search'
  import { DCS_TYPES_LIST, TROOP_FIELDS, withTips } from './lib/tables'

  const LANG_NAMES: Record<string, string> = { en: 'English', fr: 'Français' }

  const ZONE_TYPES = ['troopZones', 'wpZones', 'AIZones']
  const STRING_LISTS = ['transportPilotNames', 'extractableGroups', 'logisticUnits']

  let schema = $state<SchemaInfo | null>(null)
  let snapshot = $state<Snapshot | null>(null)
  let defaults = $state<Record<string, unknown>>({})
  let error = $state<string | null>(null)
  let status = $state<string | null>(null)
  let findings = $state<Finding[]>([])
  let dcsTypes = $state<string[]>([])
  let gap = $state<VersionGap | null>(null)

  let activeFamily = $state<string | null>(null)
  let query = $state('')
  let revealKey = $state<string | null>(null)
  // null = follow the automatic rule (open when it hides a change); true/false = the user decided.
  let advancedManual = $state<boolean | null>(null)
  let fromDefaults = $state(true)
  let dirty = $state(false)
  let justSaved = $state(false)
  let injected = $state(false)

  const families = $derived<Family[]>(snapshot && schema ? classify(snapshot, schema) : [])
  const current = $derived<Family | null>(families.find((f) => f.key === activeFamily) ?? families[0] ?? null)
  const hasErrors = $derived(findings.some((f) => f.severity === 'error'))

  /** A setting's display name: the schema's translated label, else derived from the key. */
  const labelOf = (key: string) => settingLabel(key, schema?.keys[key]?.label)

  const familyForKey = (key: string) =>
    DATA_FAMILY[key] ?? familyOf(key, schema?.keys[key]?.group)

  const hits = $derived(
    !snapshot || !schema ? [] : searchSettings(query, settingKeys(snapshot), schema, familyForKey),
  )
  const searching = $derived(query.trim().length > 0)

  const changedKeys = $derived<Set<string>>(
    new Set(
      !snapshot ? [] : snapshot.keys.filter((k) => isChanged(snapshot!.values[k], defaults[k])),
    ),
  )
  const changedInFamily = (f: Family) =>
    [...f.standard, ...f.advanced, ...f.data].filter((k) => changedKeys.has(k)).length

  // Never let the Advanced disclosure hide a modification, or the setting a finding points at.
  // It also opens when a family has no common settings at all (Parachute, Zones): a family whose
  // whole content sits behind a closed disclosure looks broken.
  const advancedAuto = $derived(
    !current
      ? false
      : current.standard.length === 0 ||
        current.advanced.some((k) => changedKeys.has(k)) ||
        (revealKey !== null && current.advanced.includes(revealKey)),
  )
  const advancedOpen = $derived(advancedManual ?? advancedAuto)

  const configName = $derived(
    fromDefaults || !snapshot?.path ? t('web.header.defaults') : snapshot.path.replace(/^.*[\\/]/, ''),
  )
  const configVersion = $derived(String(snapshot?.values?.configVersion ?? '—'))
  const saveLabel = $derived(
    dirty ? t('web.state.dirty') : justSaved ? t('web.state.saved') : t('web.state.clean'),
  )
  const step = $derived(injected ? 3 : snapshot ? 2 : 1)
  const steps = $derived([
    { title: t('web.step.load'), hint: t('web.step.load_hint') },
    { title: t('web.step.adjust'), hint: t('web.step.adjust_hint') },
    { title: t('web.step.inject'), hint: t('web.step.inject_hint') },
  ])

  onMount(async () => {
    try {
      // Language first: everything rendered afterwards (including a boot failure) is translated.
      await initLanguage()
      schema = await getSchema(currentLanguage())
      dcsTypes = (await getDcsTypes()).types
      defaults = (await getDefaults()).values
      // Boot straight into a usable state: an empty screen asking the user to "load the defaults"
      // is a question a first-time MM cannot answer.
      await run(loadDefault, true)
    } catch {
      error = t('web.outcome.boot_failed')
    }
  })

  // Descriptions and family labels live in the schema, so a language switch re-fetches it.
  async function switchLanguage(next: string) {
    try {
      await setLanguage(next)
      schema = await getSchema(currentLanguage())
    } catch (e) {
      error = String(e)
    }
  }

  $effect(() => {
    if (!revealKey) return
    const el = document.getElementById(`f_${revealKey}`)
    el?.scrollIntoView?.({ block: 'center' })
  })

  async function run(load: () => Promise<Snapshot>, asDefaults: boolean) {
    try {
      snapshot = await load()
      fromDefaults = asDefaults
      dirty = false
      justSaved = false
      injected = false
      error = null
      // Leave the selection to `current`, which falls back to the first family in domain order.
      activeFamily = null
      advancedManual = null
      await doValidate()
      const g = await getVersionGap()
      gap = g.isEmpty ? null : g
    } catch (e) {
      error = String(e)
    }
  }

  async function doValidate() {
    try {
      findings = (await getValidate()).findings
    } catch {
      findings = []
    }
  }

  function confirmDiscard(): boolean {
    return !dirty || confirm(t('web.confirm_discard'))
  }

  async function applySetting(key: string, value: unknown) {
    const r = await putSetting(key, value)
    if (snapshot) snapshot = { ...snapshot, values: { ...snapshot.values, [key]: r.value } }
    dirty = true
    justSaved = false
    error = null
    await doValidate()
  }

  async function edit(key: string, raw: string | boolean, type: EditorType) {
    try {
      await applySetting(key, coerce(raw, type))
    } catch (e) {
      error = String(e)
    }
  }

  async function reset(key: string, fallback: unknown) {
    try {
      await applySetting(key, fallback)
    } catch (e) {
      error = String(e)
    }
  }

  async function saveData(key: string, value: unknown) {
    try {
      await applySetting(key, value)
    } catch (e) {
      error = String(e)
    }
  }

  async function doLoadDefaults() {
    if (!confirmDiscard()) return
    status = null
    await run(loadDefault, true)
  }

  async function doOpen() {
    if (!confirmDiscard()) return
    try {
      const { path } = await openDialog('open')
      if (!path) return
      status = null
      await run(() => loadPath(path), false)
    } catch (e) {
      error = String(e)
    }
  }

  async function doSave() {
    try {
      const { path } = await openDialog('save')
      if (!path) return
      await save(path)
      error = null
      dirty = false
      justSaved = true
      status = t('web.outcome.saved_to', { path })
    } catch (e) {
      error = String(e)
    }
  }

  async function doInject() {
    try {
      const { path } = await openDialog('miz')
      if (!path) return
      const r = await injectMiz(path)
      error = null
      injected = true
      status = t('web.outcome.injected', { miz: r.injected })
    } catch (e) {
      status = null
      error = hasErrors ? t('web.outcome.inject_blocked') : String(e)
    }
  }

  function pickFamily(key: string) {
    activeFamily = key
    advancedManual = null
    revealKey = null
    query = ''
  }

  /** Jump to the setting a validation finding concerns. */
  function goto(key: string) {
    if (!key) return
    query = ''
    activeFamily = familyForKey(key)
    advancedManual = null
    revealKey = key
  }
</script>

<header class="bar">
  <div class="brand">
    <BrandMark height={34} />
    <div>
      <h1>CTLD</h1>
      <p>{t('web.tagline')}</p>
    </div>
  </div>

  <div class="readouts">
    <div class="readout">
      <span class="lbl">{t('web.header.config')}</span>
      <span class="val">{configName}</span>
    </div>
    <div class="readout">
      <span class="lbl">{t('web.header.version')}</span>
      <span class="val">{configVersion}</span>
    </div>
    <div class="readout">
      <span class="lbl">{saveLabel}</span>
      <span class="val sub">{changedKeys.size ? plural('web.changed', changedKeys.size) : '—'}</span>
    </div>
    <label class="lang">
      <span class="lbl">{t('web.lang.label')}</span>
      <select value={currentLanguage()} onchange={(e) => switchLanguage(e.currentTarget.value)}>
        {#each availableLanguages() as code (code)}
          <option value={code}>{LANG_NAMES[code] ?? code.toUpperCase()}</option>
        {/each}
      </select>
    </label>

    <div class="lamp" class:bad={hasErrors}>
      <span class="dot"></span>{hasErrors ? t('web.validation.lamp_error') : t('web.validation.lamp_ok')}
    </div>
  </div>
</header>

<!-- Mounted once, outside every family: any field taking a DCS type references it, so the combo
     works everywhere and not only on the Aircraft family where the list used to live. -->
<datalist id={DCS_TYPES_LIST}>
  {#each dcsTypes as dcsType (dcsType)}<option value={dcsType}></option>{/each}
</datalist>

<div class="flow">
  {#each steps as s, i (s.title)}
    <div class="step" class:active={step === i + 1} class:done={step > i + 1}>
      <span class="n">{step > i + 1 ? '✓' : i + 1}</span>
      <span class="txt"><span class="t">{s.title}</span><span class="s">{s.hint}</span></span>
    </div>
  {/each}
  <div class="tools">
    <button onclick={doLoadDefaults}>{t('web.action.load_defaults')}</button>
    <button onclick={doOpen}>{t('web.action.open')}</button>
    <button onclick={doSave} disabled={!snapshot}>{t('web.action.save')}</button>
    <button class="primary" onclick={doInject} disabled={!snapshot || hasErrors}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" aria-hidden="true">
        <path d="M12 3.5v11M12 14.5l-4-4M12 14.5l4-4M4.5 19.5h15" />
      </svg>
      {t('web.action.inject')}
    </button>
  </div>
</div>

{#if error}
  <p class="banner error" role="alert">{error}</p>
{:else if status}
  <p class="banner status">{status}</p>
{/if}

{#if gap}
  <VersionGapPopup {gap} {labelOf} onclose={() => (gap = null)} />
{/if}

<div class="body">
  <nav class="rail" aria-label="families">
    <ul>
      {#each families as f (f.key)}
        {@const n = changedInFamily(f)}
        <li>
          <button class:active={f.key === current?.key} onclick={() => pickFamily(f.key)}>
            <svg class="ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              {@html familyIcon(f.key)}
            </svg>
            <span class="name">{familyLabel(f.key, schema?.familyMeta)}</span>
            {#if n}<span class="count" title={plural('web.changed', n)}>{n}</span>{/if}
          </button>
        </li>
      {/each}
    </ul>
  </nav>

  <main class="panel">
    <div class="search">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true">
        <circle cx="11" cy="11" r="7" /><path d="M21 21l-4-4" />
      </svg>
      <input
        type="search"
        placeholder={t('web.search.placeholder')}
        bind:value={query}
        onkeydown={(e) => {
          if (e.key === 'Escape') query = ''
        }}
      />
      {#if searching}
        <button class="ghost clear" aria-label={t('web.action.clear_search')} onclick={() => (query = '')}>✕</button>
      {/if}
    </div>

    <ValidationPanel {findings} {labelOf} ongoto={goto} />

    {#if searching}
      <h2 class="title">{plural('web.search.results', hits.length)}</h2>
      {#if !hits.length}
        <p class="empty">{t('web.search.empty')}</p>
      {/if}
      {#each hits as hit (hit.key)}
        <SettingRow
          settingKey={hit.key}
          meta={schema?.keys[hit.key]}
          value={snapshot?.values[hit.key]}
          fallback={defaults[hit.key]}
          familyName={familyLabel(hit.family, schema?.familyMeta)}
          onedit={edit}
          onreset={reset}
        />
      {/each}
    {:else if current && snapshot}
      <h2 class="title">{familyLabel(current.key, schema?.familyMeta)}</h2>
      {#if familyDescription(current.key, schema?.familyMeta)}
        <p class="family-desc">{familyDescription(current.key, schema?.familyMeta)}</p>
      {/if}

      {#if current.standard.length}
        <h3 class="section">{t('web.section.standard')}</h3>
        {#each current.standard as key (key)}
          <SettingRow
            settingKey={key}
            meta={schema?.keys[key]}
            value={snapshot.values[key]}
            fallback={defaults[key]}
            onedit={edit}
            onreset={reset}
          />
        {/each}
      {/if}

      {#if current.advanced.length}
        <details class="advanced" open={advancedOpen} ontoggle={(e) => (advancedManual = e.currentTarget.open)}>
          <summary>
            <span class="sum-title">{t('web.section.advanced')}</span>
            <span class="sum-hint">{plural('web.section.advanced_hint', current.advanced.length)}</span>
          </summary>
          {#each current.advanced as key (key)}
            <SettingRow
              settingKey={key}
              meta={schema?.keys[key]}
              value={snapshot.values[key]}
              fallback={defaults[key]}
              onedit={edit}
              onreset={reset}
            />
          {/each}
        </details>
      {/if}

      {#if current.data.length}
        <h3 class="section">{t('web.section.data')}</h3>
        {#each current.data as key (key)}
          <section class="datacard">
            <h4>
              {labelOf(key)}
              <code class="rawkey">{key}</code>
              {#if changedKeys.has(key)}<span class="cbadge">{t('web.badge.changed')}</span>{/if}
            </h4>
            <div class="dcbody">
              {#key key}
                {#if key === 'spawnableCrates'}
                  <CratesEditor
                    crates={snapshot.values.spawnableCrates as Record<string, Record<string, unknown>[]>}
                    fields={schema?.tableFields?.spawnableCrates ?? {}}
                    onchange={(v) => saveData('spawnableCrates', v)}
                  />
                {:else if key === 'loadableGroups'}
                  <RecordListEditor
                    records={snapshot.values.loadableGroups as Record<string, unknown>[]}
                    fields={withTips(TROOP_FIELDS, schema?.tableFields?.loadableGroups)}
                    blank={() => ({ name: '' })}
                    onchange={(v) => saveData('loadableGroups', v)}
                  />
                {:else if key === 'capabilitiesByType'}
                  <AircraftEditor
                    capabilities={snapshot.values.capabilitiesByType as Record<string, Record<string, unknown>>}
                    fields={schema?.tableFields?.capabilitiesByType ?? {}}
                    onchange={(v) => saveData('capabilitiesByType', v)}
                  />
                {:else if ZONE_TYPES.includes(key)}
                  <ZonesEditor
                    zones={snapshot.values[key] as unknown[][]}
                    fields={schema?.zoneFields?.[key] ?? []}
                    onchange={(v) => saveData(key, v)}
                  />
                {:else if STRING_LISTS.includes(key)}
                  <StringListEditor items={snapshot.values[key] as string[]} onchange={(v) => saveData(key, v)} />
                {:else if key === 'groundVehicleWeights'}
                  <KeyValueEditor
                    map={snapshot.values.groundVehicleWeights as Record<string, number>}
                    keyList={DCS_TYPES_LIST}
                    onchange={(v) => saveData('groundVehicleWeights', v)}
                  />
                {:else}
                  <JsonEditor value={snapshot.values[key]} onchange={(v) => saveData(key, v)} />
                {/if}
              {/key}
            </div>
          </section>
        {/each}
      {/if}
    {/if}
  </main>
</div>

<style>
  /* ── header ────────────────────────────────────────────────────
     Deliberately opaque: it is the band that anchors the page above the photo behind everything
     else. The photo used to live here and it was the wrong place — a 15:1 band can only ever show
     about an eighth of a 16:9 frame. */
  .bar {
    position: relative;
    display: flex;
    align-items: center;
    gap: 1.5rem;
    flex-wrap: wrap;
    padding: 0.8rem var(--pad);
    background: linear-gradient(180deg, #1b262c, #141c21);
    border-bottom: 2px solid var(--accent);
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 0.8rem;
  }
  /* The mark colours itself from `currentColor`, so it just needs the accent. */
  .brand :global(.brand-mark) {
    color: var(--accent);
  }
  .brand h1 {
    font-family: var(--font-display);
    font-size: var(--fs-xl);
    letter-spacing: 1.5px;
    margin: 0;
    line-height: 1;
  }
  .brand p {
    margin: 0.15rem 0 0;
    font-size: var(--fs-xs);
    color: var(--ink-dim);
    letter-spacing: 0.5px;
    text-transform: uppercase;
  }
  .readouts {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: 1.4rem;
    flex-wrap: wrap;
  }
  .readout {
    display: flex;
    flex-direction: column;
    text-align: right;
  }
  .readout .lbl {
    font-size: var(--fs-xs);
    text-transform: uppercase;
    letter-spacing: 0.7px;
    color: var(--ink-faint);
  }
  .readout .val {
    font-family: var(--font-mono);
    font-size: var(--fs-sm);
  }
  .readout .val.sub {
    color: var(--ink-dim);
  }
  .lang {
    display: flex;
    flex-direction: column;
    gap: 0.15rem;
  }
  .lang .lbl {
    font-size: var(--fs-xs);
    text-transform: uppercase;
    letter-spacing: 0.7px;
    color: var(--ink-faint);
  }
  .lang select {
    padding: 0.2rem 1.7rem 0.2rem 0.4rem;
    font-size: var(--fs-sm);
  }
  .lamp {
    display: inline-flex;
    align-items: center;
    gap: 0.5rem;
    font-family: var(--font-display);
    font-size: var(--fs-base);
    letter-spacing: 0.8px;
    padding: 0.4rem 0.8rem;
    border-radius: var(--radius-sm);
    border: 1px solid var(--ok);
    color: var(--ok);
    background: var(--ok-soft);
  }
  .lamp .dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: var(--ok);
    box-shadow: 0 0 7px var(--ok);
  }
  .lamp.bad {
    border-color: var(--err);
    color: var(--err);
    background: var(--err-soft);
  }
  .lamp.bad .dot {
    background: var(--err);
    box-shadow: 0 0 7px var(--err);
  }

  /* ── guided workflow strip ───────────────────────────────────── */
  .flow {
    display: flex;
    align-items: stretch;
    flex-wrap: wrap;
    gap: 0;
    background: var(--panel-glass);
    border-bottom: 1px solid var(--hair);
  }
  .step {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    padding: 0.6rem 1rem;
    color: var(--ink-dim);
  }
  .step + .step {
    border-left: 1px solid var(--hair-soft);
  }
  .step .n {
    width: 24px;
    height: 24px;
    flex: none;
    border-radius: 50%;
    display: grid;
    place-items: center;
    font-family: var(--font-display);
    font-size: var(--fs-sm);
    border: 1px solid var(--hair);
    background: var(--raised-glass);
  }
  .step.active {
    color: var(--ink);
  }
  .step.active .n {
    border-color: var(--accent);
    color: var(--accent);
  }
  .step.done .n {
    border-color: var(--ok);
    color: var(--ok);
  }
  .step .txt {
    display: flex;
    flex-direction: column;
    line-height: 1.25;
  }
  .step .t {
    font-family: var(--font-display);
    font-size: var(--fs-base);
    letter-spacing: 0.3px;
  }
  .step .s {
    font-size: var(--fs-xs);
    color: var(--ink-faint);
  }
  .tools {
    margin-left: auto;
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.5rem var(--pad) 0.5rem 1rem;
    flex-wrap: wrap;
  }
  .tools svg {
    width: 15px;
    height: 15px;
  }

  /* ── banners ─────────────────────────────────────────────────── */
  .banner {
    margin: 0;
    padding: 0.6rem var(--pad);
    font-size: var(--fs-base);
  }
  .banner.error {
    color: var(--err);
    background: var(--err-soft);
    border-bottom: 1px solid var(--err);
  }
  .banner.status {
    color: var(--ok);
    background: var(--ok-soft);
    border-bottom: 1px solid var(--ok);
  }

  /* ── body ────────────────────────────────────────────────────── */
  .body {
    display: grid;
    grid-template-columns: 14rem minmax(0, 1fr);
    align-items: start;
  }
  .rail {
    background: var(--panel-2-glass);
    border-right: 1px solid var(--hair);
    min-height: calc(100vh - 8.5rem);
    padding: 0.6rem 0 1.5rem;
  }
  .rail ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .rail button {
    width: 100%;
    justify-content: flex-start;
    gap: 0.65rem;
    padding: 0.45rem 0.9rem;
    border: none;
    border-left: 3px solid transparent;
    border-radius: 0;
    background: transparent;
    color: var(--ink-dim);
    font-family: var(--font-body);
    font-size: var(--fs-base);
    letter-spacing: 0;
  }
  .rail button:hover {
    background: rgba(23, 33, 39, 0.85);
    color: var(--ink);
  }
  .rail button.active {
    background: rgba(27, 39, 45, 0.9);
    color: var(--ink);
    border-left-color: var(--accent);
  }
  .rail .ico {
    width: 17px;
    height: 17px;
    flex: none;
    opacity: 0.8;
  }
  .rail button.active .ico {
    color: var(--accent);
    opacity: 1;
  }
  .rail .name {
    text-align: left;
  }
  .rail .count {
    margin-left: auto;
    font-family: var(--font-mono);
    font-size: var(--fs-xs);
    color: var(--accent);
    background: var(--accent-soft);
    border-radius: 3px;
    padding: 0 0.3rem;
  }

  .panel {
    padding: 1.1rem var(--pad) 3rem;
    min-width: 0;
  }
  .title {
    font-family: var(--font-display);
    font-size: var(--fs-lg);
    letter-spacing: 0.4px;
    margin: 0 0 0.35rem;
  }
  /* What the family covers, from the schema — orients a MM who lands here from search. */
  .family-desc {
    margin: 0 0 1rem;
    color: var(--ink-dim);
    max-width: 78ch;
  }
  .section {
    display: flex;
    align-items: center;
    gap: 0.7rem;
    font-family: var(--font-display);
    font-size: var(--fs-sm);
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--accent);
    margin: 1.5rem 0 0.6rem;
  }
  .section::after {
    content: '';
    flex: 1;
    height: 1px;
    background: linear-gradient(90deg, var(--hair), transparent);
  }
  .empty {
    color: var(--ink-dim);
    margin: 0.5rem 0;
  }

  .search {
    position: relative;
    display: flex;
    align-items: center;
    margin-bottom: 1rem;
  }
  .search > svg {
    position: absolute;
    left: 0.7rem;
    width: 16px;
    height: 16px;
    color: var(--ink-faint);
    pointer-events: none;
  }
  .search input {
    width: 100%;
    padding: 0.55rem 2.2rem;
  }
  .search .clear {
    position: absolute;
    right: 0.35rem;
    border-color: transparent;
    color: var(--ink-faint);
    padding: 0.2rem 0.4rem;
  }

  .advanced {
    border: 1px solid var(--hair-soft);
    border-radius: var(--radius);
    margin: 0.9rem 0 0;
    padding: 0 0.5rem 0.5rem;
    background: rgba(0, 0, 0, 0.12);
  }
  .advanced summary {
    display: flex;
    align-items: baseline;
    gap: 0.6rem;
    padding: 0.6rem 0.4rem;
    cursor: pointer;
    list-style: none;
  }
  .advanced summary::-webkit-details-marker {
    display: none;
  }
  .advanced summary::before {
    content: '▸';
    color: var(--ink-faint);
  }
  .advanced[open] summary::before {
    content: '▾';
  }
  .sum-title {
    font-family: var(--font-display);
    font-size: var(--fs-sm);
    letter-spacing: 1px;
    text-transform: uppercase;
    color: var(--ink-dim);
  }
  .sum-hint {
    font-size: var(--fs-xs);
    color: var(--ink-faint);
  }

  .datacard {
    border: 1px solid var(--hair-soft);
    border-radius: var(--radius);
    background: var(--panel-glass);
    margin-bottom: 0.8rem;
    overflow: hidden;
  }
  .datacard h4 {
    display: flex;
    align-items: baseline;
    gap: 0.55rem;
    margin: 0;
    padding: 0.6rem 0.9rem;
    border-bottom: 1px solid var(--hair-soft);
    font-family: var(--font-display);
    font-size: var(--fs-md);
    font-weight: 600;
    letter-spacing: 0.3px;
  }
  .cbadge {
    font-family: var(--font-display);
    font-size: var(--fs-xs);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--accent);
    border: 1px solid var(--accent-soft);
    background: var(--accent-soft);
    border-radius: 3px;
    padding: 0.05rem 0.35rem;
  }
  /* Wide tables scroll inside the card — the page body never scrolls sideways. */
  .dcbody {
    padding: 0.75rem 0.9rem 0.9rem;
    overflow-x: auto;
  }

  @media (max-width: 1000px) {
    .body {
      grid-template-columns: 1fr;
    }
    .rail {
      min-height: 0;
      border-right: none;
      border-bottom: 1px solid var(--hair);
    }
    .rail ul {
      display: flex;
      flex-wrap: wrap;
    }
    .rail button {
      width: auto;
      border-left: none;
      border-bottom: 3px solid transparent;
    }
    .rail button.active {
      border-left: none;
      border-bottom-color: var(--accent);
    }
  }
</style>
