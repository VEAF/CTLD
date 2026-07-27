<script lang="ts">
  // A short positional array edited as named fields.
  //
  // Some catalogue values are fixed-length Lua arrays whose meaning is carried entirely by position:
  // `nbLimitSpawnedTroops` is [RED, BLUE] by DCS coalition id, `beaconIconColor` is DCS RGBA. Shown
  // raw they read as `[0, 0]` and `[1, 0.5, 0, 1]` — technically editable, practically undecipherable.
  //
  // Length is preserved: the engine indexes these by position, so a missing slot is not an empty
  // value but a different meaning.
  import { t } from './i18n.svelte'

  export interface Slot {
    /** Translated field name. */
    label: string
    /** Optional hint under the field. */
    hint?: string
    min?: number
    max?: number
    step?: number
  }

  let {
    value,
    slots,
    swatch = false,
    onchange,
  }: {
    value: unknown[]
    slots: Slot[]
    /** Show a colour preview built from the first four slots (RGBA 0–1). */
    swatch?: boolean
    onchange: (v: unknown[]) => void
  } = $props()

  // svelte-ignore state_referenced_locally
  let model = $state<unknown[]>(slots.map((_, i) => (value?.[i] ?? 0) as unknown))

  const asNumber = (v: unknown) => (typeof v === 'number' ? v : Number(v) || 0)
  const clamp01 = (v: number) => Math.min(1, Math.max(0, v))

  const preview = $derived(
    swatch
      ? `rgba(${[0, 1, 2].map((i) => Math.round(clamp01(asNumber(model[i])) * 255)).join(',')},${clamp01(asNumber(model[3]))})`
      : '',
  )

  function set(i: number, raw: string) {
    model[i] = raw === '' ? 0 : Number(raw)
    onchange([...model])
  }
</script>

<div class="slots">
  {#each slots as slot, i (slot.label)}
    <label>
      <span class="name">{slot.label}</span>
      <input
        type="number"
        min={slot.min}
        max={slot.max}
        step={slot.step ?? 1}
        value={asNumber(model[i])}
        onchange={(e) => set(i, e.currentTarget.value)}
      />
      {#if slot.hint}<span class="hint">{slot.hint}</span>{/if}
    </label>
  {/each}

  {#if swatch}
    <div class="swatch-wrap">
      <span class="name">{t('web.table.colour_preview')}</span>
      <span class="swatch" style="background: {preview}" aria-hidden="true"></span>
    </div>
  {/if}
</div>

<style>
  .slots {
    display: flex;
    flex-wrap: wrap;
    gap: 0.7rem 1.2rem;
    align-items: flex-start;
  }
  label,
  .swatch-wrap {
    display: flex;
    flex-direction: column;
    gap: 0.22rem;
  }
  .name {
    font-family: var(--font-display);
    font-size: var(--fs-xs);
    letter-spacing: 0.5px;
    text-transform: uppercase;
    color: var(--ink-faint);
  }
  input {
    width: 7.5rem;
  }
  .hint {
    font-size: var(--fs-xs);
    color: var(--ink-faint);
    max-width: 12rem;
  }
  /* Big enough to judge the colour, bordered so pure black or white still reads as a swatch. */
  .swatch {
    width: 3.2rem;
    height: 2.05rem;
    border: 1px solid var(--hair);
    border-radius: var(--radius-sm);
  }
</style>
