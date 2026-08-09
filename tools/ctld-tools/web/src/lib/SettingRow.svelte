<script lang="ts">
  // One setting: human label, raw key, description, the right editor, its unit, and a way back to
  // the CTLD default. The row is the unit of trust — a MM should be able to read what a setting
  // does, see whether they have touched it, and undo that, without leaving the row.
  import type { SchemaKey, SoundState } from './api'
  import { t } from './i18n.svelte'
  import { settingLabel, settingUnit } from './labels'
  import { editorType, isChanged, type EditorType } from './model'
  import SoundPicker from './SoundPicker.svelte'

  let {
    settingKey,
    meta,
    value,
    fallback,
    familyName,
    sound,
    onedit,
    onreset,
    onsound,
  }: {
    settingKey: string
    meta: SchemaKey | undefined
    value: unknown
    fallback: unknown
    /** Set when the row is shown in search results, to say which family owns it. */
    familyName?: string
    /** Present for a setting the schema marks `editor: 'sound'`. */
    sound?: SoundState
    onedit: (key: string, raw: string | boolean, type: EditorType) => void
    onreset: (key: string, fallback: unknown) => void
    onsound?: () => void
  } = $props()

  const name = $derived(settingLabel(settingKey, meta?.label))
  const type = $derived<EditorType>(editorType(meta, value))
  const unit = $derived(settingUnit(meta?.unit, meta?.description))
  const changed = $derived(isChanged(value, fallback))
  const id = $derived(`f_${settingKey}`)
</script>

<div class="row" class:changed>
  <div class="head">
    <label for={id}>{name}</label>
    <code class="rawkey">{settingKey}</code>
    {#if changed}<span class="badge">{t('web.badge.changed')}</span>{/if}
    {#if familyName}<span class="family">{t('web.search.in')} {familyName}</span>{/if}
  </div>

  <div class="ctrl">
    {#if meta?.editor === 'sound' && sound}
      <SoundPicker {sound} onchange={() => onsound?.()} />
    {:else if type === 'boolean'}
      <input {id} type="checkbox" checked={value === true} onchange={(e) => onedit(settingKey, e.currentTarget.checked, 'boolean')} />
    {:else if type === 'enum'}
      <select {id} value={String(value)} onchange={(e) => onedit(settingKey, e.currentTarget.value, 'enum')}>
        {#each meta?.choices ?? [] as choice (String(choice))}
          <option value={String(choice)}>{String(choice)}</option>
        {/each}
      </select>
    {:else if type === 'number'}
      <span class="numfield">
        <input {id} type="number" step="any" value={value as number} onchange={(e) => onedit(settingKey, e.currentTarget.value, 'number')} />
        {#if unit}<span class="unit">{unit}</span>{/if}
      </span>
    {:else}
      <input {id} type="text" value={String(value ?? '')} onchange={(e) => onedit(settingKey, e.currentTarget.value, 'string')} />
    {/if}

    {#if changed && meta?.editor !== 'sound'}
      <button class="ghost reset" title={t('web.action.reset')} aria-label={`${t('web.action.reset')}: ${name}`} onclick={() => onreset(settingKey, fallback)}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round">
          <path d="M4 12a8 8 0 1 0 3-6.2M4 4v4h4" />
        </svg>
      </button>
    {/if}
  </div>

  {#if meta?.description}<p class="desc">{meta.description}</p>{/if}
</div>

<style>
  .row {
    display: grid;
    grid-template-columns: 1fr auto;
    gap: 0.2rem 1.25rem;
    align-items: center;
    padding: 0.7rem 0.9rem;
    background: var(--panel-glass);
    border: 1px solid var(--hair-soft);
    border-radius: var(--radius);
    margin-bottom: 0.4rem;
  }
  .row:hover {
    border-color: var(--hair);
  }
  /* A touched setting is marked on the edge, so a column of rows shows at a glance what was changed. */
  .row.changed {
    border-left: 2px solid var(--accent);
  }
  .head {
    display: flex;
    align-items: baseline;
    flex-wrap: wrap;
    gap: 0.5rem;
    min-width: 0;
  }
  .head label {
    font-family: var(--font-display);
    font-size: var(--fs-md);
    letter-spacing: 0.2px;
    cursor: pointer;
  }
  .badge {
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
  .family {
    font-size: var(--fs-xs);
    color: var(--ink-faint);
    font-style: italic;
  }
  .ctrl {
    grid-column: 2;
    grid-row: 1 / span 2;
    display: flex;
    align-items: center;
    gap: 0.4rem;
  }
  .ctrl input[type='text'],
  .ctrl select {
    min-width: 11rem;
  }
  .numfield {
    display: inline-flex;
    align-items: stretch;
  }
  .numfield input {
    width: 6.5rem;
    border-radius: var(--radius-sm) 0 0 var(--radius-sm);
  }
  /* No unit documented → the field keeps a plain rounded edge. */
  .numfield input:only-child {
    border-radius: var(--radius-sm);
  }
  .numfield .unit {
    display: inline-flex;
    align-items: center;
    padding: 0 0.5rem;
    background: var(--raised);
    border: 1px solid var(--hair);
    border-left: none;
    border-radius: 0 var(--radius-sm) var(--radius-sm) 0;
    font-family: var(--font-mono);
    font-size: var(--fs-xs);
    color: var(--ink-dim);
  }
  .reset {
    padding: 0.3rem;
    border-color: transparent;
    color: var(--ink-faint);
  }
  .reset:hover {
    color: var(--accent);
  }
  .reset svg {
    width: 15px;
    height: 15px;
  }
  .desc {
    grid-column: 1;
    margin: 0;
    font-size: var(--fs-sm);
    color: var(--ink-dim);
    max-width: 68ch;
  }
</style>
