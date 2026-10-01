<script lang="ts">
  // Config completion summary (FEAT-CTLD-TOOLS-CONFIG-COMPLETION): what the tool added to the configuration
  // it just opened. Unlike the version-gap dialog this is not modal — the Mission Maker can keep editing —
  // but it is never silent, and any one addition can be undone.
  import type { CompletionAddition } from './api'
  import { plural, t } from './i18n.svelte'

  let {
    additions,
    labelOf,
    onundo,
    onclose,
  }: {
    additions: CompletionAddition[]
    labelOf: (key: string) => string
    onundo: (key: string) => void
    onclose: () => void
  } = $props()

  function short(v: unknown): string {
    if (v === null || v === undefined) return '—'
    if (typeof v === 'object') return Array.isArray(v) ? `[${v.length}]` : '{…}'
    return String(v)
  }
</script>

<section class="summary" aria-labelledby="completion-title">
  <div class="head">
    <h2 id="completion-title">{plural('web.completion.title', additions.length)}</h2>
    <button class="dismiss" onclick={onclose}>{t('web.completion.dismiss')}</button>
  </div>
  <p class="body">{t('web.completion.body')}</p>
  <ul>
    {#each additions as a (a.key)}
      <li>
        <span class="label">{labelOf(a.key)}</span>
        <code class="rawkey">{a.key}</code>
        <span class="value">{short(a.value)}</span>
        <button class="undo" onclick={() => onundo(a.key)}>{t('web.completion.undo')}</button>
      </li>
    {/each}
  </ul>
</section>

<style>
  .summary {
    background: var(--panel);
    border: 1px solid var(--hair);
    border-left: 2px solid var(--accent);
    border-radius: var(--radius);
    padding: 0.75rem 1rem;
    margin: 0.5rem 1rem;
    max-height: 14rem;
    overflow: auto;
  }
  .head {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
  }
  h2 {
    font-family: var(--font-display);
    font-size: var(--fs-base);
    letter-spacing: 0.3px;
    margin: 0;
  }
  .body {
    margin: 0.35rem 0 0.5rem;
    color: var(--ink-dim);
    font-size: var(--fs-sm);
    max-width: 70ch;
  }
  ul {
    margin: 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 0.2rem;
    font-size: var(--fs-sm);
  }
  li {
    display: flex;
    align-items: baseline;
    gap: 0.6rem;
  }
  .rawkey,
  .value {
    font-family: var(--font-mono);
    font-size: var(--fs-xs);
    color: var(--ink-faint);
  }
  .value {
    margin-left: auto;
  }
  .undo,
  .dismiss {
    font-size: var(--fs-xs);
  }
</style>
