<script lang="ts">
  // A beacon sound: the bundled one, or a file the Mission Maker picks.
  //
  // Bound to `editor: 'sound'` in the schema, never to a setting name — FEAT-EDITOR-COVERAGE. The
  // text box it replaces let you retype a file name that put no file anywhere, which is the bug
  // this control exists to remove.
  //
  // What is shown is the *original* file name, not the reserved one the file takes inside the
  // mission (ADR 0012): `CTLD_beacon_custom.ogg` means nothing to the person who chose
  // `Ma Balise Été.ogg`.
  import { chooseSound, resetSound, type SoundState } from './api'
  import { t } from './i18n.svelte'

  let { sound, onchange }: { sound: SoundState; onchange: () => void } = $props()

  let busy = $state(false)
  let error = $state<string | null>(null)

  const kb = (bytes: number) => `${Math.max(1, Math.round(bytes / 1024))} kB`

  async function pick() {
    busy = true
    error = null
    try {
      const result = await chooseSound(sound.setting)
      if (!result.cancelled) onchange()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }

  async function useDefault() {
    if (!sound.custom) return
    busy = true
    error = null
    try {
      await resetSound(sound.setting)
      onchange()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }
</script>

<div class="sound">
  <div class="choice" role="radiogroup" aria-label={sound.setting}>
    <label>
      <input
        type="radio"
        name={`sound_${sound.setting}`}
        checked={!sound.custom}
        disabled={busy}
        onchange={useDefault}
      />
      {t('web.sound.default')}
    </label>
    <label>
      <input
        type="radio"
        name={`sound_${sound.setting}`}
        checked={sound.custom}
        disabled={busy}
        onchange={pick}
      />
      {t('web.sound.custom')}
    </label>
    <button class="ghost" disabled={busy} onclick={pick}>
      {sound.custom ? t('web.sound.replace') : t('web.sound.choose')}
    </button>
  </div>

  {#if sound.custom}
    <p class="detail" class:warn={!sound.available}>
      {#if sound.originalName}{t('web.sound.from').replace('{name}', sound.originalName)}{/if}
      {#if sound.size}<span class="size">{kb(sound.size)}</span>{/if}
      <code>{sound.file}</code>
    </p>
    {#if !sound.available}<p class="detail warn">{t('web.sound.missing')}</p>{/if}
  {/if}

  {#if error}<p class="detail warn">{error}</p>{/if}
</div>

<style>
  .sound {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
    align-items: flex-end;
  }
  .choice {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }
  .choice label {
    display: inline-flex;
    align-items: center;
    gap: 0.3rem;
    font-size: var(--fs-sm);
    cursor: pointer;
  }
  .detail {
    margin: 0;
    font-size: var(--fs-xs);
    color: var(--ink-dim);
    display: flex;
    gap: 0.4rem;
    align-items: baseline;
    flex-wrap: wrap;
    justify-content: flex-end;
    max-width: 32ch;
    text-align: right;
  }
  .detail code {
    font-family: var(--font-mono);
    color: var(--ink-faint);
  }
  .size {
    color: var(--ink-faint);
  }
  .warn {
    color: var(--danger, #c2554d);
  }
</style>
